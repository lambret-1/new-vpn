//
//  配置描述文件服务.swift
//  NewVPN
//
//  配置描述文件服务
//  负责配置文件的加载、保存、导入、导出、验证、版本管理
//

import Foundation

/// 配置描述文件服务
final class 配置描述文件服务 {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = 配置描述文件服务()

    // MARK: - 属性

    /// 文件管理器
    private let 文件管理 = FileManager.default

    /// 配置目录 URL
    private var 配置目录: URL? {
        guard let 文档目录 = 文件管理.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let 目录 = 文档目录.appendingPathComponent("configs", isDirectory: true)
        // 确保目录存在
        if !文件管理.fileExists(atPath: 目录.path) {
            try? 文件管理.createDirectory(at: 目录, withIntermediateDirectories: true)
        }
        return 目录
    }

    /// 版本备份目录 URL
    private var 版本目录: URL? {
        guard let 配置目录 = 配置目录 else { return nil }
        let 目录 = 配置目录.appendingPathComponent("versions", isDirectory: true)
        if !文件管理.fileExists(atPath: 目录.path) {
            try? 文件管理.createDirectory(at: 目录, withIntermediateDirectories: true)
        }
        return 目录
    }

    /// 元数据文件路径
    private var 元数据路径: URL? {
        配置目录?.appendingPathComponent("metadata.json")
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 元数据管理

    /// 加载所有配置元数据
    func 加载元数据列表() -> [配置描述文件] {
        guard let 路径 = 元数据路径,
              let 数据 = try? Data(contentsOf: 路径),
              let 列表 = try? JSONDecoder().decode([配置描述文件].self, from: 数据) else {
            return []
        }
        return 列表
    }

    /// 保存配置元数据列表
    func 保存元数据列表(_ 列表: [配置描述文件]) -> Bool {
        guard let 路径 = 元数据路径,
              let 数据 = try? JSONEncoder().encode(列表) else {
            return false
        }
        do {
            try 数据.write(to: 路径)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 配置文件内容管理

    /// 加载配置文件内容
    func 加载配置内容(_ 配置: 配置描述文件) -> String? {
        guard let 目录 = 配置目录 else { return nil }
        let 文件URL = 目录.appendingPathComponent(配置.文件路径)
        guard 文件管理.fileExists(atPath: 文件URL.path) else { return nil }
        return try? String(contentsOf: 文件URL, encoding: .utf8)
    }

    /// 保存配置文件内容
    func 保存配置内容(_ 配置: 配置描述文件, 内容: String) -> Bool {
        guard let 目录 = 配置目录 else { return false }
        let 文件URL = 目录.appendingPathComponent(配置.文件路径)
        // 确保父目录存在
        let 父目录 = 文件URL.deletingLastPathComponent()
        if !文件管理.fileExists(atPath: 父目录.path) {
            try? 文件管理.createDirectory(at: 父目录, withIntermediateDirectories: true)
        }
        do {
            try 内容.write(to: 文件URL, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// 删除配置文件
    func 删除配置文件(_ 配置: 配置描述文件) -> Bool {
        guard let 目录 = 配置目录 else { return false }
        let 文件URL = 目录.appendingPathComponent(配置.文件路径)
        guard 文件管理.fileExists(atPath: 文件URL.path) else { return true }
        do {
            try 文件管理.removeItem(at: 文件URL)
            return true
        } catch {
            return false
        }
    }

    /// 复制配置文件
    func 复制配置文件(源配置: 配置描述文件, 新名称: String) -> 配置描述文件? {
        guard let 内容 = 加载配置内容(源配置) else { return nil }
        let 新ID = UUID()
        let 新路径 = "configs/\(新ID.uuidString).json"
        var 新配置 = 源配置
        新配置.id = 新ID
        新配置.名称 = 新名称
        新配置.文件路径 = 新路径
        新配置.是否激活 = false
        新配置.是否默认 = false
        新配置.创建时间 = Date()
        新配置.最后修改时间 = Date()
        新配置.最后使用时间 = nil
        新配置.版本号 = 1
        新配置.版本 = "1.0.0"
        新配置.关联订阅ID = nil
        新配置.关联订阅名称 = nil
        新配置.标签 = ["副本"]
        新配置.备注 = "复制自「\(源配置.名称)」"

        guard 保存配置内容(新配置, 内容: 内容) else { return nil }
        return 新配置
    }

    // MARK: - 配置文件导入

    /// 从 URL 导入配置文件
    func 从URL导入配置(文件URL: URL, 名称: String? = nil) -> 配置文件导入结果 {
        // 检查文件是否存在
        guard 文件管理.fileExists(atPath: 文件URL.path) else {
            return .失败(错误: "文件不存在")
        }

        // 读取文件内容
        guard let 内容 = try? String(contentsOf: 文件URL, encoding: .utf8) else {
            return .失败(错误: "无法读取文件内容")
        }

        // 检测文件类型
        let 类型 = 检测配置类型(内容: 内容, 文件扩展名: 文件URL.pathExtension)

        // 验证配置
        let 验证结果 = 验证配置内容(内容, 类型: 类型)
        if !验证结果.有效 {
            return .失败(错误: 验证结果.错误 ?? "配置验证失败")
        }

        // 创建配置描述
        let 配置ID = UUID()
        let 配置名称 = 名称 ?? 文件URL.deletingPathExtension().lastPathComponent
        let 文件路径 = "configs/\(配置ID.uuidString).\(类型.文件扩展名)"

        var 配置 = 配置描述文件(
            id: 配置ID,
            名称: 配置名称,
            描述: "从文件导入的配置",
            类型: 类型,
            状态: .正常,
            版本: "1.0.0",
            版本号: 1,
            创建时间: Date(),
            最后修改时间: Date(),
            最后使用时间: nil,
            是否激活: false,
            是否默认: false,
            关联订阅ID: nil,
            关联订阅名称: nil,
            文件路径: 文件路径,
            统计: 计算配置统计(内容, 类型: 类型),
            标签: ["导入"],
            备注: nil,
            自动更新: false,
            更新间隔分钟: 360,
            上次更新时间: nil,
            更新错误: nil
        )

        // 保存配置内容
        guard 保存配置内容(配置, 内容: 内容) else {
            return .失败(错误: "保存配置文件失败")
        }

        // 更新文件大小
        if let 目录 = 配置目录 {
            let 文件URL = 目录.appendingPathComponent(配置.文件路径)
            if let 属性 = try? 文件管理.attributesOfItem(atPath: 文件URL.path),
               let 大小 = 属性[.size] as? Int64 {
                配置.统计.文件大小 = 大小
            }
        }

        return .成功(配置: 配置, 警告: 验证结果.警告)
    }

    /// 从字符串导入配置
    func 从字符串导入配置(内容: String, 名称: String, 类型: 配置文件类型 = .singbox) -> 配置文件导入结果 {
        // 验证配置
        let 验证结果 = 验证配置内容(内容, 类型: 类型)
        if !验证结果.有效 {
            return .失败(错误: 验证结果.错误 ?? "配置验证失败")
        }

        // 创建配置描述
        let 配置ID = UUID()
        let 文件路径 = "configs/\(配置ID.uuidString).\(类型.文件扩展名)"

        var 配置 = 配置描述文件(
            id: 配置ID,
            名称: 名称,
            描述: "从文本导入的配置",
            类型: 类型,
            状态: .正常,
            版本: "1.0.0",
            版本号: 1,
            创建时间: Date(),
            最后修改时间: Date(),
            最后使用时间: nil,
            是否激活: false,
            是否默认: false,
            关联订阅ID: nil,
            关联订阅名称: nil,
            文件路径: 文件路径,
            统计: 计算配置统计(内容, 类型: 类型),
            标签: ["导入"],
            备注: nil,
            自动更新: false,
            更新间隔分钟: 360,
            上次更新时间: nil,
            更新错误: nil
        )

        // 保存配置内容
        guard 保存配置内容(配置, 内容: 内容) else {
            return .失败(错误: "保存配置文件失败")
        }

        // 更新文件大小
        if let 目录 = 配置目录 {
            let 文件URL = 目录.appendingPathComponent(配置.文件路径)
            if let 属性 = try? 文件管理.attributesOfItem(atPath: 文件URL.path),
               let 大小 = 属性[.size] as? Int64 {
                配置.统计.文件大小 = 大小
            }
        }

        return .成功(配置: 配置, 警告: 验证结果.警告)
    }

    // MARK: - 配置文件导出

    /// 导出配置文件
    func 导出配置(_ 配置: 配置描述文件, 选项: 配置文件导出选项 = .默认) -> URL? {
        guard let 内容 = 加载配置内容(配置) else { return nil }
        guard let 临时目录 = 文件管理.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let 导出文件名 = "\(配置.名称).\(选项.导出格式.文件扩展名)"
        let 导出URL = 临时目录.appendingPathComponent(导出文件名)

        var 导出内容 = 内容

        // 如果不包含敏感信息，需要脱敏处理
        if !选项.包含敏感信息 {
            导出内容 = 脱敏配置内容(内容, 类型: 配置.类型)
        }

        do {
            try 导出内容.write(to: 导出URL, atomically: true, encoding: .utf8)
            return 导出URL
        } catch {
            return nil
        }
    }

    // MARK: - 配置验证

    /// 验证配置内容
    func 验证配置内容(_ 内容: String, 类型: 配置文件类型) -> (有效: Bool, 错误: String?, 警告: [String]) {
        var 警告列表: [String] = []

        switch 类型 {
        case .singbox:
            // 验证 JSON 格式
            guard let 数据 = 内容.data(using: .utf8),
                  let JSON = try? JSONSerialization.jsonObject(with: 数据) as? [String: Any] else {
                return (false, "无效的 JSON 格式", [])
            }

            // 检查必要字段
            if JSON["outbounds"] == nil {
                警告列表.append("配置中没有出站（outbounds）配置")
            }
            if JSON["inbounds"] == nil {
                警告列表.append("配置中没有入站（inbounds）配置")
            }
            if JSON["route"] == nil {
                警告列表.append("配置中没有路由（route）配置")
            }

            return (true, nil, 警告列表)

        case .clash:
            // 简化的 YAML 验证
            if 内容.contains("proxies:") || 内容.contains("proxy-groups:") {
                return (true, nil, 警告列表)
            }
            警告列表.append("配置中可能没有代理节点配置")
            return (true, nil, 警告列表)

        case .v2ray:
            guard let 数据 = 内容.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: 数据)) != nil else {
                return (false, "无效的 JSON 格式", [])
            }
            return (true, nil, 警告列表)

        case .manual:
            return (true, nil, 警告列表)
        }
    }

    // MARK: - 配置类型检测

    /// 检测配置类型
    func 检测配置类型(内容: String, 文件扩展名: String) -> 配置文件类型 {
        // 先根据扩展名判断
        switch 文件扩展名.lowercased() {
        case "yaml", "yml":
            return .clash
        case "json":
            // JSON 可能是 sing-box 或 v2ray，根据内容判断
            if 内容.contains("\"outbounds\"") || 内容.contains("\"inbounds\"") || 内容.contains("\"route\"") {
                return .singbox
            }
            if 内容.contains("\"outbounds\"") && 内容.contains("\"inbounds\"") {
                return .v2ray
            }
            return .singbox
        default:
            break
        }

        // 根据内容判断
        if 内容.contains("proxies:") || 内容.contains("proxy-groups:") {
            return .clash
        }
        if 内容.contains("\"outbounds\"") || 内容.contains("\"inbounds\"") {
            return .singbox
        }

        return .singbox
    }

    // MARK: - 配置统计

    /// 计算配置统计信息
    func 计算配置统计(_ 内容: String, 类型: 配置文件类型) -> 配置文件统计 {
        var 统计 = 配置文件统计.默认
        统计.文件大小 = Int64(内容.utf8.count)

        switch 类型 {
        case .singbox:
            if let 数据 = 内容.data(using: .utf8),
               let JSON = try? JSONSerialization.jsonObject(with: 数据) as? [String: Any] {
                if let 出站列表 = JSON["outbounds"] as? [[String: Any]] {
                    统计.出站数量 = 出站列表.count
                    统计.节点数量 = 出站列表.filter { 出站 in
                        let 类型 = 出站["type"] as? String ?? ""
                        return ["vless", "vmess", "trojan", "shadowsocks", "socks", "http"].contains(类型)
                    }.count
                }
                if let 入站列表 = JSON["inbounds"] as? [[String: Any]] {
                    统计.入站数量 = 入站列表.count
                }
                if let 路由 = JSON["route"] as? [String: Any],
                   let 规则列表 = 路由["rules"] as? [[String: Any]] {
                    统计.路由规则数量 = 规则列表.count
                }
                if let DNS = JSON["dns"] as? [String: Any],
                   let 服务器列表 = DNS["servers"] as? [Any] {
                    统计.DNS服务器数量 = 服务器列表.count
                }
            }

        case .clash:
            // 简化统计
            if let 范围 = 内容.range(of: "proxies:") {
                let 之后内容 = String(内容[范围.upperBound...])
                if let 下一个节 = 之后内容.firstIndex(of: "\n") {
                    let 代理节 = String(之后内容[..<下一个节])
                    统计.节点数量 = 代理节.components(separatedBy: "\n").filter { $0.contains("- name:") }.count
                }
            }

        default:
            break
        }

        return 统计
    }

    // MARK: - 版本管理

    /// 创建配置版本备份
    func 创建版本备份(_ 配置: 配置描述文件, 修改说明: String? = nil) -> 配置文件版本记录? {
        guard let 内容 = 加载配置内容(配置),
              let 版本目录 = 版本目录 else { return nil }

        let 版本ID = UUID()
        let 新版本号 = 配置.版本号 + 1
        let 版本路径 = "versions/\(配置.id.uuidString)/v\(新版本号).json"
        let 版本文件URL = 版本目录.appendingPathComponent("\(配置.id.uuidString)/v\(新版本号).json")

        // 确保目录存在
        let 父目录 = 版本文件URL.deletingLastPathComponent()
        if !文件管理.fileExists(atPath: 父目录.path) {
            try? 文件管理.createDirectory(at: 父目录, withIntermediateDirectories: true)
        }

        do {
            try 内容.write(to: 版本文件URL, atomically: true, encoding: .utf8)

            let 文件大小 = (try? 文件管理.attributesOfItem(atPath: 版本文件URL.path)[.size] as? Int64) ?? 0

            return 配置文件版本记录(
                id: 版本ID,
                配置ID: 配置.id,
                版本号: 新版本号,
                版本名称: "v\(新版本号).0.0",
                创建时间: Date(),
                修改说明: 修改说明,
                文件路径: 版本路径,
                文件大小: 文件大小
            )
        } catch {
            return nil
        }
    }

    /// 加载配置版本列表
    func 加载版本列表(_ 配置ID: UUID) -> [配置文件版本记录] {
        guard let 版本目录 = 版本目录 else { return [] }
        let 配置版本目录 = 版本目录.appendingPathComponent(配置ID.uuidString)
        guard 文件管理.fileExists(atPath: 配置版本目录.path) else { return [] }

        var 版本列表: [配置文件版本记录] = []
        if let 文件列表 = try? 文件管理.contentsOfDirectory(at: 配置版本目录, includingPropertiesForKeys: nil) {
            for 文件URL in 文件列表 where 文件URL.pathExtension == "json" {
                let 版本号字符串 = 文件URL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "v", with: "")
                let 版本号 = Int(版本号字符串) ?? 0
                let 文件大小 = (try? 文件管理.attributesOfItem(atPath: 文件URL.path)[.size] as? Int64) ?? 0

                版本列表.append(配置文件版本记录(
                    id: UUID(),
                    配置ID: 配置ID,
                    版本号: 版本号,
                    版本名称: "v\(版本号).0.0",
                    创建时间: Date(),
                    修改说明: nil,
                    文件路径: "versions/\(配置ID.uuidString)/v\(版本号).json",
                    文件大小: 文件大小
                ))
            }
        }

        return 版本列表.sorted { $0.版本号 > $1.版本号 }
    }

    /// 恢复配置版本
    func 恢复版本(_ 版本: 配置文件版本记录, 到配置: 配置描述文件) -> Bool {
        guard let 版本目录 = 版本目录 else { return false }
        let 版本文件URL = 版本目录.appendingPathComponent(版本.文件路径)
        guard let 内容 = try? String(contentsOf: 版本文件URL, encoding: .utf8) else { return false }
        return 保存配置内容(到配置, 内容: 内容)
    }

    // MARK: - 私有方法

    /// 脱敏配置内容（移除敏感信息）
    private func 脱敏配置内容(_ 内容: String, 类型: 配置文件类型) -> String {
        var 脱敏内容 = 内容

        switch 类型 {
        case .singbox:
            // 替换 UUID
            let UUID模式 = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
            if let 正则 = try? NSRegularExpression(pattern: UUID模式) {
                脱敏内容 = 正则.stringByReplacingMatches(
                    in: 脱敏内容,
                    range: NSRange(脱敏内容.startIndex..., in: 脱敏内容),
                    withTemplate: "********-****-****-****-************"
                )
            }
            // 替换密码
            脱敏内容 = 脱敏内容.replacingOccurrences(of: "\"password\":\\s*\"[^\"]+\"", with: "\"password\": \"********\"", options: .regularExpression)

        default:
            break
        }

        return 脱敏内容
    }
}
