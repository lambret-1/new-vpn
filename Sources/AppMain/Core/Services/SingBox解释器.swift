//
//  SingBox解释器.swift
//  NewVPN
//
//  sing-box 配置解释器
//  解析 sing-box JSON 配置中的 outbounds 数组，转换为统一节点模型
//

import Foundation

// MARK: - sing-box 解释器

/// sing-box 配置解释器
final class SingBox解释器 {
    /// 共享单例
    static let 共享 = SingBox解释器()

    /// 私有初始化
    private init() {}

    // MARK: - 主解析入口

    /// 解析 sing-box JSON 配置
    /// - Parameter json内容: JSON 配置文本
    /// - Returns: 解析结果
    func 解析(_ json内容: String) -> 订阅解析结果 {
        var 节点列表: [解析节点模型] = []
        var 错误列表: [解析错误] = []

        guard let json数据 = json内容.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: json数据) as? [String: Any] else {
            错误列表.append(解析错误(类型: .JSON解析失败, 描述: "sing-box配置JSON解析失败", 原始内容: json内容, 行号: nil))
            return 订阅解析结果(格式: .singbox配置, 节点列表: [], 分流规则列表: [], 错误列表: 错误列表)
        }

        // 提取 outbounds 数组
        guard let outbounds = json["outbounds"] as? [[String: Any]] else {
            错误列表.append(解析错误(类型: .格式不支持, 描述: "未找到outbounds配置", 原始内容: nil, 行号: nil))
            return 订阅解析结果(格式: .singbox配置, 节点列表: [], 分流规则列表: [], 错误列表: 错误列表)
        }

        for (索引, outbound) in outbounds.enumerated() {
            let 结果 = 解析单个Outbound(outbound)
            switch 结果 {
            case .success(var 节点):
                if 节点.分组.isEmpty {
                    节点.分组 = "sing-box节点"
                }
                节点列表.append(节点)
            case .failure(let 错误):
                let 带行号错误 = 解析错误(类型: 错误.类型, 描述: 错误.描述, 原始内容: 错误.原始内容, 行号: 索引 + 1)
                错误列表.append(带行号错误)
            }
        }

        // 解析路由规则
        let 分流规则 = 解析路由规则(json)

        return 订阅解析结果(格式: .singbox配置, 节点列表: 节点列表, 分流规则列表: 分流规则, 错误列表: 错误列表)
    }

    // MARK: - 解析路由规则

    /// 从 sing-box 配置中解析路由规则
    private func 解析路由规则(_ json: [String: Any]) -> [分流规则项] {
        guard let route = json["route"] as? [String: Any],
              let rules = route["rules"] as? [[String: Any]] else {
            return []
        }

        var 规则列表: [分流规则项] = []
        var 优先级 = 100

        for 规则字典 in rules {
            let 出站 = 规则字典["outbound"] as? String ?? "proxy"

            // 转换动作
            let 规则动作: 分流动作
            switch 出站.lowercased() {
            case "direct":
                规则动作 = .直连
            case "reject", "block":
                规则动作 = .拦截
            default:
                规则动作 = .代理
            }

            // 域名精确
            if let domains = 规则字典["domain"] as? [String] {
                for 域名 in domains {
                    规则列表.append(分流规则项(名称: "订阅-域名-\(域名)", 类型: .域名精确, 匹配值: 域名, 动作: 规则动作, 优先级: 优先级))
                    优先级 += 1
                }
            }
            // 域名后缀
            if let suffixes = 规则字典["domain_suffix"] as? [String] {
                for 后缀 in suffixes {
                    规则列表.append(分流规则项(名称: "订阅-后缀-\(后缀)", 类型: .域名后缀, 匹配值: 后缀, 动作: 规则动作, 优先级: 优先级))
                    优先级 += 1
                }
            }
            // 域名关键词
            if let keywords = 规则字典["domain_keyword"] as? [String] {
                for 关键词 in keywords {
                    规则列表.append(分流规则项(名称: "订阅-关键词-\(关键词)", 类型: .域名关键词, 匹配值: 关键词, 动作: 规则动作, 优先级: 优先级))
                    优先级 += 1
                }
            }
            // 域名正则
            if let regexes = 规则字典["domain_regex"] as? [String] {
                for 正则 in regexes {
                    规则列表.append(分流规则项(名称: "订阅-正则-\(正则)", 类型: .正则表达式, 匹配值: 正则, 动作: 规则动作, 优先级: 优先级))
                    优先级 += 1
                }
            }
            // IP CIDR
            if let cidrs = 规则字典["ip_cidr"] as? [String] {
                for cidr in cidrs {
                    规则列表.append(分流规则项(名称: "订阅-IP段-\(cidr)", 类型: .IP段, 匹配值: cidr, 动作: 规则动作, 优先级: 优先级))
                    优先级 += 1
                }
            }
        }

        return 规则列表
    }

    // MARK: - 解析单个 Outbound

    /// 解析单个 sing-box outbound 配置
    private func 解析单个Outbound(_ outbound: [String: Any]) -> Result<解析节点模型, 解析错误> {
        guard let 类型 = outbound["type"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "outbound缺少type字段", 原始内容: "\(outbound)", 行号: nil))
        }

        // 跳过非代理类型
        let 代理类型列表 = ["vless", "vmess", "trojan", "shadowsocks", "ss"]
        guard 代理类型列表.contains(类型.lowercased()) else {
            return .failure(解析错误(类型: .协议不支持, 描述: "跳过非代理类型：\(类型)", 原始内容: nil, 行号: nil))
        }

        guard let 地址 = outbound["server"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "outbound缺少server字段", 原始内容: "\(outbound)", 行号: nil))
        }

        guard let 端口值 = outbound["server_port"], let 端口 = Int("\(端口值)") else {
            return .failure(解析错误(类型: .端口无效, 描述: "outbound端口无效", 原始内容: "\(outbound)", 行号: nil))
        }

        let 标签 = outbound["tag"] as? String ?? "\(地址):\(端口)"

        // 根据类型解析
        switch 类型.lowercased() {
        case "vless":
            return 解析VLESSOutbound(outbound, 标签: 标签, 地址: 地址, 端口: 端口)
        case "vmess":
            return 解析VMessOutbound(outbound, 标签: 标签, 地址: 地址, 端口: 端口)
        case "trojan":
            return 解析TrojanOutbound(outbound, 标签: 标签, 地址: 地址, 端口: 端口)
        case "shadowsocks", "ss":
            return 解析SSOutbound(outbound, 标签: 标签, 地址: 地址, 端口: 端口)
        default:
            return .failure(解析错误(类型: .协议不支持, 描述: "不支持的类型：\(类型)", 原始内容: "\(outbound)", 行号: nil))
        }
    }

    // MARK: - VLESS Outbound

    /// 解析 VLESS outbound
    private func 解析VLESSOutbound(_ outbound: [String: Any], 标签: String, 地址: String, 端口: Int) -> Result<解析节点模型, 解析错误> {
        guard let uuid = outbound["uuid"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "VLESS outbound缺少uuid", 原始内容: "\(outbound)", 行号: nil))
        }

        // 传输层配置
        var 传输类型: 传输类型 = .tcp
        if let transport = outbound["transport"] as? [String: Any],
           let type = transport["type"] as? String {
            switch type.lowercased() {
            case "ws": 传输类型 = .ws
            case "grpc": 传输类型 = .grpc
            case "quic": 传输类型 = .quic
            default: 传输类型 = .tcp
            }
        }

        // TLS
        var 启用TLS = false
        var 服务器名称: String? = nil
        if let tls = outbound["tls"] as? [String: Any] {
            启用TLS = true
            服务器名称 = tls["server_name"] as? String
        }

        // WebSocket 路径和主机
        var ws路径: String? = nil
        var ws主机: String? = nil
        if 传输类型 == .ws, let transport = outbound["transport"] as? [String: Any] {
            ws路径 = transport["path"] as? String
            if let headers = transport["headers"] as? [String: Any] {
                ws主机 = headers["Host"] as? String
            }
        }

        let 节点 = 解析节点模型(
            名称: 标签,
            协议: .vless,
            地址: 地址,
            端口: 端口,
            用户标识: uuid,
            传输类型: 传输类型,
            启用TLS: 启用TLS,
            服务器名称: 服务器名称,
            ws路径: ws路径,
            ws主机: ws主机,
            分组: "",
            标签: ["VLESS", "sing-box"],
            原始数据: "\(outbound)"
        )

        return .success(节点)
    }

    // MARK: - VMess Outbound

    /// 解析 VMess outbound
    private func 解析VMessOutbound(_ outbound: [String: Any], 标签: String, 地址: String, 端口: Int) -> Result<解析节点模型, 解析错误> {
        guard let uuid = outbound["uuid"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "VMess outbound缺少uuid", 原始内容: "\(outbound)", 行号: nil))
        }

        var 传输类型: 传输类型 = .tcp
        if let transport = outbound["transport"] as? [String: Any],
           let type = transport["type"] as? String {
            switch type.lowercased() {
            case "ws": 传输类型 = .ws
            case "grpc": 传输类型 = .grpc
            default: 传输类型 = .tcp
            }
        }

        var 启用TLS = false
        var 服务器名称: String? = nil
        if let tls = outbound["tls"] as? [String: Any] {
            启用TLS = true
            服务器名称 = tls["server_name"] as? String
        }

        // WebSocket 路径和主机
        var ws路径: String? = nil
        var ws主机: String? = nil
        if 传输类型 == .ws, let transport = outbound["transport"] as? [String: Any] {
            ws路径 = transport["path"] as? String
            if let headers = transport["headers"] as? [String: Any] {
                ws主机 = headers["Host"] as? String
            }
        }

        let 节点 = 解析节点模型(
            名称: 标签,
            协议: .vmess,
            地址: 地址,
            端口: 端口,
            用户标识: uuid,
            传输类型: 传输类型,
            启用TLS: 启用TLS,
            服务器名称: 服务器名称,
            ws路径: ws路径,
            ws主机: ws主机,
            分组: "",
            标签: ["VMess", "sing-box"],
            原始数据: "\(outbound)"
        )

        return .success(节点)
    }

    // MARK: - Trojan Outbound

    /// 解析 Trojan outbound
    private func 解析TrojanOutbound(_ outbound: [String: Any], 标签: String, 地址: String, 端口: Int) -> Result<解析节点模型, 解析错误> {
        guard let 密码 = outbound["password"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "Trojan outbound缺少password", 原始内容: "\(outbound)", 行号: nil))
        }

        var 启用TLS = true
        var 服务器名称: String? = nil
        if let tls = outbound["tls"] as? [String: Any] {
            启用TLS = true
            服务器名称 = tls["server_name"] as? String
        } else if outbound["tls"] == nil {
            启用TLS = true // Trojan 默认启用 TLS
        }

        let 节点 = 解析节点模型(
            名称: 标签,
            协议: .trojan,
            地址: 地址,
            端口: 端口,
            用户标识: 密码,
            传输类型: .tcp,
            启用TLS: 启用TLS,
            服务器名称: 服务器名称,
            分组: "",
            标签: ["Trojan", "sing-box"],
            原始数据: "\(outbound)"
        )

        return .success(节点)
    }

    // MARK: - Shadowsocks Outbound

    /// 解析 Shadowsocks outbound
    private func 解析SSOutbound(_ outbound: [String: Any], 标签: String, 地址: String, 端口: Int) -> Result<解析节点模型, 解析错误> {
        guard let 方法 = outbound["method"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "SS outbound缺少method", 原始内容: "\(outbound)", 行号: nil))
        }

        guard let 密码 = outbound["password"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "SS outbound缺少password", 原始内容: "\(outbound)", 行号: nil))
        }

        let 节点 = 解析节点模型(
            名称: 标签,
            协议: .shadowsocks,
            地址: 地址,
            端口: 端口,
            用户标识: "\(方法):\(密码)",
            传输类型: .tcp,
            启用TLS: false,
            服务器名称: nil,
            分组: "",
            标签: ["SS", 方法, "sing-box"],
            原始数据: "\(outbound)"
        )

        return .success(节点)
    }
}
