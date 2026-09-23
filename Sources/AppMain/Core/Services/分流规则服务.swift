//
//  分流规则服务.swift
//  NewVPN
//
//  分流规则匹配引擎、规则导入导出
//

import Foundation

// MARK: - 分流规则服务

/// 分流规则匹配服务
final class 分流规则服务 {
    /// 共享单例
    static let 共享 = 分流规则服务()

    /// 私有初始化
    private init() {}

    // MARK: - 规则匹配

    /// 匹配分流规则
    /// - Parameters:
    ///   - 域名: 请求域名
    ///   - IP地址: 目标IP地址（可选）
    ///   - 端口: 目标端口（可选）
    ///   - 协议: 网络协议（可选）
    ///   - 规则列表: 待匹配的规则列表（按优先级排序）
    /// - Returns: 匹配到的规则（nil表示未匹配）
    func 匹配规则(域名: String? = nil,
                 IP地址: String? = nil,
                 端口: Int? = nil,
                 协议: 网络协议? = nil,
                 规则列表: [分流规则项]) -> 分流规则项? {
        for 规则 in 规则列表 {
            guard 规则.启用 else { continue }

            // 检查协议限制
            if let 规则协议 = 规则.协议限制, 规则协议 != .全部 {
                if let 请求协议 = 协议, 请求协议 != 规则协议 {
                    continue
                }
            }

            // 检查端口限制
            if let 规则端口 = 规则.端口限制 {
                if let 请求端口 = 端口, 请求端口 != 规则端口 {
                    continue
                }
            }

            // 根据规则类型匹配
            if 匹配单条规则(规则, 域名: 域名, IP地址: IP地址, 端口: 端口) {
                return 规则
            }
        }
        return nil
    }

    /// 匹配单条规则
    private func 匹配单条规则(_ 规则: 分流规则项,
                            域名: String?,
                            IP地址: String?,
                            端口: Int?) -> Bool {
        switch 规则.类型 {
        case .域名精确:
            guard let 域名 = 域名 else { return false }
            return 域名.lowercased() == 规则.匹配值.lowercased()

        case .域名后缀:
            guard let 域名 = 域名 else { return false }
            let 小写域名 = 域名.lowercased()
            let 后缀 = 规则.匹配值.lowercased()
            return 小写域名 == 后缀 || 小写域名.hasSuffix(".\(后缀)")

        case .域名关键词:
            guard let 域名 = 域名 else { return false }
            return 域名.lowercased().contains(规则.匹配值.lowercased())

        case .正则表达式:
            guard let 域名 = 域名 else { return false }
            do {
                let 正则 = try NSRegularExpression(pattern: 规则.匹配值, options: .caseInsensitive)
                let 范围 = NSRange(域名.startIndex..., in: 域名)
                return 正则.firstMatch(in: 域名, range: 范围) != nil
            } catch {
                return false
            }

        case .IP地址:
            guard let IP = IP地址 else { return false }
            return IP == 规则.匹配值

        case .IP段:
            guard let IP = IP地址 else { return false }
            return IP属于CIDR(IP: IP, CIDR: 规则.匹配值)

        case .端口:
            guard let 端口 = 端口 else { return false }
            return 端口 == Int(规则.匹配值)

        case .端口范围:
            guard let 端口 = 端口 else { return false }
            let 范围 = 规则.匹配值.split(separator: "-").compactMap { Int($0) }
            guard 范围.count == 2 else { return false }
            return 端口 >= 范围[0] && 端口 <= 范围[1]

        case .协议:
            // 协议匹配在外部已处理
            return true

        case .进程名称:
            // iOS 上无法获取其他进程名称，返回 false
            return false

        case .用户代理:
            // 用户代理匹配需要 HTTP 层，此处返回 false
            return false

        case .地理区域:
            // 地理区域匹配需要 IP 地理位置数据库，此处返回 false
            return false

        case .全部:
            return true
        }
    }

    // MARK: - CIDR 匹配

    /// 判断 IP 是否属于 CIDR 段
    private func IP属于CIDR(IP: String, CIDR: String) -> Bool {
        let 部分 = CIDR.split(separator: "/")
        guard 部分.count == 2,
              let 网络地址 = String(部分[0]).转换为IPv4整数,
              let 前缀长度 = Int(部分[1]),
              let IP整数 = IP.转换为IPv4整数 else {
            return false
        }

        guard 前缀长度 >= 0 && 前缀长度 <= 32 else { return false }

        // 计算掩码
        let 掩码: UInt32
        if 前缀长度 == 0 {
            掩码 = 0
        } else {
            掩码 = UInt32.max << (32 - 前缀长度)
        }

        return (IP整数 & 掩码) == (网络地址 & 掩码)
    }

    // MARK: - 规则测试

    /// 测试规则匹配（返回详细匹配过程）
    func 测试匹配(测试值: String,
                 规则列表: [分流规则项],
                 默认动作: 分流动作) -> 分流测试结果 {
        var 匹配过程: [(规则名称: String, 匹配: Bool)] = []
        var 匹配规则: 分流规则项?

        // 判断测试值是域名还是 IP
        let 是IP = 测试值.转换为IPv4整数 != nil

        for 规则 in 规则列表 {
            guard 规则.启用 else { continue }

            let 匹配: Bool
            if 是IP {
                匹配 = 匹配单条规则(规则, 域名: nil, IP地址: 测试值, 端口: nil)
            } else {
                匹配 = 匹配单条规则(规则, 域名: 测试值, IP地址: nil, 端口: nil)
            }

            匹配过程.append((规则名称: 规则.名称, 匹配: 匹配))

            if 匹配 && 匹配规则 == nil {
                匹配规则 = 规则
            }
        }

        let 最终动作 = 匹配规则?.动作 ?? 默认动作

        return 分流测试结果(
            测试值: 测试值,
            匹配规则: 匹配规则,
            最终动作: 最终动作,
            匹配过程: 匹配过程,
            测试时间: Date()
        )
    }

    // MARK: - 规则导入

    /// 从 Clash 配置导入规则
    /// - Parameter 配置文本: Clash YAML 配置文本
    /// - Returns: 导入的规则列表
    func 从Clash导入规则(_ 配置文本: String) -> [分流规则项] {
        var 规则列表: [分流规则项] = []

        // 简单解析 Clash rules 部分
        let 行 = 配置文本.components(separatedBy: .newlines)
        var 在规则段 = false

        for 行文本 in 行 {
            let 修剪行 = 行文本.trimmingCharacters(in: .whitespaces)

            if 修剪行.hasPrefix("rules:") {
                在规则段 = true
                continue
            }

            if 在规则段 {
                // 遇到新的顶级键则结束
                if !修剪行.hasPrefix("-") && !修剪行.hasPrefix(" ") && !修剪行.isEmpty {
                    break
                }

                // 解析规则行: - DOMAIN,example.com,DIRECT
                if 修剪行.hasPrefix("-") {
                    let 规则内容 = 修剪行.dropFirst().trimmingCharacters(in: .whitespaces)
                    let 部分 = 规则内容.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

                    guard 部分.count >= 3 else { continue }

                    let 类型字符串 = 部分[0].uppercased()
                    let 匹配值 = 部分[1]
                    let 动作字符串 = 部分[2].uppercased()

                    let 类型: 分流规则类型
                    switch 类型字符串 {
                    case "DOMAIN": 类型 = .域名精确
                    case "DOMAIN-SUFFIX": 类型 = .域名后缀
                    case "DOMAIN-KEYWORD": 类型 = .域名关键词
                    case "DOMAIN-REGEX": 类型 = .正则表达式
                    case "IP-CIDR", "IP-CIDR6": 类型 = .IP段
                    case "SRC-IP-CIDR": 类型 = .IP段
                    case "DST-PORT": 类型 = .端口
                    case "SRC-PORT": 类型 = .端口
                    case "PROCESS-NAME": 类型 = .进程名称
                    case "USER-AGENT": 类型 = .用户代理
                    case "GEOIP": 类型 = .地理区域
                    case "MATCH": 类型 = .全部
                    default: continue
                    }

                    let 动作: 分流动作
                    switch 动作字符串 {
                    case "DIRECT": 动作 = .直连
                    case "PROXY": 动作 = .代理
                    case "REJECT": 动作 = .拦截
                    case "GLOBAL": 动作 = .全局代理
                    case "PASS": 动作 = .放行
                    default: 动作 = .代理
                    }

                    let 规则 = 分流规则项(
                        名称: "\(类型.rawValue) - \(匹配值)",
                        类型: 类型,
                        匹配值: 匹配值,
                        动作: 动作,
                        优先级: 规则列表.count + 100,
                        备注: "从 Clash 导入"
                    )
                    规则列表.append(规则)
                }
            }
        }

        return 规则列表
    }

    /// 从 sing-box 配置导入规则
    /// - Parameter 配置文本: sing-box JSON 配置文本
    /// - Returns: 导入的规则列表
    func 从SingBox导入规则(_ 配置文本: String) -> [分流规则项] {
        var 规则列表: [分流规则项] = []

        guard let 数据 = 配置文本.data(using: .utf8),
              let JSON = try? JSONSerialization.jsonObject(with: 数据) as? [String: Any],
              let 路由 = JSON["route"] as? [String: Any],
              let 规则数组 = 路由["rules"] as? [[String: Any]] else {
            return 规则列表
        }

        for (索引, 规则JSON) in 规则数组.enumerated() {
            // 解析域名规则
            if let 域名列表 = 规则JSON["domain"] as? [String] {
                for 域名 in 域名列表 {
                    let 规则 = 分流规则项(
                        名称: "域名 - \(域名)",
                        类型: .域名精确,
                        匹配值: 域名,
                        动作: .代理,
                        优先级: 索引 * 10 + 100,
                        备注: "从 sing-box 导入"
                    )
                    规则列表.append(规则)
                }
            }

            // 解析域名后缀
            if let 后缀列表 = 规则JSON["domain_suffix"] as? [String] {
                for 后缀 in 后缀列表 {
                    let 规则 = 分流规则项(
                        名称: "域名后缀 - \(后缀)",
                        类型: .域名后缀,
                        匹配值: 后缀,
                        动作: .代理,
                        优先级: 索引 * 10 + 101,
                        备注: "从 sing-box 导入"
                    )
                    规则列表.append(规则)
                }
            }

            // 解析 IP 段
            if let IP列表 = 规则JSON["ip_cidr"] as? [String] {
                for IP in IP列表 {
                    let 规则 = 分流规则项(
                        名称: "IP段 - \(IP)",
                        类型: .IP段,
                        匹配值: IP,
                        动作: .代理,
                        优先级: 索引 * 10 + 102,
                        备注: "从 sing-box 导入"
                    )
                    规则列表.append(规则)
                }
            }
        }

        return 规则列表
    }

    // MARK: - 规则导出

    /// 导出为 Clash 格式
    /// - Parameter 规则列表: 规则列表
    /// - Returns: Clash YAML 规则文本
    func 导出为Clash格式(_ 规则列表: [分流规则项]) -> String {
        var 行: [String] = ["rules:"]

        for 规则 in 规则列表 where 规则.启用 {
            let 类型字符串: String
            switch 规则.类型 {
            case .域名精确: 类型字符串 = "DOMAIN"
            case .域名后缀: 类型字符串 = "DOMAIN-SUFFIX"
            case .域名关键词: 类型字符串 = "DOMAIN-KEYWORD"
            case .正则表达式: 类型字符串 = "DOMAIN-REGEX"
            case .IP地址: 类型字符串 = "IP-CIDR"
            case .IP段: 类型字符串 = "IP-CIDR"
            case .端口: 类型字符串 = "DST-PORT"
            case .端口范围: 类型字符串 = "DST-PORT"
            case .协议: 类型字符串 = "PROCESS-NAME"
            case .进程名称: 类型字符串 = "PROCESS-NAME"
            case .用户代理: 类型字符串 = "USER-AGENT"
            case .地理区域: 类型字符串 = "GEOIP"
            case .全部: 类型字符串 = "MATCH"
            }

            let 动作字符串: String
            switch 规则.动作 {
            case .直连: 动作字符串 = "DIRECT"
            case .代理: 动作字符串 = "PROXY"
            case .拦截: 动作字符串 = "REJECT"
            case .全局代理: 动作字符串 = "GLOBAL"
            case .拒绝: 动作字符串 = "REJECT"
            case .放行: 动作字符串 = "PASS"
            }

            行.append("  - \(类型字符串),\(规则.匹配值),\(动作字符串)")
        }

        return 行.joined(separator: "\n")
    }
}

// MARK: - String 扩展

private extension String {
    /// 转换为 IPv4 整数
    var 转换为IPv4整数: UInt32? {
        let 部分 = self.split(separator: ".").compactMap { UInt32($0) }
        guard 部分.count == 4 else { return nil }
        guard 部分.allSatisfy({ $0 <= 255 }) else { return nil }
        return (部分[0] << 24) | (部分[1] << 16) | (部分[2] << 8) | 部分[3]
    }
}
