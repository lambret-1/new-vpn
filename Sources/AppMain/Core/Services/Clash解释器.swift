//
//  Clash解释器.swift
//  NewVPN
//
//  Clash 订阅配置解释器
//  解析 Clash YAML 配置中的 proxies 数组，转换为统一节点模型
//

import Foundation

// MARK: - Clash 解释器

/// Clash 配置解释器
final class Clash解释器 {
    /// 共享单例
    static let 共享 = Clash解释器()

    /// 私有初始化
    private init() {}

    // MARK: - 主解析入口

    /// 解析 Clash YAML 配置
    /// - Parameter yaml内容: YAML 配置文本
    /// - Returns: 解析结果
    func 解析(_ yaml内容: String) -> 订阅解析结果 {
        var 节点列表: [解析节点模型] = []
        var 错误列表: [解析错误] = []

        // 提取 proxies 部分
        guard let proxies部分 = 提取Proxies部分(yaml内容) else {
            错误列表.append(解析错误(类型: .格式不支持, 描述: "未找到proxies配置段", 原始内容: nil, 行号: nil))
            return 订阅解析结果(格式: .clash配置, 节点列表: [], 错误列表: 错误列表)
        }

        // 解析每个代理节点
        let 代理项列表 = 解析代理项列表(proxies部分)

        for (索引, 代理字典) in 代理项列表.enumerated() {
            let 结果 = 解析单个代理(代理字典)
            switch 结果 {
            case .success(var 节点):
                if 节点.分组.isEmpty {
                    节点.分组 = "Clash节点"
                }
                节点列表.append(节点)
            case .failure(let 错误):
                let 带行号错误 = 解析错误(类型: 错误.类型, 描述: 错误.描述, 原始内容: 错误.原始内容, 行号: 索引 + 1)
                错误列表.append(带行号错误)
            }
        }

        return 订阅解析结果(格式: .clash配置, 节点列表: 节点列表, 错误列表: 错误列表)
    }

    // MARK: - 提取 proxies 部分

    /// 从 YAML 中提取 proxies 配置段
    private func 提取Proxies部分(_ yaml: String) -> String? {
        let 行列表 = yaml.components(separatedBy: .newlines)
        var 开始行 = -1
        var 结束行 = 行列表.count

        for (索引, 行) in 行列表.enumerated() {
            let 修剪后 = 行.trimmingCharacters(in: .whitespaces)

            // 匹配 proxies: 开头（顶层键）
            if 开始行 == -1 && (修剪后.hasPrefix("proxies:") || 修剪后 == "proxies:") {
                开始行 = 索引 + 1
                continue
            }

            // 找到下一个顶层键（无缩进的键），作为结束
            if 开始行 != -1 && 索引 > 开始行 {
                if !行.hasPrefix(" ") && !行.hasPrefix("\t") && !修剪后.isEmpty && !修剪后.hasPrefix("#") {
                    // 检查是否是顶层键（包含冒号且不是数组项）
                    if 修剪后.contains(":") && !修剪后.hasPrefix("-") {
                        结束行 = 索引
                        break
                    }
                }
            }
        }

        guard 开始行 != -1 else { return nil }

        let 部分 = 行列表[开始行..<min(结束行, 行列表.count)].joined(separator: "\n")
        return 部分
    }

    // MARK: - 解析代理项列表

    /// 解析 proxies 部分中的代理项列表
    private func 解析代理项列表(_ proxies部分: String) -> [[String: Any]] {
        let 行列表 = proxies部分.components(separatedBy: .newlines)
        var 代理列表: [[String: Any]] = []
        var 当前代理: [String: Any] = [:]
        var 当前嵌套键: String? = nil
        var 当前嵌套字典: [String: Any] = [:]

        for 行 in 行列表 {
            let 修剪后 = 行.trimmingCharacters(in: .whitespaces)

            // 跳过空行和注释
            guard !修剪后.isEmpty && !修剪后.hasPrefix("#") else { continue }

            // 新代理项开始（以 - 开头，缩进2空格）
            if 行.hasPrefix("  - ") || 行.hasPrefix("  -") {
                // 保存上一个代理
                if !当前代理.isEmpty {
                    if let 嵌套键 = 当前嵌套键 {
                        当前代理[嵌套键] = 当前嵌套字典
                    }
                    代理列表.append(当前代理)
                }
                当前代理 = [:]
                当前嵌套键 = nil
                当前嵌套字典 = [:]

                // 解析 - name: "xxx" 格式
                let 内容 = String(修剪后.dropFirst(2)) // 移除 "- "
                if let 键值 = 解析键值对(内容) {
                    当前代理[键值.键] = 键值.值
                }
                continue
            }

            // 代理属性（缩进4空格）
            if 行.hasPrefix("    ") && !行.hasPrefix("      ") {
                if let 键值 = 解析键值对(修剪后) {
                    // 检查是否是嵌套对象的开始（值为空，下一行有更深缩进）
                    if 键值.值 is NSNull || (键值.值 as? String)?.isEmpty == true {
                        // 保存之前的嵌套
                        if let 嵌套键 = 当前嵌套键 {
                            当前代理[嵌套键] = 当前嵌套字典
                        }
                        当前嵌套键 = 键值.键
                        当前嵌套字典 = [:]
                    } else {
                        // 保存之前的嵌套
                        if let 嵌套键 = 当前嵌套键 {
                            当前代理[嵌套键] = 当前嵌套字典
                            当前嵌套键 = nil
                            当前嵌套字典 = [:]
                        }
                        当前代理[键值.键] = 键值.值
                    }
                }
                continue
            }

            // 嵌套对象属性（缩进6空格或更多）
            if 行.hasPrefix("      ") {
                if let 键值 = 解析键值对(修剪后) {
                    当前嵌套字典[键值.键] = 键值.值
                }
                continue
            }
        }

        // 保存最后一个代理
        if !当前代理.isEmpty {
            if let 嵌套键 = 当前嵌套键 {
                当前代理[嵌套键] = 当前嵌套字典
            }
            代理列表.append(当前代理)
        }

        return 代理列表
    }

    // MARK: - 解析键值对

    /// 解析 YAML 键值对
    private func 解析键值对(_ 文本: String) -> (键: String, 值: Any)? {
        guard let 冒号范围 = 文本.range(of: ":") else { return nil }

        let 键 = String(文本[..<冒号范围.lowerBound]).trimmingCharacters(in: .whitespaces)
        var 值文本 = String(文本[冒号范围.upperBound...]).trimmingCharacters(in: .whitespaces)

        // 移除引号
        if (值文本.hasPrefix("\"") && 值文本.hasSuffix("\"")) ||
           (值文本.hasPrefix("'") && 值文本.hasSuffix("'")) {
            值文本 = String(值文本.dropFirst().dropLast())
        }

        // 转换值类型
        let 值: Any
        if 值文本.isEmpty {
            值 = NSNull()
        } else if let 整数 = Int(值文本) {
            值 = 整数
        } else if let 浮点 = Double(值文本) {
            值 = 浮点
        } else if 值文本.lowercased() == "true" {
            值 = true
        } else if 值文本.lowercased() == "false" {
            值 = false
        } else {
            值 = 值文本
        }

        return (键, 值)
    }

    // MARK: - 解析单个代理

    /// 解析单个 Clash 代理配置
    private func 解析单个代理(_ 代理: [String: Any]) -> Result<解析节点模型, 解析错误> {
        // 必要字段
        guard let 类型 = 代理["type"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "代理缺少type字段", 原始内容: "\(代理)", 行号: nil))
        }

        guard let 地址 = 代理["server"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "代理缺少server字段", 原始内容: "\(代理)", 行号: nil))
        }

        guard let 端口值 = 代理["port"], let 端口 = Int("\(端口值)") else {
            return .failure(解析错误(类型: .端口无效, 描述: "代理端口无效", 原始内容: "\(代理)", 行号: nil))
        }

        let 名称 = (代理["name"] as? String) ?? "\(地址):\(端口)"

        // 根据类型解析
        switch 类型.lowercased() {
        case "vmess":
            return 解析VMess代理(代理, 名称: 名称, 地址: 地址, 端口: 端口)
        case "vless":
            return 解析VLESS代理(代理, 名称: 名称, 地址: 地址, 端口: 端口)
        case "trojan":
            return 解析Trojan代理(代理, 名称: 名称, 地址: 地址, 端口: 端口)
        case "ss", "shadowsocks":
            return 解析SS代理(代理, 名称: 名称, 地址: 地址, 端口: 端口)
        default:
            return .failure(解析错误(类型: .协议不支持, 描述: "不支持的代理类型：\(类型)", 原始内容: "\(代理)", 行号: nil))
        }
    }

    /// 解析 VMess 代理
    private func 解析VMess代理(_ 代理: [String: Any], 名称: String, 地址: String, 端口: Int) -> Result<解析节点模型, 解析错误> {
        guard let uuid = 代理["uuid"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "VMess代理缺少uuid", 原始内容: "\(代理)", 行号: nil))
        }

        // 传输类型
        var 传输类型: 传输类型 = .tcp
        if let network = 代理["network"] as? String {
            switch network.lowercased() {
            case "ws": 传输类型 = .ws
            case "grpc": 传输类型 = .grpc
            default: 传输类型 = .tcp
            }
        }

        // TLS
        let 启用TLS = (代理["tls"] as? Bool) ?? false
        var 服务器名称 = 代理["servername"] as? String
        if 服务器名称 == nil, let wsOpts = 代理["ws-opts"] as? [String: Any],
           let headers = wsOpts["headers"] as? [String: Any] {
            服务器名称 = headers["Host"] as? String
        }

        let 节点 = 解析节点模型(
            名称: 名称,
            协议: .vmess,
            地址: 地址,
            端口: 端口,
            用户标识: uuid,
            传输类型: 传输类型,
            启用TLS: 启用TLS,
            服务器名称: 服务器名称,
            分组: "",
            标签: ["VMess", "Clash"],
            原始数据: "\(代理)"
        )

        return .success(节点)
    }

    /// 解析 VLESS 代理
    private func 解析VLESS代理(_ 代理: [String: Any], 名称: String, 地址: String, 端口: Int) -> Result<解析节点模型, 解析错误> {
        guard let uuid = 代理["uuid"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "VLESS代理缺少uuid", 原始内容: "\(代理)", 行号: nil))
        }

        var 传输类型: 传输类型 = .tcp
        if let network = 代理["network"] as? String {
            switch network.lowercased() {
            case "ws": 传输类型 = .ws
            case "grpc": 传输类型 = .grpc
            default: 传输类型 = .tcp
            }
        }

        let 启用TLS = (代理["tls"] as? Bool) ?? false
        let 服务器名称 = 代理["servername"] as? String

        let 节点 = 解析节点模型(
            名称: 名称,
            协议: .vless,
            地址: 地址,
            端口: 端口,
            用户标识: uuid,
            传输类型: 传输类型,
            启用TLS: 启用TLS,
            服务器名称: 服务器名称,
            分组: "",
            标签: ["VLESS", "Clash"],
            原始数据: "\(代理)"
        )

        return .success(节点)
    }

    /// 解析 Trojan 代理
    private func 解析Trojan代理(_ 代理: [String: Any], 名称: String, 地址: String, 端口: Int) -> Result<解析节点模型, 解析错误> {
        guard let 密码 = 代理["password"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "Trojan代理缺少password", 原始内容: "\(代理)", 行号: nil))
        }

        let 启用TLS = (代理["tls"] as? Bool) ?? true
        let 服务器名称 = 代理["servername"] as? String

        let 节点 = 解析节点模型(
            名称: 名称,
            协议: .trojan,
            地址: 地址,
            端口: 端口,
            用户标识: 密码,
            传输类型: .tcp,
            启用TLS: 启用TLS,
            服务器名称: 服务器名称,
            分组: "",
            标签: ["Trojan", "Clash"],
            原始数据: "\(代理)"
        )

        return .success(节点)
    }

    /// 解析 Shadowsocks 代理
    private func 解析SS代理(_ 代理: [String: Any], 名称: String, 地址: String, 端口: Int) -> Result<解析节点模型, 解析错误> {
        guard let 密码 = 代理["password"] as? String else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "SS代理缺少password", 原始内容: "\(代理)", 行号: nil))
        }

        let 方法 = (代理["cipher"] as? String) ?? "aes-256-gcm"

        let 节点 = 解析节点模型(
            名称: 名称,
            协议: .shadowsocks,
            地址: 地址,
            端口: 端口,
            用户标识: "\(方法):\(密码)",
            传输类型: .tcp,
            启用TLS: false,
            服务器名称: nil,
            分组: "",
            标签: ["SS", 方法, "Clash"],
            原始数据: "\(代理)"
        )

        return .success(节点)
    }
}
