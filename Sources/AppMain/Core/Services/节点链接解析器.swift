//
//  节点链接解析器.swift
//  NewVPN
//
//  各种协议节点链接解析器
//  支持 vless://、vmess://、trojan://、ss:// 等格式
//

import Foundation

// MARK: - 节点链接解析器

/// 节点链接解析器：将各种协议链接解析为统一节点模型
final class 节点链接解析器 {
    /// 共享单例
    static let 共享 = 节点链接解析器()

    /// 私有初始化
    private init() {}

    // MARK: - 主解析入口

    /// 解析单个节点链接
    /// - Parameter 链接: 节点链接字符串
    /// - Returns: 解析结果（成功返回节点模型，失败返回错误）
    func 解析链接(_ 链接: String) -> Result<解析节点模型, 解析错误> {
        let 清理后链接 = 链接.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !清理后链接.isEmpty else {
            return .failure(解析错误(类型: .URL无效, 描述: "链接为空", 原始内容: 链接, 行号: nil))
        }

        // 判断协议类型
        if 清理后链接.hasPrefix("vless://") {
            return 解析VLESS(清理后链接)
        } else if 清理后链接.hasPrefix("vmess://") {
            return 解析VMess(清理后链接)
        } else if 清理后链接.hasPrefix("trojan://") {
            return 解析Trojan(清理后链接)
        } else if 清理后链接.hasPrefix("ss://") {
            return 解析Shadowsocks(清理后链接)
        } else {
            return .failure(解析错误(类型: .协议不支持, 描述: "不支持的协议链接", 原始内容: 链接, 行号: nil))
        }
    }

    /// 批量解析节点链接列表
    func 批量解析(_ 链接列表: [String]) -> (节点: [解析节点模型], 错误: [解析错误]) {
        var 节点列表: [解析节点模型] = []
        var 错误列表: [解析错误] = []

        for (索引, 链接) in 链接列表.enumerated() {
            let 结果 = 解析链接(链接)
            switch 结果 {
            case .success(var 节点):
                // 如果节点没有分组，使用默认分组
                if 节点.分组.isEmpty {
                    节点.分组 = "未分组"
                }
                节点列表.append(节点)
            case .failure(var 错误):
                错误 = 解析错误(类型: 错误.类型, 描述: 错误.描述, 原始内容: 错误.原始内容, 行号: 索引 + 1)
                错误列表.append(错误)
            }
        }

        return (节点列表, 错误列表)
    }

    // MARK: - VLESS 解析

    /// 解析 vless:// 链接
    /// 格式：vless://uuid@host:port?type=ws&security=tls&sni=example.com&path=/path#备注
    private func 解析VLESS(_ 链接: String) -> Result<解析节点模型, 解析错误> {
        guard let url = URL(string: 链接) else {
            return .failure(解析错误(类型: .URL无效, 描述: "VLESS链接格式无效", 原始内容: 链接, 行号: nil))
        }

        // 用户标识（UUID）
        guard let uuid = url.user, !uuid.isEmpty else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "VLESS链接缺少UUID", 原始内容: 链接, 行号: nil))
        }

        // 主机和端口
        guard let host = url.host, !host.isEmpty else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "VLESS链接缺少服务器地址", 原始内容: 链接, 行号: nil))
        }

        guard let port = url.port, port > 0 && port <= 65535 else {
            return .failure(解析错误(类型: .端口无效, 描述: "VLESS链接端口无效", 原始内容: 链接, 行号: nil))
        }

        // 解析查询参数
        let 参数 = 解析查询参数(url.query ?? "")

        // 传输类型
        var 传输类型: 传输类型 = .tcp
        if let type = 参数["type"]?.lowercased() {
            switch type {
            case "ws", "websocket": 传输类型 = .ws
            case "grpc": 传输类型 = .grpc
            case "quic": 传输类型 = .quic
            default: 传输类型 = .tcp
            }
        }

        // TLS
        var 启用TLS = false
        var 服务器名称: String? = nil
        if let security = 参数["security"]?.lowercased() {
            启用TLS = (security == "tls" || security == "reality")
        }
        if let sni = 参数["sni"], !sni.isEmpty {
            服务器名称 = sni
        }

        // WebSocket 路径和主机
        var ws路径: String? = nil
        var ws主机: String? = nil
        if 传输类型 == .ws {
            if let path = 参数["path"], !path.isEmpty {
                ws路径 = path.removingPercentEncoding ?? path
            }
            if let host = 参数["host"], !host.isEmpty {
                ws主机 = host.removingPercentEncoding ?? host
            }
        }

        // 备注（fragment）
        let 名称 = url.fragment?.removingPercentEncoding ?? "\(host):\(port)"

        var 节点 = 解析节点模型(
            名称: 名称,
            协议: .vless,
            地址: host,
            端口: port,
            用户标识: uuid,
            传输类型: 传输类型,
            启用TLS: 启用TLS,
            服务器名称: 服务器名称,
            ws路径: ws路径,
            ws主机: ws主机,
            分组: "",
            标签: ["VLESS"],
            原始数据: 链接
        )

        // 解析额外参数作为警告
        if 参数["flow"] != nil {
            节点.解析警告.append("包含flow参数（XTLS），当前版本可能不完全支持")
        }

        return .success(节点)
    }

    // MARK: - VMess 解析

    /// 解析 vmess:// 链接
    /// 格式：vmess://base64(json)
    /// JSON字段：v, ps, add, port, id, aid, scy, net, type, host, path, tls, sni, alpn
    private func 解析VMess(_ 链接: String) -> Result<解析节点模型, 解析错误> {
        // 移除 vmess:// 前缀
        let base64部分 = String(链接.dropFirst(8))

        guard let 解码数据 = Data(base64Encoded: base64部分, options: .ignoreUnknownCharacters),
              let json字符串 = String(data: 解码数据, encoding: .utf8) else {
            return .failure(解析错误(类型: .解码失败, 描述: "VMess链接Base64解码失败", 原始内容: 链接, 行号: nil))
        }

        guard let json数据 = json字符串.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: json数据) as? [String: Any] else {
            return .failure(解析错误(类型: .JSON解析失败, 描述: "VMess链接JSON解析失败", 原始内容: 链接, 行号: nil))
        }

        // 必要字段
        guard let 地址 = json["add"] as? String, !地址.isEmpty else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "VMess配置缺少服务器地址(add)", 原始内容: 链接, 行号: nil))
        }

        guard let 端口值 = json["port"], let 端口 = Int("\(端口值)"), 端口 > 0 && 端口 <= 65535 else {
            return .failure(解析错误(类型: .端口无效, 描述: "VMess配置端口无效", 原始内容: 链接, 行号: nil))
        }

        guard let uuid = json["id"] as? String, !uuid.isEmpty else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "VMess配置缺少UUID(id)", 原始内容: 链接, 行号: nil))
        }

        // 传输类型
        var 传输类型: 传输类型 = .tcp
        if let net = json["net"] as? String {
            switch net.lowercased() {
            case "ws": 传输类型 = .ws
            case "grpc": 传输类型 = .grpc
            case "quic": 传输类型 = .quic
            default: 传输类型 = .tcp
            }
        }

        // TLS
        var 启用TLS = false
        var 服务器名称: String? = nil
        if let tls = json["tls"] as? String {
            启用TLS = tls.lowercased() == "tls"
        }
        if let sni = json["sni"] as? String, !sni.isEmpty {
            服务器名称 = sni
        } else if let host = json["host"] as? String, !host.isEmpty {
            服务器名称 = host
        }

        // 备注
        let 名称 = (json["ps"] as? String) ?? "\(地址):\(端口)"

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
            标签: ["VMess"],
            原始数据: 链接
        )

        return .success(节点)
    }

    // MARK: - Trojan 解析

    /// 解析 trojan:// 链接
    /// 格式：trojan://password@host:port?security=tls&sni=example.com#备注
    private func 解析Trojan(_ 链接: String) -> Result<解析节点模型, 解析错误> {
        guard let url = URL(string: 链接) else {
            return .failure(解析错误(类型: .URL无效, 描述: "Trojan链接格式无效", 原始内容: 链接, 行号: nil))
        }

        guard let 密码 = url.user, !密码.isEmpty else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "Trojan链接缺少密码", 原始内容: 链接, 行号: nil))
        }

        guard let 地址 = url.host, !地址.isEmpty else {
            return .failure(解析错误(类型: .缺少必要字段, 描述: "Trojan链接缺少服务器地址", 原始内容: 链接, 行号: nil))
        }

        guard let 端口 = url.port, 端口 > 0 && 端口 <= 65535 else {
            return .failure(解析错误(类型: .端口无效, 描述: "Trojan链接端口无效", 原始内容: 链接, 行号: nil))
        }

        let 参数 = 解析查询参数(url.query ?? "")

        var 启用TLS = true // Trojan 默认启用 TLS
        var 服务器名称: String? = nil

        if let security = 参数["security"]?.lowercased() {
            启用TLS = (security == "tls")
        }
        if let sni = 参数["sni"], !sni.isEmpty {
            服务器名称 = sni
        }

        let 名称 = url.fragment?.removingPercentEncoding ?? "\(地址):\(端口)"

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
            标签: ["Trojan"],
            原始数据: 链接
        )

        return .success(节点)
    }

    // MARK: - Shadowsocks 解析

    /// 解析 ss:// 链接
    /// 格式1：ss://base64(method:password)@host:port#备注
    /// 格式2：ss://base64(method:password@host:port)#备注
    /// 格式3：ss://method:password@host:port#备注（明文）
    private func 解析Shadowsocks(_ 链接: String) -> Result<解析节点模型, 解析错误> {
        // 移除 ss:// 前缀
        var 内容 = String(链接.dropFirst(5))

        // 分离备注
        var 备注: String? = nil
        if let 范围 = 内容.range(of: "#") {
            备注 = String(内容[范围.upperBound...]).removingPercentEncoding
            内容 = String(内容[..<范围.lowerBound])
        }

        // 尝试解析为 URL（明文格式）
        if let url = URL(string: "ss://\(内容)"),
           let 用户 = url.user,
           let 主机 = url.host,
           let 端口 = url.port {
            // 明文格式：method:password
            let 部分 = 用户.components(separatedBy: ":")
            guard 部分.count >= 2 else {
                return .failure(解析错误(类型: .缺少必要字段, 描述: "SS链接格式无效（缺少加密方法或密码）", 原始内容: 链接, 行号: nil))
            }
            let 方法 = 部分[0]
            let 密码 = 部分.dropFirst().joined(separator: ":")

            return 构建SS节点(方法: 方法, 密码: 密码, 地址: 主机, 端口: 端口, 备注: 备注, 原始链接: 链接)
        }

        // Base64 编码格式
        guard let 解码数据 = Data(base64Encoded: 内容, options: .ignoreUnknownCharacters),
              let 解码字符串 = String(data: 解码数据, encoding: .utf8) else {
            return .failure(解析错误(类型: .解码失败, 描述: "SS链接Base64解码失败", 原始内容: 链接, 行号: nil))
        }

        // 格式：method:password@host:port 或 method:password
        if let url = URL(string: "ss://\(解码字符串)"),
           let 用户 = url.user,
           let 主机 = url.host,
           let 端口 = url.port {
            let 部分 = 用户.components(separatedBy: ":")
            guard 部分.count >= 2 else {
                return .failure(解析错误(类型: .缺少必要字段, 描述: "SS Base64内容格式无效", 原始内容: 链接, 行号: nil))
            }
            let 方法 = 部分[0]
            let 密码 = 部分.dropFirst().joined(separator: ":")
            return 构建SS节点(方法: 方法, 密码: 密码, 地址: 主机, 端口: 端口, 备注: 备注, 原始链接: 链接)
        }

        return .failure(解析错误(类型: .格式不支持, 描述: "SS链接格式无法识别", 原始内容: 链接, 行号: nil))
    }

    /// 构建 Shadowsocks 节点
    private func 构建SS节点(方法: String, 密码: String, 地址: String, 端口: Int, 备注: String?, 原始链接: String) -> Result<解析节点模型, 解析错误> {
        guard 端口 > 0 && 端口 <= 65535 else {
            return .failure(解析错误(类型: .端口无效, 描述: "SS端口无效", 原始内容: 原始链接, 行号: nil))
        }

        let 名称 = 备注 ?? "\(地址):\(端口)"

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
            标签: ["SS", 方法],
            原始数据: 原始链接
        )

        return .success(节点)
    }

    // MARK: - 工具方法

    /// 解析 URL 查询参数
    private func 解析查询参数(_ 查询: String) -> [String: String] {
        var 参数: [String: String] = [:]
        let 键值对 = 查询.components(separatedBy: "&")
        for 键值 in 键值对 {
            let 部分 = 键值.components(separatedBy: "=")
            if 部分.count == 2 {
                let 键 = 部分[0].removingPercentEncoding ?? 部分[0]
                let 值 = 部分[1].removingPercentEncoding ?? 部分[1]
                参数[键] = 值
            }
        }
        return 参数
    }
}
