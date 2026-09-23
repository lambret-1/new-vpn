//
//  分流规则项.swift
//  NewVPN
//
//  分流规则模块数据模型定义
//

import Foundation

// MARK: - 分流规则类型

/// 分流规则匹配类型
enum 分流规则类型: String, Codable, CaseIterable {
    /// 域名精确匹配
    case 域名精确 = "域名精确"
    /// 域名后缀匹配
    case 域名后缀 = "域名后缀"
    /// 域名关键词匹配
    case 域名关键词 = "域名关键词"
    /// 正则表达式匹配
    case 正则表达式 = "正则表达式"
    /// IP 地址匹配
    case IP地址 = "IP地址"
    /// IP 段匹配（CIDR）
    case IP段 = "IP段"
    /// 端口匹配
    case 端口 = "端口"
    /// 端口范围匹配
    case 端口范围 = "端口范围"
    /// 协议匹配
    case 协议 = "协议"
    /// 进程名称匹配
    case 进程名称 = "进程名称"
    /// 用户代理匹配
    case 用户代理 = "用户代理"
    /// 地理区域匹配
    case 地理区域 = "地理区域"
    /// 全部流量
    case 全部 = "全部"

    /// 规则类型图标
    var 图标: String {
        switch self {
        case .域名精确, .域名后缀, .域名关键词: return "globe"
        case .正则表达式: return "textformat"
        case .IP地址, .IP段: return "network"
        case .端口, .端口范围: return "point.3.connected.trianglepath.dotted"
        case .协议: return "cable.connector"
        case .进程名称: return "app"
        case .用户代理: return "person.crop.circle"
        case .地理区域: return "map"
        case .全部: return "infinity"
        }
    }
}

// MARK: - 分流动作

/// 分流规则动作
enum 分流动作: String, Codable, CaseIterable {
    /// 直连（不经过代理）
    case 直连 = "直连"
    /// 代理（经过代理节点）
    case 代理 = "代理"
    /// 拦截（拒绝连接）
    case 拦截 = "拦截"
    /// 全局代理（所有流量走代理）
    case 全局代理 = "全局代理"
    /// 拒绝（返回错误）
    case 拒绝 = "拒绝"
    /// 放行（不做处理）
    case 放行 = "放行"

    /// 动作颜色
    var 颜色: String {
        switch self {
        case .直连: return "success"
        case .代理: return "primary"
        case .拦截, .拒绝: return "danger"
        case .全局代理: return "warning"
        case .放行: return "secondary"
        }
    }

    /// 动作图标
    var 图标: String {
        switch self {
        case .直连: return "arrow.right"
        case .代理: return "arrow.triangle.2.circlepath"
        case .拦截: return "hand.raised"
        case .全局代理: return "globe"
        case .拒绝: return "xmark.circle"
        case .放行: return "checkmark.circle"
        }
    }
}

// MARK: - 网络协议

/// 网络协议类型
enum 网络协议: String, Codable, CaseIterable {
    case TCP = "TCP"
    case UDP = "UDP"
    case HTTP = "HTTP"
    case HTTPS = "HTTPS"
    case DNS = "DNS"
    case ICMP = "ICMP"
    case WebSocket = "WebSocket"
    case QUIC = "QUIC"
    case 全部 = "全部"
}

// MARK: - 分流规则项

/// 分流规则
struct 分流规则项: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 规则名称
    var 名称: String
    /// 规则类型
    var 类型: 分流规则类型
    /// 匹配值（域名/IP/端口/正则等）
    var 匹配值: String
    /// 分流动作
    var 动作: 分流动作
    /// 是否启用
    var 启用: Bool = true
    /// 规则优先级（数字越小优先级越高）
    var 优先级: Int = 100
    /// 规则备注
    var 备注: String?
    /// 命中次数
    var 命中次数: Int = 0
    /// 最后命中时间
    var 最后命中时间: Date?
    /// 创建时间
    var 创建时间: Date = Date()
    /// 关联的代理节点ID（动作=代理时可指定特定节点）
    var 代理节点ID: UUID?
    /// 协议限制（仅匹配指定协议，nil表示全部）
    var 协议限制: 网络协议?
    /// 端口限制（仅匹配指定端口，nil表示全部）
    var 端口限制: Int?

    /// 规则描述
    var 描述: String {
        switch 类型 {
        case .域名精确: return "域名 == \(匹配值)"
        case .域名后缀: return "域名 以 \(匹配值) 结尾"
        case .域名关键词: return "域名 包含 \(匹配值)"
        case .正则表达式: return "正则: \(匹配值)"
        case .IP地址: return "IP == \(匹配值)"
        case .IP段: return "IP 属于 \(匹配值)"
        case .端口: return "端口 == \(匹配值)"
        case .端口范围: return "端口 在 \(匹配值) 范围"
        case .协议: return "协议 == \(匹配值)"
        case .进程名称: return "进程 == \(匹配值)"
        case .用户代理: return "UA 包含 \(匹配值)"
        case .地理区域: return "地区 == \(匹配值)"
        case .全部: return "匹配全部流量"
        }
    }

    /// 命中时间显示
    var 最后命中显示: String {
        guard let 时间 = 最后命中时间 else { return "从未命中" }
        let 格式 = DateFormatter()
        格式.dateFormat = "MM/dd HH:mm"
        return 格式.string(from: 时间)
    }
}

// MARK: - 分流规则分组

/// 分流规则分组
struct 分流规则分组: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 分组名称
    var 名称: String
    /// 分组描述
    var 描述: String?
    /// 分组图标
    var 图标: String = "folder"
    /// 规则列表
    var 规则列表: [分流规则项]
    /// 是否启用
    var 启用: Bool = true
    /// 是否展开
    var 是否展开: Bool = true

    /// 启用的规则数量
    var 启用规则数: Int {
        规则列表.filter { $0.启用 }.count
    }

    /// 总命中次数
    var 总命中次数: Int {
        规则列表.reduce(0) { $0 + $1.命中次数 }
    }
}

// MARK: - 预设规则集

/// 预设规则集
struct 预设规则集: Identifiable, Codable, Hashable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 规则集名称
    var 名称: String
    /// 规则集描述
    var 描述: String
    /// 规则集图标
    var 图标: String
    /// 规则列表
    var 规则列表: [分流规则项]
    /// 是否为内置预设
    var 是否内置: Bool = true

    // MARK: - 内置预设规则集

    /// 国内直连规则集
    static let 国内直连: 预设规则集 = {
        var 规则: [分流规则项] = []

        // 常见国内域名后缀
        let 国内域名后缀 = [
            "cn", "com.cn", "net.cn", "org.cn", "gov.cn", "edu.cn",
            "baidu.com", "qq.com", "taobao.com", "tmall.com", "jd.com",
            "alibaba.com", "aliyun.com", "weibo.com", "bilibili.com",
            "douyin.com", "kuaishou.com", "xiaohongshu.com", "zhihu.com",
            "163.com", "126.com", "sina.com.cn", "sohu.com", "ifeng.com",
            "ctrip.com", "meituan.com", "dianping.com", "ele.me",
            "didichuxing.com", "amap.com", "autonavi.com", "map.baidu.com",
            "iqiyi.com", "youku.com", "mgtv.com", "tencent.com",
            "toutiao.com", "36kr.com", "csdn.net", "jianshu.com",
            "weixin.qq.com", "wx.qq.com", "qq.com"
        ]

        for (索引, 域名) in 国内域名后缀.enumerated() {
            规则.append(分流规则项(
                名称: "国内直连 - \(域名)",
                类型: .域名后缀,
                匹配值: 域名,
                动作: .直连,
                优先级: 50 + 索引,
                备注: "国内常用域名直连"
            ))
        }

        // 国内 IP 段
        let 国内IP段 = [
            "1.0.1.0/24", "1.0.2.0/23", "1.0.8.0/21",
            "14.0.0.0/11", "27.8.0.0/13", "36.0.0.0/10",
            "39.0.0.0/8", "42.0.0.0/8", "49.0.0.0/8",
            "58.0.0.0/9", "59.0.0.0/8", "60.0.0.0/8",
            "61.0.0.0/8", "101.0.0.0/8", "103.0.0.0/8",
            "106.0.0.0/8", "110.0.0.0/8", "111.0.0.0/8",
            "112.0.0.0/8", "113.0.0.0/8", "114.0.0.0/8",
            "115.0.0.0/8", "116.0.0.0/8", "117.0.0.0/8",
            "118.0.0.0/8", "119.0.0.0/8", "120.0.0.0/8",
            "121.0.0.0/8", "122.0.0.0/8", "123.0.0.0/8",
            "124.0.0.0/8", "125.0.0.0/8", "126.0.0.0/8",
            "127.0.0.0/8", "129.0.0.0/8", "132.0.0.0/8",
            "133.0.0.0/8", "134.0.0.0/8", "137.0.0.0/8",
            "138.0.0.0/8", "139.0.0.0/8", "140.0.0.0/8",
            "144.0.0.0/8", "150.0.0.0/8", "152.0.0.0/8",
            "153.0.0.0/8", "157.0.0.0/8", "159.0.0.0/8",
            "161.0.0.0/8", "162.0.0.0/8", "163.0.0.0/8",
            "166.0.0.0/8", "167.0.0.0/8", "168.0.0.0/8",
            "169.0.0.0/8", "171.0.0.0/8", "172.0.0.0/8",
            "175.0.0.0/8", "180.0.0.0/8", "182.0.0.0/8",
            "183.0.0.0/8", "184.0.0.0/8", "185.0.0.0/8",
            "188.0.0.0/8", "189.0.0.0/8", "190.0.0.0/8",
            "191.0.0.0/8", "192.0.0.0/8", "193.0.0.0/8",
            "194.0.0.0/8", "195.0.0.0/8", "196.0.0.0/8",
            "197.0.0.0/8", "198.0.0.0/8", "199.0.0.0/8",
            "202.0.0.0/8", "203.0.0.0/8", "210.0.0.0/8",
            "211.0.0.0/8", "218.0.0.0/8", "219.0.0.0/8",
            "220.0.0.0/8", "221.0.0.0/8", "222.0.0.0/8",
            "223.0.0.0/8"
        ]

        for (索引, IP段) in 国内IP段.enumerated() {
            规则.append(分流规则项(
                名称: "国内IP - \(IP段)",
                类型: .IP段,
                匹配值: IP段,
                动作: .直连,
                优先级: 200 + 索引,
                备注: "国内IP段直连"
            ))
        }

        return 预设规则集(
            名称: "国内直连",
            描述: "包含常用国内域名和IP段，自动直连不走代理",
            图标: "arrow.right",
            规则列表: 规则
        )
    }()

    /// 广告拦截规则集
    static let 广告拦截: 预设规则集 = {
        var 规则: [分流规则项] = []

        let 广告域名 = [
            "doubleclick.net", "googlesyndication.com", "googleadservices.com",
            "google-analytics.com", "googletagmanager.com", "googleads.g.doubleclick.net",
            "facebook.com/tr", "connect.facebook.net", "platform.twitter.com",
            "adservice.google.com", "pagead2.googlesyndication.com",
            "tpc.googlesyndication.com", "www.googleadservices.com",
            "ads.yahoo.com", "advertising.yahoo.com", "adserver.yahoo.com",
            "ads.pinterest.com", "trk.pinterest.com", "analytics.pinterest.com",
            "ads.linkedin.com", "analytics.linkedin.com", "px.ads.linkedin.com",
            "ads.tiktok.com", "analytics.tiktok.com", "log.tiktok.com",
            "ads.reddit.com", "events.reddit.com", "analytics.reddit.com",
            "adnxs.com", "advertising.com", "atdmt.com", "bkrtx.com",
            "casalemedia.com", "criteo.com", "distroscale.com", "exponential.com",
            "gravity.com", "indexww.com", "innovid.com", "krxd.net",
            "mathtag.com", "moatads.com", "openx.net", "pubmatic.com",
            "rubiconproject.com", "serving-sys.com", "sharethrough.com",
            "smartadserver.com", "spotxchange.com", "taboola.com", "tremorhub.com",
            "turn.com", "undertone.com", "videohub.tv", "yieldmo.com",
            "zemanta.com", "adsrvr.org", "adform.net", "adcolony.com",
            "applovin.com", "chartboost.com", "ironsource.com", "unityads.unity3d.com",
            "vungle.com", "mopub.com", "flurry.com", "adjust.com",
            "appsflyer.com", "kochava.com", "tune.com", "branch.io",
            "amplitude.com", "mixpanel.com", "heap.io", "hotjar.com",
            "crazyegg.com", "mouseflow.com", "sessioncam.com", "fullstory.com",
            "smartlook.com", "luckyorange.com", "inspectlet.com", "clicktale.com",
            "ptengine.cn", "GrowingIO.com", "sensorsdata.cn", "神策数据.com"
        ]

        for (索引, 域名) in 广告域名.enumerated() {
            规则.append(分流规则项(
                名称: "广告拦截 - \(域名)",
                类型: .域名后缀,
                匹配值: 域名,
                动作: .拦截,
                优先级: 10 + 索引,
                备注: "广告和追踪域名拦截"
            ))
        }

        return 预设规则集(
            名称: "广告拦截",
            描述: "拦截常见广告和用户追踪域名",
            图标: "hand.raised",
            规则列表: 规则
        )
    }()

    /// 全局代理规则集
    static let 全局代理: 预设规则集 = {
        let 规则 = [
            分流规则项(
                名称: "全部流量代理",
                类型: .全部,
                匹配值: "*",
                动作: .全局代理,
                优先级: 999,
                备注: "所有流量走代理"
            )
        ]

        return 预设规则集(
            名称: "全局代理",
            描述: "所有网络流量全部走代理节点",
            图标: "globe",
            规则列表: 规则
        )
    }()

    /// 局域网直连规则集
    static let 局域网直连: 预设规则集 = {
        let 规则 = [
            分流规则项(名称: "本地回环", 类型: .IP段, 匹配值: "127.0.0.0/8", 动作: .直连, 优先级: 1, 备注: "本地回环地址"),
            分流规则项(名称: "私有网络A", 类型: .IP段, 匹配值: "10.0.0.0/8", 动作: .直连, 优先级: 2, 备注: "私有网络A类"),
            分流规则项(名称: "私有网络B", 类型: .IP段, 匹配值: "172.16.0.0/12", 动作: .直连, 优先级: 3, 备注: "私有网络B类"),
            分流规则项(名称: "私有网络C", 类型: .IP段, 匹配值: "192.168.0.0/16", 动作: .直连, 优先级: 4, 备注: "私有网络C类"),
            分流规则项(名称: "链路本地", 类型: .IP段, 匹配值: "169.254.0.0/16", 动作: .直连, 优先级: 5, 备注: "链路本地地址"),
            分流规则项(名称: "组播地址", 类型: .IP段, 匹配值: "224.0.0.0/4", 动作: .直连, 优先级: 6, 备注: "组播地址"),
            分流规则项(名称: "广播地址", 类型: .IP段, 匹配值: "255.255.255.255/32", 动作: .直连, 优先级: 7, 备注: "广播地址"),
            分流规则项(名称: "本地主机名", 类型: .域名精确, 匹配值: "localhost", 动作: .直连, 优先级: 8, 备注: "本地主机名")
        ]

        return 预设规则集(
            名称: "局域网直连",
            描述: "局域网和私有网络地址直连",
            图标: "network",
            规则列表: 规则
        )
    }()

    /// 所有内置预设
    static let 所有预设: [预设规则集] = [
        .局域网直连,
        .国内直连,
        .广告拦截,
        .全局代理
    ]
}

// MARK: - 分流规则测试结果

/// 分流规则匹配测试结果
struct 分流测试结果 {
    /// 测试的域名/IP
    let 测试值: String
    /// 匹配到的规则
    var 匹配规则: 分流规则项?
    /// 最终动作
    var 最终动作: 分流动作
    /// 匹配过程（规则名称: 是否匹配）
    var 匹配过程: [(规则名称: String, 匹配: Bool)]
    /// 测试时间
    let 测试时间: Date

    /// 结果描述
    var 结果描述: String {
        if let 规则 = 匹配规则 {
            return "匹配规则「\(规则.名称)」，动作：\(规则.动作.rawValue)"
        }
        return "未匹配到任何规则，使用默认动作"
    }
}

// MARK: - 分流配置

/// 分流全局配置
struct 分流配置模型: Codable {
    /// 是否启用分流
    var 启用分流: Bool = true
    /// 默认动作（未匹配规则时）
    var 默认动作: 分流动作 = .代理
    /// 规则分组列表
    var 分组列表: [分流规则分组] = []
    /// 是否启用规则统计
    var 启用统计: Bool = true
    /// 最大统计记录数
    var 最大统计数: Int = 1000
    /// 是否按域名分流
    var 按域名分流: Bool = true
    /// 是否按IP分流
    var 按IP分流: Bool = true
    /// 是否按端口分流
    var 按端口分流: Bool = false
    /// 是否按协议分流
    var 按协议分流: Bool = false

    /// 所有规则（按优先级排序）
    var 所有规则: [分流规则项] {
        分组列表
            .filter { $0.启用 }
            .flatMap { $0.规则列表 }
            .filter { $0.启用 }
            .sorted { $0.优先级 < $1.优先级 }
    }

    /// 默认配置
    static let 默认 = 分流配置模型(
        分组列表: [
            分流规则分组(名称: "默认规则", 描述: "系统默认分流规则", 图标: "star", 规则列表: [])
        ]
    )
}
