//
//  DNS模型.swift
//  NewVPN
//
//  DNS 模块数据模型定义
//

import Foundation

// MARK: - DNS 服务器类型

/// DNS 服务器协议类型
enum DNS服务器类型: String, Codable, CaseIterable {
    /// 传统 UDP DNS
    case udp = "UDP"
    /// TCP DNS
    case tcp = "TCP"
    /// DNS over HTTPS
    case doh = "DoH"
    /// DNS over TLS
    case dot = "DoT"

    /// 默认端口
    var 默认端口: Int {
        switch self {
        case .udp, .tcp: return 53
        case .doh: return 443
        case .dot: return 853
        }
    }
}

// MARK: - DNS 服务器模型

/// DNS 服务器配置
struct DNS服务器模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 服务器名称
    var 名称: String
    /// 服务器地址（IP或域名）
    var 地址: String
    /// 端口
    var 端口: Int
    /// 协议类型
    var 类型: DNS服务器类型
    /// 是否启用
    var 启用: Bool
    /// 服务器描述
    var 描述: String?
    /// 测速延迟（毫秒）
    var 测速延迟: Int?
    /// 是否为系统默认
    var 是否系统默认: Bool = false

    /// 完整地址显示
    var 地址显示: String {
        if 端口 == 类型.默认端口 {
            return 地址
        }
        return "\(地址):\(端口)"
    }

    /// 延迟颜色
    var 延迟颜色: String {
        guard let 延迟 = 测速延迟 else { return "secondary" }
        switch 延迟 {
        case 0..<50: return "success"
        case 50..<150: return "warning"
        default: return "danger"
        }
    }

    // MARK: - 预设 DNS 服务器

    /// 常用 DNS 服务器预设
    static let 预设列表: [DNS服务器模型] = [
        DNS服务器模型(名称: "Google DNS", 地址: "8.8.8.8", 端口: 53, 类型: .udp, 启用: true, 描述: "Google 公共 DNS", 是否系统默认: false),
        DNS服务器模型(名称: "Google DNS IPv6", 地址: "2001:4860:4860::8888", 端口: 53, 类型: .udp, 启用: false, 描述: "Google IPv6 DNS", 是否系统默认: false),
        DNS服务器模型(名称: "Cloudflare", 地址: "1.1.1.1", 端口: 53, 类型: .udp, 启用: true, 描述: "Cloudflare 公共 DNS", 是否系统默认: false),
        DNS服务器模型(名称: "Cloudflare DoH", 地址: "https://cloudflare-dns.com/dns-query", 端口: 443, 类型: .doh, 启用: false, 描述: "Cloudflare DNS over HTTPS", 是否系统默认: false),
        DNS服务器模型(名称: "阿里 DNS", 地址: "223.5.5.5", 端口: 53, 类型: .udp, 启用: true, 描述: "阿里公共 DNS", 是否系统默认: false),
        DNS服务器模型(名称: "腾讯 DNS", 地址: "119.29.29.29", 端口: 53, 类型: .udp, 启用: false, 描述: "腾讯公共 DNS", 是否系统默认: false),
        DNS服务器模型(名称: "114 DNS", 地址: "114.114.114.114", 端口: 53, 类型: .udp, 启用: false, 描述: "114 公共 DNS", 是否系统默认: false),
        DNS服务器模型(名称: "OpenDNS", 地址: "208.67.222.222", 端口: 53, 类型: .udp, 启用: false, 描述: "Cisco OpenDNS", 是否系统默认: false),
        DNS服务器模型(名称: "Quad9", 地址: "9.9.9.9", 端口: 53, 类型: .udp, 启用: false, 描述: "Quad9 安全 DNS", 是否系统默认: false)
    ]
}

// MARK: - DNS 记录类型

/// DNS 记录类型
enum DNS记录类型: String, Codable, CaseIterable {
    case A = "A"
    case AAAA = "AAAA"
    case CNAME = "CNAME"
    case MX = "MX"
    case TXT = "TXT"
    case NS = "NS"
    case SOA = "SOA"
    case PTR = "PTR"
    case SRV = "SRV"
    case CAA = "CAA"
}

// MARK: - DNS 记录模型

/// DNS 查询记录
struct DNS记录模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 查询的域名
    var 域名: String
    /// 记录类型
    var 记录类型: DNS记录类型
    /// 解析结果（IP地址或其他记录值）
    var 解析结果: [String]
    /// TTL（秒）
    var TTL: Int
    /// 查询时间
    var 查询时间: Date
    /// 响应时间（毫秒）
    var 响应时间: Int?
    /// 使用的 DNS 服务器
    var DNS服务器: String
    /// 来源（缓存/远程/拦截）
    var 来源: DNS来源
    /// 是否被拦截
    var 是否被拦截: Bool = false
    /// 拦截规则名称
    var 拦截规则: String?

    /// 查询时间显示
    var 时间显示: String {
        let 格式 = DateFormatter()
        格式.dateFormat = "HH:mm:ss"
        return 格式.string(from: 查询时间)
    }

    /// 解析结果显示
    var 结果显示: String {
        if 解析结果.isEmpty {
            return "无结果"
        }
        return 解析结果.joined(separator: ", ")
    }
}

// MARK: - DNS 来源

/// DNS 记录来源
enum DNS来源: String, Codable, CaseIterable {
    /// 缓存命中
    case 缓存 = "缓存"
    /// 远程服务器查询
    case 远程 = "远程"
    /// 被规则拦截
    case 拦截 = "拦截"
    /// 直连解析
    case 直连 = "直连"
    /// 代理解析
    case 代理 = "代理"
}

// MARK: - DNS 策略

/// DNS 解析策略
enum DNS策略: String, Codable, CaseIterable {
    /// 系统默认
    case 系统默认 = "系统默认"
    /// 直连 DNS（本地解析）
    case 直连 = "直连解析"
    /// 代理 DNS（通过代理解析）
    case 代理 = "代理解析"
    /// 分流 DNS（国内直连，国外代理）
    case 分流 = "分流解析"
    /// 自定义 DNS
    case 自定义 = "自定义"
}

// MARK: - DNS 配置模型

/// DNS 全局配置
struct DNS配置模型: Codable {
    /// 是否启用自定义 DNS
    var 启用自定义DNS: Bool = false
    /// DNS 解析策略
    var 策略: DNS策略 = .系统默认
    /// DNS 服务器列表
    var 服务器列表: [DNS服务器模型] = DNS服务器模型.预设列表
    /// 备用 DNS 服务器
    var 备用服务器: [DNS服务器模型] = []
    /// 是否启用 DNS 缓存
    var 启用缓存: Bool = true
    /// 缓存 TTL 覆盖（秒，0表示使用服务器TTL）
    var 缓存TTL覆盖: Int = 0
    /// 是否启用 DNS 过滤
    var 启用过滤: Bool = false
    /// 广告拦截规则列表
    var 广告拦截规则: [DNS过滤规则] = []
    /// 自定义 hosts
    var 自定义Hosts: [自定义Hosts条目] = []
    /// 是否记录 DNS 查询日志
    var 记录查询日志: Bool = true
    /// 最大日志条数
    var 最大日志条数: Int = 500
    /// 是否启用 DNS 泄漏保护
    var 启用泄漏保护: Bool = true

    /// 启用的服务器列表
    var 启用服务器: [DNS服务器模型] {
        服务器列表.filter { $0.启用 }
    }

    /// 默认配置
    static let 默认 = DNS配置模型()
}

// MARK: - DNS 过滤规则

/// DNS 过滤规则
struct DNS过滤规则: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 规则名称
    var 名称: String
    /// 匹配类型
    var 匹配类型: DNS匹配类型
    /// 匹配值（域名/关键词/正则）
    var 匹配值: String
    /// 动作（拦截/放行/重定向）
    var 动作: DNS过滤动作
    /// 重定向地址（动作=重定向时有效）
    var 重定向地址: String?
    /// 是否启用
    var 启用: Bool = true
    /// 命中次数
    var 命中次数: Int = 0
}

/// DNS 匹配类型
enum DNS匹配类型: String, Codable, CaseIterable {
    case 域名精确 = "域名精确"
    case 域名后缀 = "域名后缀"
    case 域名关键词 = "域名关键词"
    case 正则表达式 = "正则表达式"
}

/// DNS 过滤动作
enum DNS过滤动作: String, Codable, CaseIterable {
    case 拦截 = "拦截"
    case 放行 = "放行"
    case 重定向 = "重定向"
}

// MARK: - 自定义 Hosts

/// 自定义 hosts 条目
struct 自定义Hosts条目: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 域名
    var 域名: String
    /// IP 地址
    var IP地址: String
    /// 是否启用
    var 启用: Bool = true
    /// 备注
    var 备注: String?
}

// MARK: - DNS 测速结果

/// DNS 服务器测速结果
struct DNS测速结果: Identifiable {
    let id: UUID
    /// 服务器 ID
    let 服务器ID: UUID
    /// 服务器名称
    let 服务器名称: String
    /// 延迟（毫秒）
    var 延迟: Int?
    /// 是否成功
    var 成功: Bool
    /// 错误信息
    var 错误信息: String?
    /// 测速时间
    let 测速时间: Date
}

// MARK: - DNS 泄漏检测结果

/// DNS 泄漏检测结果
struct DNS泄漏检测结果 {
    /// 是否存在泄漏
    var 存在泄漏: Bool
    /// 检测到的 DNS 服务器
    var 检测到的服务器: [String]
    /// 预期 DNS 服务器
    var 预期服务器: [String]
    /// 泄漏的服务器
    var 泄漏服务器: [String]
    /// 检测时间
    let 检测时间: Date
    /// 检测说明
    var 说明: String {
        if 存在泄漏 {
            return "检测到 DNS 泄漏：\(泄漏服务器.joined(separator: ", "))"
        }
        return "未检测到 DNS 泄漏"
    }
}
