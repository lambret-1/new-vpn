//
//  数据模型.swift
//  NewVPN
//
//  全局核心数据模型定义：节点、订阅、分流规则、重写规则、脚本、日志、抓包会话
//  一期使用 Mock 数据驱动 UI，后续接入真实业务模块
//

import Foundation

// MARK: - 协议类型枚举

/// 代理协议类型
enum 协议类型: String, Codable, CaseIterable {
    case vless = "VLESS"
    case vmess = "VMess"
    case trojan = "Trojan"
    case shadowsocks = "Shadowsocks"
}

// MARK: - 传输层类型

/// 传输层协议类型
enum 传输类型: String, Codable, CaseIterable {
    case tcp = "TCP"
    case ws = "WebSocket"
    case grpc = "gRPC"
    case quic = "QUIC"
}

// MARK: - 节点测速结果

/// 节点测速结果数据
struct 测速结果: Codable, Hashable {
    /// 延迟（毫秒）
    var 延迟毫秒: Int?
    /// 抖动（毫秒）
    var 抖动毫秒: Int?
    /// 丢包率（百分比）
    var 丢包率: Double?
    /// 下载速度（Mbps）
    var 下载速率: Double?
    /// 上传速度（Mbps）
    var 上传速率: Double?
    /// 测速时间
    var 测速时间: Date?
    /// 是否测速成功
    var 成功: Bool
}

// MARK: - 节点模型

/// 代理节点数据模型
struct 节点模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 节点名称
    var 名称: String
    /// 协议类型
    var 协议: 协议类型
    /// 服务器地址
    var 地址: String
    /// 端口
    var 端口: Int
    /// UUID（VLESS/VMess）
    var 用户标识: String?
    /// 传输层类型
    var 传输类型: 传输类型
    /// 是否启用 TLS
    var 启用TLS: Bool
    /// SNI 服务器名称
    var 服务器名称: String?
    /// WebSocket 路径
    var ws路径: String? = nil
    /// WebSocket 主机（Host 头）
    var ws主机: String? = nil
    /// 所属分组
    var 分组: String
    /// 标签
    var 标签: [String]
    /// 备注
    var 备注: String?
    /// 来源类型（手动添加/订阅导入）
    var 来源类型: String
    /// 测速结果
    var 测速数据: 测速结果?

    /// 协议显示文字
    var 协议显示: String { 协议.rawValue }

    /// 延迟显示文字
    var 延迟显示: String {
        guard let 结果 = 测速数据, 结果.成功, let 延迟 = 结果.延迟毫秒 else {
            return "未测速"
        }
        return "\(延迟)ms"
    }
}

// MARK: - 订阅流量信息

/// 订阅流量与到期信息
struct 订阅流量信息: Codable, Hashable {
    /// 总流量（字节）
    var 总流量: Int64?
    /// 已用流量（字节）
    var 已用流量: Int64?
    /// 到期时间
    var 到期时间: Date?
}

// MARK: - 订阅模型

/// 订阅源数据模型
struct 订阅模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 订阅名称
    var 名称: String
    /// 订阅地址
    var 地址: String
    /// 是否启用
    var 启用: Bool
    /// 是否自动更新
    var 自动更新: Bool
    /// 更新间隔（分钟）
    var 更新间隔分钟: Int
    /// 上次更新时间
    var 上次更新: Date?
    /// 上次更新状态
    var 更新状态: String
    /// 错误信息
    var 错误信息: String?
    /// 流量信息
    var 流量信息: 订阅流量信息?
    /// 节点数量
    var 节点数量: Int

    /// 状态显示文字
    var 状态显示: String { 更新状态 }
}

// MARK: - 规则动作枚举

/// 分流规则动作
enum 规则动作: String, Codable, CaseIterable {
    case 代理 = "代理"
    case 直连 = "直连"
    case 拦截 = "拦截"
}

/// 规则匹配类型
enum 匹配类型: String, Codable, CaseIterable {
    case 域名后缀 = "域名后缀"
    case 域名关键词 = "域名关键词"
    case 域名正则 = "域名正则"
    case IP段 = "IP段"
    case 内网IP = "内网IP"
    case 地理IP = "地理IP"
}

// MARK: - 分流规则模型

/// 分流规则数据模型
struct 分流规则模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 规则名称
    var 名称: String
    /// 是否启用
    var 启用: Bool
    /// 匹配类型
    var 匹配类型: 匹配类型
    /// 匹配值
    var 匹配值: String
    /// 执行动作
    var 动作: 规则动作
    /// 是否启用 MITM
    var 启用MITM: Bool
    /// 优先级（数字越小越优先）
    var 优先级: Int
    /// 备注
    var 备注: String?
}

// MARK: - 重写规则模型

/// MITM 重写规则数据模型
struct 重写规则模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 规则名称
    var 名称: String
    /// 是否启用
    var 启用: Bool
    /// 匹配域名后缀
    var 域名后缀: String
    /// 匹配路径正则
    var 路径正则: String
    /// 重写类型
    var 重写类型: String
    /// 匹配表达式
    var 匹配表达式: String
    /// 替换内容
    var 替换内容: String
    /// 优先级
    var 优先级: Int
}

// MARK: - JS 脚本模型

/// JS 脚本数据模型
struct 脚本模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 脚本名称
    var 名称: String
    /// 是否启用
    var 启用: Bool
    /// 功能描述
    var 描述: String
    /// 触发时机
    var 触发时机: String
    /// 匹配域名
    var 匹配域名: String
    /// 脚本内容
    var 脚本内容: String
    /// 超时时间（毫秒）
    var 超时毫秒: Int
    /// 优先级
    var 优先级: Int
}

// MARK: - 日志模型

/// 日志级别
enum 日志级别: String, Codable, CaseIterable {
    case 致命 = "致命"
    case 错误 = "错误"
    case 警告 = "警告"
    case 信息 = "信息"
    case 调试 = "调试"
    case 追踪 = "追踪"

    /// 级别对应序号（用于过滤和比较）
    var 级别序号: Int {
        switch self {
        case .致命: return 5
        case .错误: return 4
        case .警告: return 3
        case .信息: return 2
        case .调试: return 1
        case .追踪: return 0
        }
    }

    /// 级别对应颜色
    var 级别颜色: String {
        switch self {
        case .致命: return "danger"
        case .错误: return "danger"
        case .警告: return "warning"
        case .信息: return "success"
        case .调试: return "secondary"
        case .追踪: return "secondary"
        }
    }
}

/// 日志条目数据模型
struct 日志模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 时间戳
    var 时间: Date
    /// 日志级别
    var 级别: 日志级别
    /// 模块名称
    var 模块: String
    /// 日志内容
    var 内容: String
    /// 附加字段（可选）
    var 附加字段: [String: String]?
    /// 异常堆栈（仅 error/fatal，可选）
    var 堆栈: String?

    /// 完整初始化
    init(id: UUID = UUID(), 时间: Date = Date(), 级别: 日志级别, 模块: String, 内容: String, 附加字段: [String: String]? = nil, 堆栈: String? = nil) {
        self.id = id
        self.时间 = 时间
        self.级别 = 级别
        self.模块 = 模块
        self.内容 = 内容
        self.附加字段 = 附加字段
        self.堆栈 = 堆栈
    }
}

// MARK: - 抓包会话模型

/// HTTP 抓包会话数据模型
struct 抓包会话模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 请求序号
    var 序号: Int
    /// 请求方法
    var 方法: String
    /// 完整 URL
    var URL地址: String
    /// 域名
    var 域名: String
    /// 路径
    var 路径: String
    /// HTTP 状态码
    var 状态码: Int?
    /// 请求开始时间
    var 开始时间: Date
    /// 请求耗时（毫秒）
    var 耗时毫秒: Int?
    /// 请求大小（字节）
    var 请求大小: Int?
    /// 响应大小（字节）
    var 响应大小: Int?
    /// 请求 Content-Type
    var 内容类型: String?
    /// 是否走 MITM 解密
    var 已解密: Bool
    /// 请求头
    var 请求头: [String: String]
    /// 响应头
    var 响应头: [String: String]
    /// 请求 Body 文本
    var 请求Body: String?
    /// 响应 Body 文本
    var 响应Body: String?
}

// MARK: - 网络活动连接模型

/// 网络连接记录数据模型
struct 网络连接模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 连接序号
    var 序号: Int
    /// 协议（TCP/UDP）
    var 协议: String
    /// 本地地址
    var 本地地址: String
    /// 本地端口
    var 本地端口: Int
    /// 远程地址
    var 远程地址: String
    /// 远程端口
    var 远程端口: Int
    /// 域名
    var 域名: String?
    /// 国家/地区
    var 国家地区: String?
    /// 出站策略（代理/直连/拦截）
    var 出站策略: String
    /// 连接开始时间
    var 开始时间: Date
    /// 连接是否已关闭
    var 已关闭: Bool
    /// 上行字节
    var 上行字节: Int64
    /// 下行字节
    var 下行字节: Int64
    /// HTTP 状态码（预留，MITM 模块接入后填充）
    var 状态码: Int?
    /// 匹配规则
    var 匹配规则: String?
}
