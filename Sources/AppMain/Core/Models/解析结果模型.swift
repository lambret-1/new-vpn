//
//  解析结果模型.swift
//  NewVPN
//
//  订阅解释器统一解析结果模型
//  各种订阅格式（base64/Clash/sing-box）解析后统一转换为此模型
//

import Foundation

// MARK: - 订阅格式类型

/// 订阅内容格式类型
enum 订阅格式类型: String {
    /// Base64 编码的节点链接列表
    case base64节点列表 = "Base64节点列表"
    /// 纯文本节点链接列表
    case 纯文本节点列表 = "纯文本节点列表"
    /// Clash YAML 配置
    case clash配置 = "Clash配置"
    /// sing-box JSON 配置
    case singbox配置 = "sing-box配置"
    /// V2RayN 订阅（base64编码的vmess JSON列表）
    case v2rayn订阅 = "V2RayN订阅"
    /// 未知格式
    case 未知 = "未知格式"
}

// MARK: - 解析节点模型

/// 统一解析节点模型（从各种订阅格式解析出的节点信息）
struct 解析节点模型: Identifiable, Hashable {
    /// 唯一标识
    let id = UUID()
    /// 节点名称（备注）
    var 名称: String
    /// 协议类型
    var 协议: 协议类型
    /// 服务器地址
    var 地址: String
    /// 端口
    var 端口: Int
    /// 用户标识（UUID/密码）
    var 用户标识: String?
    /// 传输层类型
    var 传输类型: 传输类型
    /// 是否启用 TLS
    var 启用TLS: Bool
    /// SNI 服务器名称
    var 服务器名称: String?
    /// 所属分组（从订阅中解析）
    var 分组: String
    /// 标签
    var 标签: [String]
    /// 原始数据（保留原始链接或JSON，用于调试）
    var 原始数据: String?
    /// 解析警告（非致命问题）
    var 解析警告: [String] = []

    /// 转换为应用节点模型
    func 转换为节点模型() -> 节点模型 {
        节点模型(
            id: UUID(),
            名称: 名称,
            协议: 协议,
            地址: 地址,
            端口: 端口,
            用户标识: 用户标识,
            传输类型: 传输类型,
            启用TLS: 启用TLS,
            服务器名称: 服务器名称,
            分组: 分组,
            标签: 标签,
            备注: nil,
            来源类型: "订阅导入",
            测速数据: nil
        )
    }
}

// MARK: - 解析结果

/// 订阅解析结果
struct 订阅解析结果 {
    /// 检测到的订阅格式
    let 格式: 订阅格式类型
    /// 解析出的节点列表
    let 节点列表: [解析节点模型]
    /// 解析错误列表
    let 错误列表: [解析错误]
    /// 解析统计
    var 统计: 解析统计 {
        解析统计(
            总节点数: 节点列表.count,
            成功数: 节点列表.filter { $0.解析警告.isEmpty }.count,
            警告数: 节点列表.filter { !$0.解析警告.isEmpty }.count,
            错误数: 错误列表.count
        )
    }
}

// MARK: - 解析统计

/// 解析统计信息
struct 解析统计 {
    /// 总节点数
    let 总节点数: Int
    /// 成功解析数
    let 成功数: Int
    /// 有警告数
    let 警告数: Int
    /// 错误数
    let 错误数: Int
}

// MARK: - 解析错误

/// 解析错误
struct 解析错误: Error, LocalizedError, Identifiable {
    let id = UUID()
    /// 错误类型
    let 类型: 错误类型
    /// 错误描述
    let 描述: String
    /// 原始行内容（用于定位）
    let 原始内容: String?
    /// 行号
    let 行号: Int?

    enum 错误类型 {
        case 格式不支持
        case 解码失败
        case URL无效
        case 缺少必要字段
        case 端口无效
        case JSON解析失败
        case YAML解析失败
        case 协议不支持
        case 其他
    }

    var errorDescription: String? {
        描述
    }
}
