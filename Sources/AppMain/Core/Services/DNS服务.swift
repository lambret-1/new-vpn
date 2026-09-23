//
//  DNS服务.swift
//  NewVPN
//
//  DNS 查询服务：域名解析、缓存管理、记录查询
//

import Foundation

// MARK: - DNS 服务

/// DNS 查询服务
final class DNS服务 {
    /// 共享单例
    static let 共享 = DNS服务()

    /// DNS 缓存（域名: 记录列表）
    private var 缓存: [String: [DNS记录模型]] = [:]
    /// 缓存锁
    private let 缓存锁 = NSLock()
    /// 查询队列
    private let 查询队列 = DispatchQueue(label: "com.newvpn.dns.query", qos: .userInitiated)

    /// 私有初始化
    private init() {}

    // MARK: - 域名解析

    /// 解析域名（同步，使用系统 DNS）
    /// - Parameters:
    ///   - 域名: 要解析的域名
    ///   - 记录类型: 记录类型
    ///   - DNS服务器: 指定 DNS 服务器（nil 使用系统默认）
    /// - Returns: 解析结果（IP地址列表）
    func 解析域名(_ 域名: String, 记录类型: DNS记录类型 = .A, DNS服务器: String? = nil) -> [String] {
        // 检查缓存
        if let 缓存记录 = 获取缓存(域名: 域名, 类型: 记录类型) {
            return 缓存记录.解析结果
        }

        // 使用系统 DNS 解析
        var 结果: [String] = []

        switch 记录类型 {
        case .A, .AAAA:
            结果 = 系统解析IP(域名: 域名)
        case .CNAME:
            结果 = 系统解析CNAME(域名: 域名)
        default:
            break
        }

        // 写入缓存
        if !结果.isEmpty {
            let 记录 = DNS记录模型(
                域名: 域名,
                记录类型: 记录类型,
                解析结果: 结果,
                TTL: 300,
                查询时间: Date(),
                响应时间: nil,
                DNS服务器: DNS服务器 ?? "系统",
                来源: .远程
            )
            添加缓存(记录)
        }

        return 结果
    }

    /// 异步解析域名
    func 异步解析域名(_ 域名: String, 记录类型: DNS记录类型 = .A, DNS服务器: String? = nil, 完成: @escaping ([String]) -> Void) {
        查询队列.async {
            let 结果 = self.解析域名(域名, 记录类型: 记录类型, DNS服务器: DNS服务器)
            DispatchQueue.main.async {
                完成(结果)
            }
        }
    }

    // MARK: - 系统 DNS 解析

    /// 使用系统 API 解析域名 IP
    private func 系统解析IP(域名: String) -> [String] {
        var 结果: [String] = []

        // 使用 CFHost 进行 DNS 解析
        let 主机 = CFHostCreateWithName(kCFAllocatorDefault, 域名 as CFString).takeRetainedValue()
        var 解析错误 = CFHostError()
        let 成功 = CFHostStartInfoResolution(主机, .addresses, &解析错误)

        if 成功 {
            var 解析结果: DarwinBoolean = false
            if let 地址列表 = CFHostGetAddressing(主机, &解析结果)?.takeUnretainedValue() as? [Data] {
                for 地址数据 in 地址列表 {
                    let 地址 = 地址数据.withUnsafeBytes { (指针: UnsafeRawBufferPointer) -> String? in
                        guard let 存储指针 = 指针.baseAddress?.assumingMemoryBound(to: sockaddr_storage.self) else { return nil }
                        let 存储 = 存储指针.pointee
                        if 存储.ss_family == sa_family_t(AF_INET) {
                            // IPv4
                            var addr4 = sockaddr_in()
                            memcpy(&addr4, 存储指针, MemoryLayout<sockaddr_in>.size)
                            let ipBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET_ADDRSTRLEN))
                            inet_ntop(AF_INET, &addr4.sin_addr, ipBuffer, socklen_t(INET_ADDRSTRLEN))
                            let ip = String(cString: ipBuffer)
                            ipBuffer.deallocate()
                            return ip
                        } else if 存储.ss_family == sa_family_t(AF_INET6) {
                            // IPv6
                            var addr6 = sockaddr_in6()
                            memcpy(&addr6, 存储指针, MemoryLayout<sockaddr_in6>.size)
                            let ipBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET6_ADDRSTRLEN))
                            inet_ntop(AF_INET6, &addr6.sin6_addr, ipBuffer, socklen_t(INET6_ADDRSTRLEN))
                            let ip = String(cString: ipBuffer)
                            ipBuffer.deallocate()
                            return ip
                        }
                        return nil
                    }
                    if let ip = 地址 {
                        结果.append(ip)
                    }
                }
            }
        }

        return 结果
    }

    /// 解析 CNAME 记录
    private func 系统解析CNAME(域名: String) -> [String] {
        // iOS 系统 API 不直接支持 CNAME 查询，使用简单模拟
        // 实际项目中可以使用 DNSServiceQueryRecord 或第三方库
        return []
    }

    // MARK: - 反向解析

    /// 反向 DNS 解析（IP -> 域名）
    func 反向解析(_ IP地址: String) -> String? {
        var 结果: String?

        // 创建 sockaddr
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        inet_pton(AF_INET, IP地址, &addr.sin_addr)

        let 主机 = CFHostCreateWithAddress(kCFAllocatorDefault,
                                             Data(bytes: &addr, count: MemoryLayout<sockaddr_in>.size) as CFData).takeRetainedValue()
        var 解析错误 = CFHostError()
        let 成功 = CFHostStartInfoResolution(主机, .names, &解析错误)

        if 成功 {
            var 解析结果: DarwinBoolean = false
            if let 名称列表 = CFHostGetNames(主机, &解析结果)?.takeUnretainedValue() as? [String] {
                结果 = 名称列表.first
            }
        }

        return 结果
    }

    // MARK: - 缓存管理

    /// 获取缓存记录
    func 获取缓存(域名: String, 类型: DNS记录类型) -> DNS记录模型? {
        缓存锁.lock()
        defer { 缓存锁.unlock() }

        let 键 = 缓存键(域名: 域名, 类型: 类型)
        guard let 记录列表 = 缓存[键], let 记录 = 记录列表.first else {
            return nil
        }

        // 检查 TTL 是否过期
        let 已过时间 = Date().timeIntervalSince(记录.查询时间)
        if Double(记录.TTL) > 0 && 已过时间 > Double(记录.TTL) {
            缓存.removeValue(forKey: 键)
            return nil
        }

        // 返回缓存命中的记录（修改来源）
        var 缓存记录 = 记录
        缓存记录.来源 = .缓存
        return 缓存记录
    }

    /// 添加缓存记录
    func 添加缓存(_ 记录: DNS记录模型) {
        缓存锁.lock()
        defer { 缓存锁.unlock() }

        let 键 = 缓存键(域名: 记录.域名, 类型: 记录.记录类型)
        缓存[键] = [记录]

        // 限制缓存大小
        if 缓存.count > 1000 {
            // 简单清理：移除最早的一半
            let 要移除 = 缓存.count / 2
            var 已移除 = 0
            for (键, _) in 缓存 {
                if 已移除 >= 要移除 { break }
                缓存.removeValue(forKey: 键)
                已移除 += 1
            }
        }
    }

    /// 清除缓存
    func 清除缓存() {
        缓存锁.lock()
        defer { 缓存锁.unlock() }
        缓存.removeAll()
    }

    /// 清除指定域名缓存
    func 清除域名缓存(_ 域名: String) {
        缓存锁.lock()
        defer { 缓存锁.unlock() }
        for 类型 in DNS记录类型.allCases {
            let 键 = 缓存键(域名: 域名, 类型: 类型)
            缓存.removeValue(forKey: 键)
        }
    }

    /// 缓存键生成
    private func 缓存键(域名: String, 类型: DNS记录类型) -> String {
        "\(域名)_\(类型.rawValue)"
    }

    // MARK: - DNS 服务器测速

    /// 测试 DNS 服务器延迟
    /// - Parameters:
    ///   - 服务器: DNS 服务器配置
    ///   - 测试域名: 测试用域名
    /// - Returns: 延迟（毫秒），失败返回 nil
    func 测试服务器延迟(_ 服务器: DNS服务器模型, 测试域名: String = "www.apple.com") -> Int? {
        let 开始时间 = Date()

        // 使用指定 DNS 服务器进行解析
        // 注意：iOS 系统 API 不直接支持指定 DNS 服务器，
        // 这里使用系统 DNS 解析作为近似测试
        // 实际项目中可以使用第三方 DNS 库或 Network.framework 的 NWResolver
        _ = 服务器

        let 结果 = 解析域名(测试域名)
        guard !结果.isEmpty else { return nil }

        let 延迟 = Int(Date().timeIntervalSince(开始时间) * 1000)
        return 延迟
    }

    // MARK: - DNS 泄漏检测

    /// DNS 泄漏检测
    /// - Parameter 预期服务器: 预期使用的 DNS 服务器列表
    /// - Returns: 检测结果
    func 泄漏检测(预期服务器: [String]) -> DNS泄漏检测结果 {
        // 模拟 DNS 泄漏检测
        // 实际实现需要查询多个测试网站并分析 DNS 请求来源
        let 检测到的服务器 = ["系统 DNS"]
        let 泄漏服务器 = 检测到的服务器.filter { !预期服务器.contains($0) }

        return DNS泄漏检测结果(
            存在泄漏: !泄漏服务器.isEmpty,
            检测到的服务器: 检测到的服务器,
            预期服务器: 预期服务器,
            泄漏服务器: 泄漏服务器,
            检测时间: Date()
        )
    }
}
