//
//  订阅解释器.swift
//  NewVPN
//
//  订阅解释器主入口
//  自动检测订阅格式，分发到对应解释器，返回统一解析结果
//

import Foundation

// MARK: - 订阅解释器

/// 订阅解释器：自动检测格式并解析订阅内容
final class 订阅解释器 {
    /// 共享单例
    static let 共享 = 订阅解释器()

    /// 私有初始化
    private init() {}

    // MARK: - 主解析入口

    /// 解析订阅内容（自动检测格式）
    /// - Parameter 原始内容: 订阅原始文本
    /// - Returns: 解析结果
    func 解析(_ 原始内容: String) -> 订阅解析结果 {
        let 清理后内容 = 原始内容.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !清理后内容.isEmpty else {
            return 订阅解析结果(
                格式: .未知,
                节点列表: [],
                错误列表: [解析错误(类型: .格式不支持, 描述: "订阅内容为空", 原始内容: nil, 行号: nil)]
            )
        }

        // 检测格式
        let 格式 = 检测格式(清理后内容)

        // 根据格式分发
        switch 格式 {
        case .base64节点列表:
            return 解析Base64节点列表(清理后内容)
        case .纯文本节点列表:
            return 解析纯文本节点列表(清理后内容)
        case .clash配置:
            return Clash解释器.共享.解析(清理后内容)
        case .singbox配置:
            return SingBox解释器.共享.解析(清理后内容)
        case .v2rayn订阅:
            return 解析V2RayN订阅(清理后内容)
        case .未知:
            // 尝试各种格式
            return 尝试多种格式(清理后内容)
        }
    }

    // MARK: - 格式检测

    /// 检测订阅内容格式
    private func 检测格式(_ 内容: String) -> 订阅格式类型 {
        // 1. 检测是否为 JSON（sing-box 配置）
        if 内容.hasPrefix("{") {
            if let 数据 = 内容.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: 数据) as? [String: Any] {
                // sing-box 配置特征：包含 outbounds 或 log/dns/inbounds
                if json["outbounds"] != nil || json["inbounds"] != nil {
                    return .singbox配置
                }
            }
        }

        // 2. 检测是否为 YAML（Clash 配置）
        if 内容.contains("proxies:") && (内容.contains("type:") || 内容.contains("server:")) {
            return .clash配置
        }

        // 3. 检测是否为纯文本节点链接列表
        let 行列表 = 内容.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !行列表.isEmpty {
            let 协议前缀列表 = ["vless://", "vmess://", "trojan://", "ss://", "ssr://"]
            let 匹配行数 = 行列表.filter { 行 in
                let 修剪 = 行.trimmingCharacters(in: .whitespaces)
                return 协议前缀列表.contains { 修剪.hasPrefix($0) }
            }.count

            // 如果超过一半的行是节点链接，认为是纯文本列表
            if 匹配行数 > 0 && 匹配行数 >= 行列表.count / 2 {
                return .纯文本节点列表
            }
        }

        // 4. 检测是否为 Base64 编码
        // Base64 特征：只包含 Base64 字符，长度是4的倍数，解码后是节点链接列表或JSON
        let base64字符 = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        let 清理后 = 内容.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: " ", with: "")

        if !清理后.isEmpty &&
           清理后.rangeOfCharacter(from: base64字符.inverted) == nil &&
           清理后.count % 4 == 0 {
            // 尝试解码
            if let 解码数据 = Data(base64Encoded: 清理后, options: .ignoreUnknownCharacters),
               let 解码文本 = String(data: 解码数据, encoding: .utf8) {
                // 解码后检测格式
                if 解码文本.hasPrefix("{") {
                    return .v2rayn订阅 // 可能是 vmess JSON
                }
                if 解码文本.contains("vless://") || 解码文本.contains("vmess://") ||
                   解码文本.contains("trojan://") || 解码文本.contains("ss://") {
                    return .base64节点列表
                }
                if 解码文本.contains("proxies:") {
                    return .clash配置
                }
            }
        }

        return .未知
    }

    // MARK: - 各格式解析

    /// 解析 Base64 编码的节点列表
    private func 解析Base64节点列表(_ 内容: String) -> 订阅解析结果 {
        let 清理后 = 内容.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: " ", with: "")

        guard let 解码数据 = Data(base64Encoded: 清理后, options: .ignoreUnknownCharacters),
              let 解码文本 = String(data: 解码数据, encoding: .utf8) else {
            return 订阅解析结果(
                格式: .base64节点列表,
                节点列表: [],
                错误列表: [解析错误(类型: .解码失败, 描述: "Base64解码失败", 原始内容: 内容, 行号: nil)]
            )
        }

        return 解析纯文本节点列表(解码文本, 格式: .base64节点列表)
    }

    /// 解析纯文本节点链接列表
    private func 解析纯文本节点列表(_ 内容: String, 格式: 订阅格式类型 = .纯文本节点列表) -> 订阅解析结果 {
        let 行列表 = 内容.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        let 结果 = 节点链接解析器.共享.批量解析(行列表)

        return 订阅解析结果(
            格式: 格式,
            节点列表: 结果.节点,
            错误列表: 结果.错误
        )
    }

    /// 解析 V2RayN 订阅（base64 编码的 vmess JSON 列表）
    private func 解析V2RayN订阅(_ 内容: String) -> 订阅解析结果 {
        let 清理后 = 内容.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")

        guard let 解码数据 = Data(base64Encoded: 清理后, options: .ignoreUnknownCharacters),
              let 解码文本 = String(data: 解码数据, encoding: .utf8) else {
            return 订阅解析结果(
                格式: .v2rayn订阅,
                节点列表: [],
                错误列表: [解析错误(类型: .解码失败, 描述: "V2RayN订阅Base64解码失败", 原始内容: 内容, 行号: nil)]
            )
        }

        // V2RayN 订阅通常是每行一个 vmess:// 链接
        return 解析纯文本节点列表(解码文本, 格式: .v2rayn订阅)
    }

    /// 尝试多种格式解析（用于未知格式）
    private func 尝试多种格式(_ 内容: String) -> 订阅解析结果 {
        // 尝试 sing-box
        if 内容.hasPrefix("{") {
            let 结果 = SingBox解释器.共享.解析(内容)
            if !结果.节点列表.isEmpty {
                return 结果
            }
        }

        // 尝试 Clash
        if 内容.contains("proxies:") {
            let 结果 = Clash解释器.共享.解析(内容)
            if !结果.节点列表.isEmpty {
                return 结果
            }
        }

        // 尝试纯文本
        let 纯文本结果 = 解析纯文本节点列表(内容)
        if !纯文本结果.节点列表.isEmpty {
            return 纯文本结果
        }

        // 尝试 Base64
        let base64结果 = 解析Base64节点列表(内容)
        if !base64结果.节点列表.isEmpty {
            return base64结果
        }

        return 订阅解析结果(
            格式: .未知,
            节点列表: [],
            错误列表: [解析错误(类型: .格式不支持, 描述: "无法识别订阅格式", 原始内容: 内容, 行号: nil)]
        )
    }

    // MARK: - 导出为 sing-box 配置

    /// 将解析结果导出为 sing-box 配置 JSON
    /// - Parameter 解析结果: 解析结果
    /// - Returns: sing-box 配置 JSON 字符串
    func 导出为SingBox配置(_ 解析结果: 订阅解析结果) -> String {
        var outbounds: [[String: Any]] = []

        for 节点 in 解析结果.节点列表 {
            var outbound: [String: Any] = [
                "type": 节点.协议.rawValue.lowercased(),
                "tag": 节点.名称,
                "server": 节点.地址,
                "server_port": 节点.端口
            ]

            switch 节点.协议 {
            case .vless, .vmess:
                if let uuid = 节点.用户标识 {
                    outbound["uuid"] = uuid
                }
            case .trojan, .shadowsocks:
                if let 密码 = 节点.用户标识 {
                    if 节点.协议 == .shadowsocks {
                        let 部分 = 密码.components(separatedBy: ":")
                        if 部分.count >= 2 {
                            outbound["method"] = 部分[0]
                            outbound["password"] = 部分.dropFirst().joined(separator: ":")
                        }
                    } else {
                        outbound["password"] = 密码
                    }
                }
            }

            if 节点.启用TLS {
                var tls: [String: Any] = ["enabled": true]
                if let sni = 节点.服务器名称 {
                    tls["server_name"] = sni
                }
                outbound["tls"] = tls
            }

            if 节点.传输类型 != .tcp {
                outbound["transport"] = ["type": 节点.传输类型.rawValue.lowercased()]
            }

            outbounds.append(outbound)
        }

        let 配置: [String: Any] = [
            "log": ["level": "info"],
            "outbounds": outbounds
        ]

        if let json数据 = try? JSONSerialization.data(withJSONObject: 配置, options: [.prettyPrinted, .sortedKeys]),
           let json字符串 = String(data: json数据, encoding: .utf8) {
            return json字符串
        }

        return "{}"
    }
}
