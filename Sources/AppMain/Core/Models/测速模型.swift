//
//  测速模型.swift
//  NewVPN
//
//  测速模块数据模型定义
//

import Foundation

// MARK: - 测速状态

/// 节点测速状态
enum 测速状态: Equatable {
    /// 未测速
    case 未测速
    /// 测速中
    case 测速中
    /// 测速成功
    case 成功
    /// 测速失败
    case 失败(String)

    /// 状态显示文字
    var 显示文字: String {
        switch self {
        case .未测速: return "未测速"
        case .测速中: return "测速中..."
        case .成功: return "已测速"
        case .失败: return "失败"
        }
    }

    /// 是否正在测速
    var 是否测速中: Bool {
        if case .测速中 = self { return true }
        return false
    }
}

// MARK: - 测速类型

/// 测速类型
enum 测速类型: String, CaseIterable {
    /// 仅延迟测试（TCP连接延迟）
    case 仅延迟 = "仅延迟"
    /// 延迟+下载速度
    case 延迟和下载 = "延迟+下载"
    /// 完整测试（延迟+下载+上传）
    case 完整测试 = "完整测试"
}

// MARK: - 测速配置

/// 测速配置
struct 测速配置 {
    /// 测速类型
    var 类型: 测速类型 = .仅延迟
    /// 延迟测试超时（秒）
    var 延迟超时: TimeInterval = 5.0
    /// 延迟测试次数（取平均值）
    var 延迟测试次数: Int = 3
    /// 下载测试超时（秒）
    var 下载超时: TimeInterval = 10.0
    /// 下载测试数据量上限（字节，0表示不限制）
    var 下载数据上限: Int64 = 10 * 1024 * 1024 // 10MB
    /// 下载测试时长上限（秒）
    var 下载时长上限: TimeInterval = 8.0
    /// 批量测速并发数
    var 并发数: Int = 3
    /// 测试服务器地址（用于HTTP延迟和下载测试）
    var 测试服务器地址: String = "https://www.gstatic.com/generate_204"
    /// 下载测试文件地址
    var 下载测试文件地址: String = "https://speed.cloudflare.com/__down?bytes=10000000"

    /// 默认配置
    static let 默认 = 测速配置()
}

// MARK: - 测速结果

/// 节点测速结果
struct 测速结果模型: Equatable {
    /// 节点ID
    let 节点ID: UUID
    /// 测速时间
    let 测速时间: Date
    /// 延迟（毫秒）
    var 延迟毫秒: Int?
    /// 抖动（毫秒）
    var 抖动毫秒: Int?
    /// 丢包率（百分比）
    var 丢包率: Double?
    /// 下载速度（Mbps）
    var 下载速率Mbps: Double?
    /// 上传速度（Mbps）
    var 上传速率Mbps: Double?
    /// 是否成功
    var 成功: Bool
    /// 错误信息
    var 错误信息: String?

    /// 延迟显示文字
    var 延迟显示: String {
        guard let 延迟 = 延迟毫秒 else { return "-" }
        return "\(延迟)ms"
    }

    /// 下载速度显示文字
    var 下载显示: String {
        guard let 下载 = 下载速率Mbps else { return "-" }
        return String(format: "%.1fMbps", 下载)
    }

    /// 延迟颜色（根据延迟值）
    var 延迟颜色: Color {
        guard let 延迟 = 延迟毫秒 else { return .secondary }
        switch 延迟 {
        case 0..<100: return .成功色
        case 100..<200: return .警告色
        default: return .危险色
        }
    }

    /// 空结果（未测速）
    static func 空结果(节点ID: UUID) -> 测速结果模型 {
        测速结果模型(
            节点ID: 节点ID,
            测速时间: Date(),
            延迟毫秒: nil,
            抖动毫秒: nil,
            丢包率: nil,
            下载速率Mbps: nil,
            上传速率Mbps: nil,
            成功: false,
            错误信息: nil
        )
    }
}

// MARK: - 批量测速进度

/// 批量测速进度
struct 批量测速进度 {
    /// 总节点数
    let 总数: Int
    /// 已完成数
    var 已完成: Int
    /// 当前正在测速的节点名称
    var 当前节点名称: String?
    /// 是否完成
    var 是否完成: Bool { 已完成 >= 总数 }
    /// 进度百分比
    var 进度百分比: Double {
        guard 总数 > 0 else { return 0 }
        return Double(已完成) / Double(总数)
    }
    /// 进度显示文字
    var 进度显示: String {
        "\(已完成)/\(总数)"
    }
}

// MARK: - 测速历史记录

/// 测速历史记录
struct 测速历史记录: Identifiable {
    let id = UUID()
    /// 测速时间
    let 时间: Date
    /// 测速节点数
    let 节点数: Int
    /// 平均延迟
    let 平均延迟: Int?
    /// 平均下载速度
    let 平均下载: Double?
    /// 测速类型
    let 类型: 测速类型
}
