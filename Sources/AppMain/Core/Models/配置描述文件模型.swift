//
//  配置描述文件模型.swift
//  NewVPN
//
//  配置描述文件数据模型
//  管理 sing-box 配置文件的元数据、版本、关联信息
//

import Foundation

// MARK: - 配置文件类型

/// 配置文件类型
enum 配置文件类型: String, Codable, CaseIterable {
    /// sing-box 原生配置
    case singbox = "sing-box"
    /// Clash 配置
    case clash = "Clash"
    /// V2Ray 配置
    case v2ray = "V2Ray"
    /// 手动配置
    case manual = "手动"

    /// 显示名称
    var 显示名称: String { rawValue }

    /// 文件扩展名
    var 文件扩展名: String {
        switch self {
        case .singbox: return "json"
        case .clash: return "yaml"
        case .v2ray: return "json"
        case .manual: return "json"
        }
    }
}

// MARK: - 配置文件状态

/// 配置文件状态
enum 配置文件状态: String, Codable, CaseIterable {
    /// 正常
    case 正常 = "正常"
    /// 已损坏
    case 已损坏 = "已损坏"
    /// 验证失败
    case 验证失败 = "验证失败"
    /// 正在导入
    case 正在导入 = "正在导入"
    /// 导入失败
    case 导入失败 = "导入失败"

    /// 状态颜色
    var 状态颜色: String {
        switch self {
        case .正常: return "成功色"
        case .已损坏, .验证失败, .导入失败: return "危险色"
        case .正在导入: return "警告色"
        }
    }
}

// MARK: - 配置文件统计信息

/// 配置文件统计信息
struct 配置文件统计: Codable, Hashable {
    /// 节点数量
    var 节点数量: Int
    /// 出站数量
    var 出站数量: Int
    /// 入站数量
    var 入站数量: Int
    /// 路由规则数量
    var 路由规则数量: Int
    /// DNS 服务器数量
    var DNS服务器数量: Int
    /// 文件大小（字节）
    var 文件大小: Int64

    /// 默认统计
    static let 默认 = 配置文件统计(
        节点数量: 0,
        出站数量: 0,
        入站数量: 0,
        路由规则数量: 0,
        DNS服务器数量: 0,
        文件大小: 0
    )
}

// MARK: - 配置描述文件

/// 配置描述文件数据模型
struct 配置描述文件: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 配置名称
    var 名称: String
    /// 配置描述
    var 描述: String?
    /// 配置类型
    var 类型: 配置文件类型
    /// 配置状态
    var 状态: 配置文件状态
    /// 配置版本
    var 版本: String
    /// 版本号（用于内部比较）
    var 版本号: Int
    /// 创建时间
    let 创建时间: Date
    /// 最后修改时间
    var 最后修改时间: Date
    /// 最后使用时间
    var 最后使用时间: Date?
    /// 是否为当前激活配置
    var 是否激活: Bool
    /// 是否为默认配置
    var 是否默认: Bool
    /// 关联的订阅 ID
    var 关联订阅ID: UUID?
    /// 关联的订阅名称
    var 关联订阅名称: String?
    /// 配置文件路径（相对沙盒）
    var 文件路径: String
    /// 配置文件统计
    var 统计: 配置文件统计
    /// 标签
    var 标签: [String]
    /// 备注
    var 备注: String?
    /// 是否自动更新
    var 自动更新: Bool
    /// 更新间隔（分钟）
    var 更新间隔分钟: Int
    /// 上次更新时间
    var 上次更新时间: Date?
    /// 更新错误信息
    var 更新错误: String?

    /// 创建时间显示
    var 创建时间显示: String {
        let 格式化 = DateFormatter()
        格式化.dateFormat = "yyyy-MM-dd HH:mm"
        return 格式化.string(from: 创建时间)
    }

    /// 最后修改时间显示
    var 最后修改时间显示: String {
        let 格式化 = DateFormatter()
        格式化.dateFormat = "yyyy-MM-dd HH:mm"
        return 格式化.string(from: 最后修改时间)
    }

    /// 文件大小显示
    var 文件大小显示: String {
        let 字节数 = Double(统计.文件大小)
        if 字节数 < 1024 {
            return "\(Int(字节数)) B"
        } else if 字节数 < 1024 * 1024 {
            return String(format: "%.1f KB", 字节数 / 1024)
        } else {
            return String(format: "%.2f MB", 字节数 / (1024 * 1024))
        }
    }

    /// 使用频率描述
    var 使用频率描述: String {
        guard let 最后使用 = 最后使用时间 else { return "未使用" }
        let 间隔 = Date().timeIntervalSince(最后使用)
        if 间隔 < 60 {
            return "刚刚使用"
        } else if 间隔 < 3600 {
            return "\(Int(间隔 / 60)) 分钟前使用"
        } else if 间隔 < 86400 {
            return "\(Int(间隔 / 3600)) 小时前使用"
        } else {
            return "\(Int(间隔 / 86400)) 天前使用"
        }
    }

    /// 默认配置
    static func 默认配置() -> 配置描述文件 {
        配置描述文件(
            id: UUID(),
            名称: "默认配置",
            描述: "系统默认生成的 sing-box 配置",
            类型: .singbox,
            状态: .正常,
            版本: "1.0.0",
            版本号: 1,
            创建时间: Date(),
            最后修改时间: Date(),
            最后使用时间: nil,
            是否激活: true,
            是否默认: true,
            关联订阅ID: nil,
            关联订阅名称: nil,
            文件路径: "configs/default.json",
            统计: .默认,
            标签: ["默认"],
            备注: nil,
            自动更新: false,
            更新间隔分钟: 360,
            上次更新时间: nil,
            更新错误: nil
        )
    }

    /// 从订阅创建配置
    static func 从订阅创建(订阅名称: String, 订阅ID: UUID) -> 配置描述文件 {
        配置描述文件(
            id: UUID(),
            名称: 订阅名称,
            描述: "从订阅「\(订阅名称)」导入的配置",
            类型: .singbox,
            状态: .正在导入,
            版本: "1.0.0",
            版本号: 1,
            创建时间: Date(),
            最后修改时间: Date(),
            最后使用时间: nil,
            是否激活: false,
            是否默认: false,
            关联订阅ID: 订阅ID,
            关联订阅名称: 订阅名称,
            文件路径: "configs/\(订阅ID.uuidString).json",
            统计: .默认,
            标签: ["订阅"],
            备注: nil,
            自动更新: true,
            更新间隔分钟: 360,
            上次更新时间: nil,
            更新错误: nil
        )
    }
}

// MARK: - 配置文件导入结果

/// 配置文件导入结果
struct 配置文件导入结果 {
    /// 是否成功
    let 成功: Bool
    /// 导入的配置
    let 配置: 配置描述文件?
    /// 错误信息
    let 错误信息: String?
    /// 警告信息
    let 警告信息: [String]

    /// 成功结果
    static func 成功(配置: 配置描述文件, 警告: [String] = []) -> 配置文件导入结果 {
        配置文件导入结果(成功: true, 配置: 配置, 错误信息: nil, 警告信息: 警告)
    }

    /// 失败结果
    static func 失败(错误: String) -> 配置文件导入结果 {
        配置文件导入结果(成功: false, 配置: nil, 错误信息: 错误, 警告信息: [])
    }
}

// MARK: - 配置文件导出选项

/// 配置文件导出选项
struct 配置文件导出选项 {
    /// 是否包含敏感信息
    var 包含敏感信息: Bool
    /// 是否压缩
    var 压缩: Bool
    /// 导出格式
    var 导出格式: 配置文件类型
    /// 是否包含元数据
    var 包含元数据: Bool

    /// 默认选项
    static let 默认 = 配置文件导出选项(
        包含敏感信息: true,
        压缩: false,
        导出格式: .singbox,
        包含元数据: true
    )
}

// MARK: - 配置文件版本记录

/// 配置文件版本记录
struct 配置文件版本记录: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 配置 ID
    let 配置ID: UUID
    /// 版本号
    let 版本号: Int
    /// 版本名称
    let 版本名称: String
    /// 创建时间
    let 创建时间: Date
    /// 修改说明
    let 修改说明: String?
    /// 文件路径
    let 文件路径: String
    /// 文件大小
    let 文件大小: Int64

    /// 创建时间显示
    var 创建时间显示: String {
        let 格式化 = DateFormatter()
        格式化.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return 格式化.string(from: 创建时间)
    }
}
