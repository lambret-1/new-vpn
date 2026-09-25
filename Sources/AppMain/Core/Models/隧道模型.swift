//
//  隧道模型.swift
//  NewVPN
//
//  隧道模块数据模型定义
//

import Foundation
import NetworkExtension
import os

// MARK: - 隧道连接状态

/// 隧道连接状态
enum 隧道状态: String, Codable, CaseIterable {
    /// 已断开
    case 已断开 = "已断开"
    /// 准备中（生成 sing-box 配置）
    case 准备中 = "准备中"
    /// 正在连接
    case 正在连接 = "正在连接"
    /// 已连接
    case 已连接 = "已连接"
    /// 正在断开
    case 正在断开 = "正在断开"
    /// 重新加载中
    case 重新加载中 = "重新加载中"
    /// 自动重连中
    case 重连中 = "重连中"
    /// 连接失败
    case 连接失败 = "连接失败"
    /// 配置无效
    case 配置无效 = "配置无效"

    /// 状态颜色
    var 状态颜色: String {
        switch self {
        case .已连接: return "success"
        case .正在连接, .重新加载中, .准备中, .重连中: return "warning"
        case .已断开: return "secondary"
        case .正在断开: return "warning"
        case .连接失败, .配置无效: return "danger"
        }
    }

    /// 状态图标
    var 状态图标: String {
        switch self {
        case .已连接: return "bolt.fill"
        case .正在连接: return "bolt"
        case .准备中: return "gearshape.2"
        case .重连中: return "arrow.clockwise.circle"
        case .已断开: return "bolt.slash"
        case .正在断开: return "bolt.slash"
        case .重新加载中: return "arrow.clockwise"
        case .连接失败: return "exclamationmark.triangle"
        case .配置无效: return "xmark.circle"
        }
    }

    /// 是否活动状态（连接中或已连接）
    var 是否活动: Bool {
        switch self {
        case .已连接, .正在连接, .重新加载中, .准备中, .重连中: return true
        default: return false
        }
    }

    /// 从 NEVPNStatus 转换
    static func 从NEVPN状态(_ 状态: NEVPNStatus) -> 隧道状态 {
        switch 状态 {
        case .invalid: return .配置无效
        case .disconnected: return .已断开
        case .connecting: return .正在连接
        case .connected: return .已连接
        case .reasserting: return .重新加载中
        case .disconnecting: return .正在断开
        @unknown default: return .已断开
        }
    }
}

// MARK: - 隧道配置模型

/// 隧道配置
struct 隧道配置模型: Codable {
    /// 隧道名称
    var 隧道名称: String = "NewVPN 隧道"
    /// 隧道描述
    var 隧道描述: String = "NewVPN 网络扩展隧道"
    /// 服务器地址（显示用）
    var 服务器地址: String = ""
    /// 用户名
    var 用户名: String = ""
    /// 密码引用（Keychain）
    var 密码引用: Data?
    /// 是否按需连接
    var 按需连接: Bool = false
    /// 是否在蜂窝网络下连接
    var 蜂窝网络连接: Bool = true
    /// 是否在 WiFi 下连接
    var WiFi连接: Bool = true
    /// 断开时是否阻止所有流量（Kill Switch）
    var 断开阻止流量: Bool = false
    /// 包含所有网络
    var 包含所有网络: Bool = true
    /// 排除的网络（SSID列表）
    var 排除网络: [String] = []
    /// 包含的网络（SSID列表）
    var 包含网络: [String] = []
    /// DNS 服务器
    var DNS服务器: [String] = []
    /// 代理设置
    var 代理设置: 隧道代理配置?
    /// MTU 大小
    var MTU: Int = 1500
    /// 隧道日志级别
    var 日志级别: 隧道日志级别 = .信息
    /// 启用流量统计
    var 启用流量统计: Bool = true
    /// 隧道运行模式
    var 运行模式: 隧道运行模式 = .规则分流

    /// 默认配置
    static let 默认 = 隧道配置模型()
}

// MARK: - 隧道运行模式

/// 隧道运行模式
enum 隧道运行模式: String, Codable, CaseIterable {
    /// 规则分流（按分流规则匹配，未命中走代理）
    case 规则分流 = "规则分流"
    /// 全局代理（所有流量走代理）
    case 全局代理 = "全局代理"
    /// 全局直连（所有流量直连，不经过代理服务器）
    case 全局直连 = "全局直连"

    /// 模式描述
    var 描述: String {
        switch self {
        case .规则分流: return "按分流规则匹配，国内直连、国外代理"
        case .全局代理: return "所有流量全部走代理服务器"
        case .全局直连: return "所有流量直接连接，不经过代理"
        }
    }
}

// MARK: - 隧道代理配置

/// 隧道代理配置
struct 隧道代理配置: Codable {
    /// 代理类型
    var 类型: 隧道代理类型 = .直连
    /// 代理服务器地址
    var 服务器: String = ""
    /// 代理端口
    var 端口: Int = 0
    /// 用户名
    var 用户名: String?
    /// 密码
    var 密码: String?
}

/// 隧道代理类型
enum 隧道代理类型: String, Codable, CaseIterable {
    case 直连 = "直连"
    case HTTP = "HTTP"
    case HTTPS = "HTTPS"
    case SOCKS5 = "SOCKS5"
}

// MARK: - 隧道日志级别

/// 隧道日志级别
enum 隧道日志级别: String, Codable, CaseIterable {
    case 调试 = "调试"
    case 信息 = "信息"
    case 警告 = "警告"
    case 错误 = "错误"
    case 关闭 = "关闭"

    /// 系统日志级别
    var 系统级别: OSLogType {
        switch self {
        case .调试: return .debug
        case .信息: return .info
        case .警告: return .default
        case .错误: return .error
        case .关闭: return .fault
        }
    }
}

// MARK: - 隧道流量统计

/// 隧道流量统计
struct 隧道流量统计: Codable, Equatable {
    /// 上行字节数
    var 上行字节: UInt64 = 0
    /// 下行字节数
    var 下行字节: UInt64 = 0
    /// 总字节数
    var 总字节: UInt64 { 上行字节 + 下行字节 }
    /// 上行速度（字节/秒）
    var 上行速度: Double = 0
    /// 下行速度（字节/秒）
    var 下行速度: Double = 0
    /// 连接时长（秒）
    var 连接时长: TimeInterval = 0
    /// 最后更新时间
    var 最后更新时间: Date = Date()

    /// 上行显示
    var 上行显示: String {
        格式化字节数(上行字节)
    }

    /// 下行显示
    var 下行显示: String {
        格式化字节数(下行字节)
    }

    /// 总流量显示
    var 总流量显示: String {
        格式化字节数(总字节)
    }

    /// 上行速度显示
    var 上行速度显示: String {
        格式化速度(上行速度)
    }

    /// 下行速度显示
    var 下行速度显示: String {
        格式化速度(下行速度)
    }

    /// 连接时长显示
    var 连接时长显示: String {
        格式化时长(连接时长)
    }

    /// 格式化字节数
    private func 格式化字节数(_ 字节: UInt64) -> String {
        let KB = 1024.0
        let MB = KB * 1024
        let GB = MB * 1024

        let 字节数 = Double(字节)
        if 字节数 >= GB {
            return String(format: "%.2f GB", 字节数 / GB)
        } else if 字节数 >= MB {
            return String(format: "%.2f MB", 字节数 / MB)
        } else if 字节数 >= KB {
            return String(format: "%.1f KB", 字节数 / KB)
        } else {
            return "\(字节) B"
        }
    }

    /// 格式化速度
    private func 格式化速度(_ 字节每秒: Double) -> String {
        let KB = 1024.0
        let MB = KB * 1024

        if 字节每秒 >= MB {
            return String(format: "%.2f MB/s", 字节每秒 / MB)
        } else if 字节每秒 >= KB {
            return String(format: "%.1f KB/s", 字节每秒 / KB)
        } else {
            return String(format: "%.0f B/s", 字节每秒)
        }
    }

    /// 格式化时长
    private func 格式化时长(_ 秒: TimeInterval) -> String {
        let 小时 = Int(秒) / 3600
        let 分钟 = (Int(秒) % 3600) / 60
        let 秒数 = Int(秒) % 60

        if 小时 > 0 {
            return String(format: "%02d:%02d:%02d", 小时, 分钟, 秒数)
        } else {
            return String(format: "%02d:%02d", 分钟, 秒数)
        }
    }
}

// MARK: - 隧道日志模型

/// 隧道日志条目
struct 隧道日志模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 日志时间
    var 时间: Date
    /// 日志级别
    var 级别: 隧道日志级别
    /// 日志模块
    var 模块: String
    /// 日志内容
    var 内容: String

    /// 时间显示
    var 时间显示: String {
        let 格式 = DateFormatter()
        格式.dateFormat = "HH:mm:ss.SSS"
        return 格式.string(from: 时间)
    }

    /// 级别颜色
    var 级别颜色: String {
        switch 级别 {
        case .调试: return "secondary"
        case .信息: return "primary"
        case .警告: return "warning"
        case .错误: return "danger"
        case .关闭: return "secondary"
        }
    }
}

// MARK: - 隧道连接信息

/// 隧道连接信息
struct 隧道连接信息: Codable {
    /// 连接ID
    var 连接ID: UUID = UUID()
    /// 开始时间
    var 开始时间: Date
    /// 结束时间
    var 结束时间: Date?
    /// 连接状态
    var 状态: 隧道状态
    /// 使用的节点ID
    var 节点ID: UUID?
    /// 使用的节点名称
    var 节点名称: String?
    /// 流量统计
    var 流量统计: 隧道流量统计 = 隧道流量统计()
    /// 断开原因
    var 断开原因: String?

    /// 连接时长
    var 连接时长: TimeInterval {
        let 结束 = 结束时间 ?? Date()
        return 结束.timeIntervalSince(开始时间)
    }
}

// MARK: - 隧道错误

/// 隧道错误
enum 隧道错误: Error, LocalizedError, Codable {
    /// 配置无效
    case 配置无效(String)
    /// 权限被拒绝
    case 权限被拒绝
    /// 连接超时
    case 连接超时
    /// 服务器无响应
    case 服务器无响应
    /// 认证失败
    case 认证失败
    /// 网络不可用
    case 网络不可用
    /// 隧道扩展未安装
    case 扩展未安装
    /// 未知错误
    case 未知错误(String)

    /// 错误描述
    var errorDescription: String? {
        switch self {
        case .配置无效(let 详情): return "配置无效：\(详情)"
        case .权限被拒绝: return "VPN 权限被拒绝"
        case .连接超时: return "连接超时"
        case .服务器无响应: return "服务器无响应"
        case .认证失败: return "认证失败"
        case .网络不可用: return "网络不可用"
        case .扩展未安装: return "隧道扩展未安装"
        case .未知错误(let 详情): return "未知错误：\(详情)"
        }
    }
}

// MARK: - 隧道常量

/// 隧道相关常量
enum 隧道常量 {
    /// 隧道扩展 Bundle ID
    static let 扩展BundleID = "com.newvpn.app.tunnel"
    /// App Group ID
    static let AppGroupID = "group.com.newvpn.app"
    /// 隧道配置标识符
    static let 配置标识符 = "com.newvpn.app.tunnelConfig"
    /// 共享配置文件名
    static let 共享配置文件名 = "vpnConfig.json"
    /// 共享日志文件名
    static let 共享日志文件名 = "vpnLogs.json"
    /// 共享统计文件名
    static let 共享统计文件名 = "vpnStats.json"
    /// 状态更新通知
    static let 状态更新通知 = Notification.Name("com.newvpn.tunnelStatusUpdate")
    /// 统计更新通知
    static let 统计更新通知 = Notification.Name("com.newvpn.tunnelStatsUpdate")
    /// 日志更新通知
    static let 日志更新通知 = Notification.Name("com.newvpn.tunnelLogsUpdate")
    /// 统计更新间隔（秒）
    static let 统计更新间隔: TimeInterval = 1.0
}
