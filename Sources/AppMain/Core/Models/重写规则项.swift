//
//  重写规则项.swift
//  NewVPN
//
//  URL 重写规则数据模型
//

import Foundation

// MARK: - 重写规则类型

/// 重写规则类型
enum 重写规则类型: String, Codable, CaseIterable, Identifiable {
    /// URL 重写（正则匹配替换）
    case URL重写 = "URL重写"
    /// 请求头重写
    case 请求头 = "请求头"
    /// 响应头重写
    case 响应头 = "响应头"
    /// 请求阻断（返回空响应）
    case 请求阻断 = "请求阻断"

    var id: String { rawValue }

    /// 图标
    var 图标: String {
        switch self {
        case .URL重写: return "arrow.triangle.2.circlepath"
        case .请求头: return "arrow.up.circle"
        case .响应头: return "arrow.down.circle"
        case .请求阻断: return "hand.raised"
        }
    }

    /// 描述
    var 描述: String {
        switch self {
        case .URL重写: return "正则匹配并替换请求 URL"
        case .请求头: return "添加/修改/删除请求头"
        case .响应头: return "添加/修改/删除响应头"
        case .请求阻断: return "阻断匹配的请求，返回空响应"
        }
    }
}

// MARK: - 重写规则项

/// 重写规则项
struct 重写规则项: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id = UUID()
    /// 规则名称
    var 名称: String
    /// 规则类型
    var 类型: 重写规则类型
    /// 匹配正则（URL 或域名）
    var 匹配正则: String
    /// 替换内容（URL 重写时为替换字符串，头重写时为 Header:Value）
    var 替换内容: String
    /// 是否启用
    var 启用 = true
    /// 优先级（数字越小优先级越高）
    var 优先级 = 100
    /// 备注
    var 备注: String?

    /// 初始化
    init(名称: String, 类型: 重写规则类型, 匹配正则: String, 替换内容: String, 优先级: Int = 100, 备注: String? = nil) {
        self.名称 = 名称
        self.类型 = 类型
        self.匹配正则 = 匹配正则
        self.替换内容 = 替换内容
        self.优先级 = 优先级
        self.备注 = 备注
    }
}

// MARK: - 重写规则分组

/// 重写规则分组
struct 重写规则分组: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id = UUID()
    /// 分组名称
    var 名称: String
    /// 分组图标
    var 图标: String
    /// 分组描述
    var 描述: String?
    /// 规则列表
    var 规则列表: [重写规则项]
    /// 是否启用
    var 启用 = true

    /// 初始化
    init(名称: String, 图标: String = "pencil.line", 描述: String? = nil, 规则列表: [重写规则项] = []) {
        self.名称 = 名称
        self.图标 = 图标
        self.描述 = 描述
        self.规则列表 = 规则列表
    }

    /// 启用的规则数量
    var 启用规则数: Int {
        规则列表.filter { $0.启用 }.count
    }
}

// MARK: - 重写配置

/// 重写配置（持久化用）
struct 重写配置: Codable {
    /// 是否启用重写功能
    var 启用 = false
    /// 分组列表
    var 分组列表: [重写规则分组] = []

    /// 所有启用的规则
    var 所有启用规则: [重写规则项] {
        分组列表
            .filter { $0.启用 }
            .flatMap { $0.规则列表 }
            .filter { $0.启用 }
            .sorted { $0.优先级 < $1.优先级 }
    }

    /// 默认配置
    static var 默认: 重写配置 {
        重写配置(
            启用: false,
            分组列表: [
                重写规则分组(名称: "默认重写", 图标: "pencil.line", 描述: "默认重写规则分组", 规则列表: [])
            ]
        )
    }
}

// MARK: - 预设重写规则集

/// 预设重写规则集
struct 预设重写规则集: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: String { 名称 }
    /// 名称
    var 名称: String
    /// 描述
    var 描述: String
    /// 图标
    var 图标: String
    /// 规则列表
    var 规则列表: [重写规则项]

    /// 去广告重写预设
    static let 去广告: 预设重写规则集 = {
        let 规则 = [
            重写规则项(名称: "拦截百度广告", 类型: .请求阻断, 匹配正则: "^https?://[^/]*baidu\\.com/.*ad.*", 替换内容: "", 优先级: 10, 备注: "拦截百度搜索广告"),
            重写规则项(名称: "拦截淘宝广告", 类型: .请求阻断, 匹配正则: "^https?://[^/]*taobao\\.com/.*ad.*", 替换内容: "", 优先级: 11, 备注: "拦截淘宝广告"),
            重写规则项(名称: "移除微博广告参数", 类型: .URL重写, 匹配正则: "(\\?|&)from=[^&]*", 替换内容: "$1", 优先级: 20, 备注: "移除微博跳转来源参数")
        ]
        return 预设重写规则集(名称: "去广告", 描述: "常见广告拦截和参数清理规则", 图标: "hand.raised", 规则列表: 规则)
    }()

    /// 隐私保护重写预设
    static let 隐私保护: 预设重写规则集 = {
        let 规则 = [
            重写规则项(名称: "移除追踪参数", 类型: .URL重写, 匹配正则: "(\\?|&)(utm_|fbclid|gclid|mc_eid)=[^&]*", 替换内容: "", 优先级: 10, 备注: "移除常见追踪参数"),
            重写规则项(名称: "修改User-Agent", 类型: .请求头, 匹配正则: ".*", 替换内容: "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", 优先级: 20, 备注: "统一 User-Agent 减少指纹追踪")
        ]
        return 预设重写规则集(名称: "隐私保护", 描述: "移除追踪参数，保护浏览隐私", 图标: "shield.lefthalf.filled", 规则列表: 规则)
    }()

    /// 所有预设
    static let 所有预设: [预设重写规则集] = [去广告, 隐私保护]
}
