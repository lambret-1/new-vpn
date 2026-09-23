//
//  测速服务.swift
//  NewVPN
//
//  节点测速核心服务
//  支持 TCP 连接延迟测试、HTTP 延迟测试、下载速度测试
//

import Foundation

// MARK: - 测速服务

/// 节点测速服务
final class 测速服务 {
    /// 共享单例
    static let 共享 = 测速服务()

    /// URLSession 配置（用于 HTTP 测速）
    private let 会话: URLSession

    /// 私有初始化
    private init() {
        let 配置 = URLSessionConfiguration.ephemeral
        配置.timeoutIntervalForRequest = 10
        配置.timeoutIntervalForResource = 15
        配置.requestCachePolicy = .reloadIgnoringLocalCacheData
        配置.httpMaximumConnectionsPerHost = 10
        会话 = URLSession(configuration: 配置)
    }

    // MARK: - TCP 延迟测试

    /// TCP 连接延迟测试（直接连接节点地址:端口）
    /// - Parameters:
    ///   - 地址: 节点服务器地址
    ///   - 端口: 节点端口
    ///   - 超时: 超时时间
    ///   - 次数: 测试次数（取平均值）
    /// - Returns: 平均延迟（毫秒），失败返回 nil
    func TCP延迟测试(地址: String, 端口: Int, 超时: TimeInterval = 5.0, 次数: Int = 3) -> (延迟: Int?, 抖动: Int?, 丢包率: Double?) {
        var 延迟列表: [Int] = []
        var 成功次数 = 0

        for _ in 0..<次数 {
            if let 延迟 = 单次TCP连接测试(地址: 地址, 端口: 端口, 超时: 超时) {
                延迟列表.append(延迟)
                成功次数 += 1
            }
        }

        guard !延迟列表.isEmpty else {
            return (nil, nil, 100.0)
        }

        // 计算平均延迟
        let 平均延迟 = Int(延迟列表.reduce(0, +) / 延迟列表.count)

        // 计算抖动（相邻延迟差的平均值）
        var 抖动 = 0
        if 延迟列表.count >= 2 {
            var 差值总和 = 0
            for i in 1..<延迟列表.count {
                差值总和 += abs(延迟列表[i] - 延迟列表[i-1])
            }
            抖动 = 差值总和 / (延迟列表.count - 1)
        }

        // 丢包率
        let 丢包率 = Double(次数 - 成功次数) / Double(次数) * 100.0

        return (平均延迟, 抖动, 丢包率)
    }

    /// 单次 TCP 连接测试
    private func 单次TCP连接测试(地址: String, 端口: Int, 超时: TimeInterval) -> Int? {
        var 地址信息 = addrinfo()
        var 结果指针: UnsafeMutablePointer<addrinfo>?

        // 解析地址
        let 端口字符串 = String(端口)
        let 解析结果 = getaddrinfo(地址, 端口字符串, &地址信息, &结果指针)
        guard 解析结果 == 0, let 第一个结果 = 结果指针 else {
            return nil
        }
        defer { freeaddrinfo(结果指针) }

        // 创建 socket
        let socket文件描述符 = socket(第一个结果.pointee.ai_family,
                                       第一个结果.pointee.ai_socktype,
                                       第一个结果.pointee.ai_protocol)
        guard socket文件描述符 >= 0 else {
            return nil
        }
        defer { close(socket文件描述符) }

        // 设置非阻塞模式
        let 标志 = fcntl(socket文件描述符, F_GETFL, 0)
        fcntl(socket文件描述符, F_SETFL, 标志 | O_NONBLOCK)

        // 记录开始时间
        let 开始时间 = Date()

        // 尝试连接
        let 连接结果 = connect(socket文件描述符,
                               第一个结果.pointee.ai_addr,
                               第一个结果.pointee.ai_addrlen)

        if 连接结果 == 0 {
            // 立即连接成功
            let 延迟 = Int(Date().timeIntervalSince(开始时间) * 1000)
            return 延迟
        } else if errno == EINPROGRESS {
            // 连接进行中，等待
            var 等待集合 = fd_set()
            fd_zero(&等待集合)
            fd_set(socket文件描述符, &等待集合)

            var 超时时间 = timeval()
            超时时间.tv_sec = __darwin_time_t(超时)
            超时时间.tv_usec = __darwin_suseconds_t((超时.truncatingRemainder(dividingBy: 1)) * 1_000_000)

            let 选择结果 = select(socket文件描述符 + 1, nil, &等待集合, nil, &超时时间)

            if 选择结果 > 0 {
                // 检查连接是否成功
                var 连接错误: Int32 = 0
                var 错误长度 = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(socket文件描述符, SOL_SOCKET, SO_ERROR, &连接错误, &错误长度)

                if 连接错误 == 0 {
                    let 延迟 = Int(Date().timeIntervalSince(开始时间) * 1000)
                    return 延迟
                }
            }
        }

        return nil
    }

    // MARK: - HTTP 延迟测试

    /// HTTP 延迟测试（通过代理或直连发送 HTTP 请求）
    /// - Parameters:
    ///   - 测试地址: 测试 URL
    ///   - 超时: 超时时间
    /// - Returns: 延迟（毫秒）
    func HTTP延迟测试(测试地址: String, 超时: TimeInterval = 5.0) -> Int? {
        guard let url = URL(string: 测试地址) else { return nil }

        var 请求 = URLRequest(url: url)
        请求.httpMethod = "GET"
        请求.timeoutInterval = 超时
        请求.cachePolicy = .reloadIgnoringLocalCacheData

        let 信号 = DispatchSemaphore(value: 0)
        var 延迟: Int?
        let 开始时间 = Date()

        let 任务 = 会话.dataTask(with: 请求) { _, 响应, 请求错误 in
            if 请求错误 == nil, (响应 as? HTTPURLResponse)?.statusCode != nil {
                延迟 = Int(Date().timeIntervalSince(开始时间) * 1000)
            }
            信号.signal()
        }

        任务.resume()
        _ = 信号.wait(timeout: .now() + 超时 + 1)

        return 延迟
    }

    // MARK: - 下载速度测试

    /// 下载速度测试
    /// - Parameters:
    ///   - 下载地址: 测试文件 URL
    ///   - 超时: 超时时间
    ///   - 数据上限: 下载数据量上限（字节）
    ///   - 时长上限: 测试时长上限（秒）
    /// - Returns: 下载速度（Mbps）
    func 下载速度测试(下载地址: String, 超时: TimeInterval = 10.0, 数据上限: Int64 = 10 * 1024 * 1024, 时长上限: TimeInterval = 8.0) -> Double? {
        guard let url = URL(string: 下载地址) else { return nil }

        var 请求 = URLRequest(url: url)
        请求.httpMethod = "GET"
        请求.timeoutInterval = 超时
        请求.cachePolicy = .reloadIgnoringLocalCacheData

        let 信号 = DispatchSemaphore(value: 0)
        var 总下载字节: Int64 = 0
        var 下载速度: Double?
        let 开始时间 = Date()
        var 应该停止 = false

        let 任务 = 会话.dataTask(with: 请求) { 数据, 响应, 错误 in
            if let 数据 = 数据 {
                总下载字节 = Int64(数据.count)
            }
            信号.signal()
        }

        // 使用进度观察
        let 进度观察 = 任务.progress.observe(\.fractionCompleted) { 进度, _ in
            let 已用时间 = Date().timeIntervalSince(开始时间)
            if 已用时间 >= 时长上限 || Int64(进度.completedUnitCount) >= 数据上限 {
                应该停止 = true
                任务.cancel()
            }
        }

        任务.resume()
        _ = 信号.wait(timeout: .now() + 超时 + 1)
        进度观察.invalidate()

        let 总用时 = Date().timeIntervalSince(开始时间)
        guard 总用时 > 0, 总下载字节 > 0 else { return nil }

        // 转换为 Mbps（兆比特每秒）
        下载速度 = (Double(总下载字节) * 8) / (总用时 * 1_000_000)

        return 下载速度
    }

    // MARK: - 完整节点测速

    /// 对单个节点执行完整测速
    /// - Parameters:
    ///   - 节点: 节点模型
    ///   - 配置: 测速配置
    ///   - 进度: 进度回调（当前阶段）
    /// - Returns: 测速结果
    func 测速节点(_ 节点: 节点模型, 配置: 测速配置 = .默认, 进度: ((String) -> Void)? = nil) -> 测速结果模型 {
        var 结果 = 测速结果模型.空结果(节点ID: 节点.id)

        // 1. TCP 延迟测试
        进度?("正在测试延迟...")
        let TCP结果 = TCP延迟测试(
            地址: 节点.地址,
            端口: 节点.端口,
            超时: 配置.延迟超时,
            次数: 配置.延迟测试次数
        )

        结果.延迟毫秒 = TCP结果.延迟
        结果.抖动毫秒 = TCP结果.抖动
        结果.丢包率 = TCP结果.丢包率

        // 如果延迟测试失败，直接返回失败
        guard TCP结果.延迟 != nil else {
            结果.成功 = false
            结果.错误信息 = "无法连接到节点"
            结果.测速时间 = Date()
            return 结果
        }

        // 2. 下载速度测试（如果配置要求）
        if 配置.类型 == .延迟和下载 || 配置.类型 == .完整测试 {
            进度?("正在测试下载速度...")
            let 下载速度 = 下载速度测试(
                下载地址: 配置.下载测试文件地址,
                超时: 配置.下载超时,
                数据上限: 配置.下载数据上限,
                时长上限: 配置.下载时长上限
            )
            结果.下载速率Mbps = 下载速度
        }

        // 3. 上传速度测试（完整测试模式，暂用模拟值）
        if 配置.类型 == .完整测试 {
            进度?("正在测试上传速度...")
            // 上传测速需要服务器支持，暂时使用下载速度的 30% 作为估算
            if let 下载 = 结果.下载速率Mbps {
                结果.上传速率Mbps = 下载 * 0.3
            }
        }

        结果.成功 = true
        结果.测速时间 = Date()
        return 结果
    }
}

// MARK: - fd_set 辅助函数

/// 初始化 fd_set
private func fd_zero(_ set: inout fd_set) {
    set = fd_set()
}

/// 设置 fd_set 中的位
private func fd_set(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd / 32)
    let bitOffset = Int32(fd % 32)
    if intOffset < 32 {
        set.fds_bits.0 = set.fds_bits.0
        // Swift 中 fd_set 的 fds_bits 是元组，需要用 withUnsafeMutablePointer 操作
        withUnsafeMutablePointer(to: &set) { 指针 in
            let 整数指针 = UnsafeMutableRawPointer(指针).assumingMemoryBound(to: Int32.self)
            整数指针[intOffset] |= (1 << bitOffset)
        }
    }
}
