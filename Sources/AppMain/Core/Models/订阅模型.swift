//
//  订阅模型.swift
//  NewVPN
//
//  远程订阅数据模型定义
//

import Foundation

// MARK: - 订阅状态枚举

/// 远程订阅更新状态
enum 订阅状态: Equatable {
    /// 空闲（未更新过）
    case 空闲
    /// 正在更新
    case 更新中
    /// 更新成功
    case 成功
    /// 更新失败
    case 失败(String)

    /// 状态显示文字
    var 显示文字: String {
        switch self {
        case .空闲: return "未更新"
        case .更新中: return "更新中..."
        case .成功: return "已更新"
        case .失败(let 信息): return "失败：\(信息)"
        }
    }

    /// 是否处于更新中
    var 是否更新中: Bool {
        if case .更新中 = self { return true }
        return false
    }
}

// MARK: - 自动更新周期枚举

/// 订阅自动更新周期
enum 自动更新周期: String, CaseIterable, Identifiable {
    case 六小时 = "6小时"
    case 十二小时 = "12小时"
    case 二十四小时 = "24小时"
    case 关闭 = "关闭"

    var id: String { rawValue }

    /// 周期对应的秒数
    var 秒数: TimeInterval {
        switch self {
        case .六小时: return 6 * 3600
        case .十二小时: return 12 * 3600
        case .二十四小时: return 24 * 3600
        case .关闭: return 0
        }
    }
}

// MARK: - 远程订阅模型

/// 远程订阅源数据模型
struct 远程订阅模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 订阅名称
    var 名称: String
    /// 远程订阅地址
    var 地址: String
    /// 自定义 User-Agent（可选）
    var 自定义UA: String?
    /// 自定义请求头
    var 请求头: [String: String] = [:]
    /// 上次更新时间
    var 上次更新时间: Date?
    /// 上次更新状态（不持久化，运行时使用）
    var 上次状态: 订阅状态 = .空闲
    /// 是否启用自动更新
    var 自动更新启用: Bool = false
    /// 自动更新周期
    var 自动更新周期: 自动更新周期 = .二十四小时

    /// 上次更新时间显示文字
    var 上次更新显示: String {
        guard let 时间 = 上次更新时间 else { return "从未更新" }
        let 格式 = DateFormatter()
        格式.dateFormat = "MM/dd HH:mm"
        return 格式.string(from: 时间)
    }

    /// 订阅地址显示文字（过长截断）
    var 地址显示: String {
        if 地址.count > 40 {
            let 前缀 = String(地址.prefix(20))
            let 后缀 = String(地址.suffix(15))
            return "\(前缀)...\(后缀)"
        }
        return 地址
    }

    // Codable 支持：订阅状态不持久化
    enum 编码键: String, CodingKey {
        case id, 名称, 地址, 自定义UA, 请求头, 上次更新时间, 自动更新启用, 自动更新周期
    }

    init(from 解码器: Decoder) throws {
        let 容器 = try 解码器.container(keyedBy: 编码键.self)
        id = try 容器.decode(UUID.self, forKey: .id)
        名称 = try 容器.decode(String.self, forKey: .名称)
        地址 = try 容器.decode(String.self, forKey: .地址)
        自定义UA = try 容器.decodeIfPresent(String.self, forKey: .自定义UA)
        请求头 = try 容器.decode([String: String].self, forKey: .请求头)
        上次更新时间 = try 容器.decodeIfPresent(Date.self, forKey: .上次更新时间)
        自动更新启用 = try 容器.decode(Bool.self, forKey: .自动更新启用)
        自动更新周期 = try 容器.decode(自动更新周期.self, forKey: .自动更新周期)
        上次状态 = .空闲
    }

    func encode(to 编码器: Encoder) throws {
        var 容器 = 编码器.container(keyedBy: 编码键.self)
        try 容器.encode(id, forKey: .id)
        try 容器.encode(名称, forKey: .名称)
        try 容器.encode(地址, forKey: .地址)
        try 容器.encodeIfPresent(自定义UA, forKey: .自定义UA)
        try 容器.encode(请求头, forKey: .请求头)
        try 容器.encodeIfPresent(上次更新时间, forKey: .上次更新时间)
        try 容器.encode(自动更新启用, forKey: .自动更新启用)
        try 容器.encode(自动更新周期, forKey: .自动更新周期)
    }

    /// 默认初始化
    init(名称: String, 地址: String) {
        self.名称 = 名称
        self.地址 = 地址
    }
}
