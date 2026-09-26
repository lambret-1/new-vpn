//
//  SingBox模型.swift
//  NewVPN
//
//  sing-box 内核配置数据模型
//  映射 sing-box JSON 配置结构
//

import Foundation

// MARK: - sing-box 完整配置

/// sing-box 完整配置
struct SingBox配置: Codable, Equatable {
    /// 日志配置
    var log: SingBox日志配置?
    /// DNS 配置
    var dns: SingBoxDNS配置?
    /// 入站配置列表
    var inbounds: [SingBox入站配置]?
    /// 出站配置列表
    var outbounds: [SingBox出站配置]?
    /// 路由配置
    var route: SingBox路由配置?
    /// 实验性功能
    var experimental: SingBox实验配置?

    /// 初始化
    init(log: SingBox日志配置? = nil,
         dns: SingBoxDNS配置? = nil,
         inbounds: [SingBox入站配置]? = nil,
         outbounds: [SingBox出站配置]? = nil,
         route: SingBox路由配置? = nil,
         experimental: SingBox实验配置? = nil) {
        self.log = log
        self.dns = dns
        self.inbounds = inbounds
        self.outbounds = outbounds
        self.route = route
        self.experimental = experimental
    }

    /// 转换为 JSON 数据
    func 转换为JSON数据(格式化: Bool = true) -> Data? {
        let 编码器 = JSONEncoder()
        编码器.keyEncodingStrategy = .convertToSnakeCase
        if 格式化 {
            编码器.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try? 编码器.encode(self)
    }

    /// 转换为 JSON 字符串
    func 转换为JSON字符串(格式化: Bool = true) -> String? {
        guard let 数据 = 转换为JSON数据(格式化: 格式化) else { return nil }
        return String(data: 数据, encoding: .utf8)
    }

    /// 从 JSON 数据解析
    static func 从JSON数据(_ 数据: Data) -> SingBox配置? {
        try? JSONDecoder().decode(SingBox配置.self, from: 数据)
    }

    /// 从 JSON 字符串解析
    static func 从JSON字符串(_ 字符串: String) -> SingBox配置? {
        guard let 数据 = 字符串.data(using: .utf8) else { return nil }
        return 从JSON数据(数据)
    }
}

// MARK: - 日志配置

/// sing-box 日志配置
struct SingBox日志配置: Codable, Equatable {
    /// 日志输出级别
    var level: String = "info"
    /// 日志输出路径（空表示输出到控制台）
    var output: String?
    /// 日志时间戳格式
    var timestamp: Bool = true
    /// 是否禁用颜色
    var disableColor: Bool?
    /// 是否禁用回退
    var disableFallback: Bool?

    /// 日志级别枚举
    enum 日志级别: String, CaseIterable {
        case trace = "trace"
        case debug = "debug"
        case info = "info"
        case warn = "warn"
        case error = "error"
        case fatal = "fatal"
        case panic = "panic"
    }

    /// 默认配置
    static let 默认 = SingBox日志配置(level: "info", timestamp: true)
}

// MARK: - DNS 配置

/// sing-box DNS 配置
struct SingBoxDNS配置: Codable, Equatable {
    /// DNS 服务器列表
    var servers: [SingBoxDNS服务器]?
    /// 最终 DNS 服务器标签
    var final: String?
    /// DNS 策略
    var strategy: String?
    /// 是否禁用缓存
    var disableCache: Bool?
    /// 是否禁用过期缓存
    var disableExpire: Bool?
    /// 是否独立缓存每个客户端
    var independentCache: Bool?
    /// 反向映射大小
    var reverseMappingSize: Int?
    /// DNS 规则列表
    var rules: [SingBoxDNS规则]?

    /// 默认配置（兼容当前 libbox 版本，detour 避免 DNS 回环）
    /// dns_resolver 用 TCP 而非 UDP：iOS NE 下 DIRECT 出站 bind_interface 后 UDP 回包失败
    static let 默认 = SingBoxDNS配置(
        servers: [
            SingBoxDNS服务器.tcp服务器(标签: "dns_resolver", 地址: "223.5.5.5", 出站: "DIRECT"),
            SingBoxDNS服务器.tls服务器(标签: "dns_proxy", 地址: "8.8.8.8", 出站: "proxy")
        ],
        final: "dns_proxy",
        strategy: "ipv4_only"
    )
}

/// sing-box DNS 服务器
/// sing-box DNS 服务器（旧格式 address，兼容当前 libbox 版本）
struct SingBoxDNS服务器: Codable, Equatable {
    /// 服务器标签
    var tag: String
    /// 服务器地址（包含协议前缀，如 tls://8.8.8.8、https://1.1.1.1/dns-query）
    var address: String
    /// 出站标签（指定 DNS 查询走哪个出站，避免回环）
    var detour: String?

    /// 创建 UDP DNS 服务器
    static func udp服务器(标签: String, 地址: String, 端口: Int? = nil, 出站: String? = nil) -> SingBoxDNS服务器 {
        let 地址字符串 = 端口 != nil ? "\(地址):\(端口!)" : 地址
        return SingBoxDNS服务器(tag: 标签, address: 地址字符串, detour: 出站)
    }

    /// 创建 TCP DNS 服务器（纯 TCP 53 端口，不加密。iOS NE 下 DIRECT 出站 UDP 回包失败，TCP 正常）
    static func tcp服务器(标签: String, 地址: String, 端口: Int? = nil, 出站: String? = nil) -> SingBoxDNS服务器 {
        let 地址字符串 = 端口 != nil ? "tcp://\(地址):\(端口!)" : "tcp://\(地址)"
        return SingBoxDNS服务器(tag: 标签, address: 地址字符串, detour: 出站)
    }

    /// 创建 TLS DNS 服务器
    static func tls服务器(标签: String, 地址: String, 域名解析器: String? = nil, 出站: String? = nil) -> SingBoxDNS服务器 {
        SingBoxDNS服务器(tag: 标签, address: "tls://\(地址)", detour: 出站)
    }

    /// 创建 H3 DNS 服务器
    static func h3服务器(标签: String, 地址: String, 域名解析器: String? = nil, 出站: String? = nil) -> SingBoxDNS服务器 {
        SingBoxDNS服务器(tag: 标签, address: "h3://\(地址)/dns-query", detour: 出站)
    }

    /// 创建 HTTPS DNS 服务器
    static func https服务器(标签: String, 地址: String, 出站: String? = nil) -> SingBoxDNS服务器 {
        let 路径 = 地址.hasPrefix("https://") ? 地址 : "https://\(地址)/dns-query"
        return SingBoxDNS服务器(tag: 标签, address: 路径, detour: 出站)
    }

    /// 创建 fakeip DNS 服务器
    static func fakeip服务器(标签: String, IPv4范围: String) -> SingBoxDNS服务器 {
        SingBoxDNS服务器(tag: 标签, address: "fakeip")
    }

    enum CodingKeys: String, CodingKey {
        case tag
        case address
        case detour
    }
}

/// sing-box DNS 规则（旧格式，兼容当前 libbox 版本）
struct SingBoxDNS规则: Codable, Equatable {
    /// 目标 DNS 服务器标签
    var server: String?
    /// 规则集标签列表（geosite/geoip）
    var ruleSet: [String]?
    /// 查询类型列表（A/AAAA/HTTPS 等）
    var queryType: [String]?
    /// 拒绝响应码（如 NOERROR）
    var rcode: String?
    /// 域名列表
    var domain: [String]?
    /// 域名后缀列表
    var domainSuffix: [String]?
    /// 域名关键词列表
    var domainKeyword: [String]?
    /// 域名正则列表
    var domainRegex: [String]?
    /// 出站标签列表（任意匹配）
    var outboundAny: [String]?
    /// 出站标签（全部匹配）
    var outboundAll: [String]?
    /// 是否拒绝解析
    var reject: Bool?
    /// 拒绝方法
    var rejectMethod: String?

    /// 创建域名 DNS 规则（指定域名走某个 DNS 服务器）
    init(域名: [String], 服务器: String) {
        self.domain = 域名
        self.server = 服务器
    }

    /// 创建域名后缀 DNS 规则（指定域名后缀走某个 DNS 服务器）
    init(域名后缀: [String], 服务器: String) {
        self.domainSuffix = 域名后缀
        self.server = 服务器
    }

    enum CodingKeys: String, CodingKey {
        case server
        case ruleSet = "rule_set"
        case queryType = "query_type"
        case rcode
        case domain
        case domainSuffix = "domain_suffix"
        case domainKeyword = "domain_keyword"
        case domainRegex = "domain_regex"
        case outboundAny = "outbound_any"
        case outboundAll = "outbound_all"
        case reject
        case rejectMethod = "reject_method"
    }
}

// MARK: - 入站配置

/// sing-box 入站配置
struct SingBox入站配置: Codable, Equatable {
    /// 入站类型
    var type: String
    /// 入站标签
    var tag: String
    /// 监听地址
    var listen: String?
    /// 监听端口
    var listenPort: Int?
    /// TCP 快速打开
    var tcpFastOpen: Bool?
    /// TCP 多路径
    var tcpMultiPath: Bool?
    /// UDP 转发
    var udpForward: Bool?
    /// UDP 超时
    var udpTimeout: String?
    /// 入站用户列表
    var users: [SingBox入站用户]?
    /// TLS 配置
    var tls: SingBoxTLS配置?
    /// 传输配置
    var transport: SingBox传输配置?
    /// 多路复用配置
    var multiplex: SingBox多路复用配置?
    /// TUN 地址列表
    var address: [String]?
    /// TUN MTU
    var mtu: Int?
    /// TUN 自动路由
    var autoRoute: Bool?
    /// TUN 严格路由
    var strictRoute: Bool?
    /// TUN 网络栈（system/gvisor）
    var stack: String?
    /// TUN 接口名
    var interfaceName: String?
    /// 是否启用协议嗅探
    var sniff: Bool?
    /// 嗅探是否覆盖目标地址
    var sniffOverrideDestination: Bool?
    /// 嗅探超时
    var sniffTimeout: String?

    /// 创建 TUN 入站
    static func tun入站(标签: String = "tun-in",
                        地址: String = "172.19.0.1/30",
                        MTU: Int = 1500,
                        自动路由: Bool = true,
                        严格路由: Bool = true,
                        网络栈: String = "system",
                        启用嗅探: Bool = true) -> SingBox入站配置 {
        var 配置 = SingBox入站配置(type: "tun", tag: 标签)
        配置.address = [地址]
        配置.mtu = MTU
        配置.autoRoute = 自动路由
        配置.strictRoute = 严格路由
        配置.stack = 网络栈
        配置.sniff = 启用嗅探
        配置.sniffOverrideDestination = false
        配置.sniffTimeout = "300ms"
        return 配置
    }

    /// 创建 Mixed 入站（HTTP+SOCKS5）
    static func mixed入站(标签: String = "mixed-in",
                          地址: String = "127.0.0.1",
                          端口: Int = 7890) -> SingBox入站配置 {
        var 配置 = SingBox入站配置(type: "mixed", tag: 标签)
        配置.listen = 地址
        配置.listenPort = 端口
        return 配置
    }

    /// 创建 SOCKS 入站
    static func socks入站(标签: String = "socks-in",
                          地址: String = "127.0.0.1",
                          端口: Int = 1080) -> SingBox入站配置 {
        var 配置 = SingBox入站配置(type: "socks", tag: 标签)
        配置.listen = 地址
        配置.listenPort = 端口
        return 配置
    }

    /// 创建 HTTP 入站
    static func http入站(标签: String = "http-in",
                         地址: String = "127.0.0.1",
                         端口: Int = 8080) -> SingBox入站配置 {
        var 配置 = SingBox入站配置(type: "http", tag: 标签)
        配置.listen = 地址
        配置.listenPort = 端口
        return 配置
    }

    /// 创建 API 入站（用于查询连接列表、统计信息等）
    static func api入站(标签: String = "api",
                        地址: String = "127.0.0.1",
                        端口: Int = 9090) -> SingBox入站配置 {
        var 配置 = SingBox入站配置(type: "api", tag: 标签)
        配置.listen = 地址
        配置.listenPort = 端口
        return 配置
    }

    enum CodingKeys: String, CodingKey {
        case type
        case tag
        case listen
        case listenPort = "listen_port"
        case tcpFastOpen = "tcp_fast_open"
        case tcpMultiPath = "tcp_multi_path"
        case udpForward = "udp_forward"
        case udpTimeout = "udp_timeout"
        case users
        case tls
        case transport
        case multiplex
        case address
        case mtu
        case autoRoute = "auto_route"
        case strictRoute = "strict_route"
        case stack
        case interfaceName = "interface_name"
        case sniff
        case sniffOverrideDestination = "sniff_override_destination"
        case sniffTimeout = "sniff_timeout"
    }
}

/// sing-box 入站用户
struct SingBox入站用户: Codable, Equatable {
    /// 用户名
    var username: String
    /// 密码
    var password: String?
    /// SAG 认证
    var sag: Bool?
}

// MARK: - 出站配置

/// sing-box 出站配置
struct SingBox出站配置: Codable, Equatable {
    /// 出站类型
    var type: String
    /// 出站标签
    var tag: String
    /// 服务器地址
    var server: String?
    /// 服务器端口
    var serverPort: Int?
    /// TCP 快速打开
    var tcpFastOpen: Bool?
    /// TCP 多路径
    var tcpMultiPath: Bool?
    /// UDP 转发
    var udpForward: Bool?
    /// 网络类型（tcp/udp/""）
    var network: String?
    /// 用户名
    var username: String?
    /// 密码
    var password: String?
    /// UUID（VLESS/VMess）
    var uuid: String?
    /// 流控（VLESS）
    var flow: String?
    /// 加密方式（VMess/Shadowsocks）
    var security: String?
    /// 加密方式（Shadowsocks）
    var method: String?
    /// TLS 配置
    var tls: SingBoxTLS配置?
    /// 传输配置
    var transport: SingBox传输配置?
    /// 多路复用配置
    var multiplex: SingBox多路复用配置?
    /// 拨号器配置
    var dialerOptions: SingBox拨号器配置?
    /// 出站标签列表（selector/urltest）
    var outbounds: [String]?
    /// 测试 URL（urltest）
    var url: String?
    /// 测试间隔（urltest）
    var interval: String?
    /// 容忍度（urltest）
    var tolerance: Int?
    /// 拦截方法（block）
    var blockMethod: String?
    /// 无响应（dns）
    var noDrop: Bool?
    /// 代理协议版本（socks/http）
    var version: String?
    /// 节点地址（direct）
    var overrideAddress: String?
    /// 节点端口（direct）
    var overridePort: Int?
    /// 包编码（VLESS：xudp/none）
    var packetEncoding: String?
    /// 绑定物理网卡接口名（en0=WiFi, pdp_ip0=蜂窝），直连出站必须设置避免回环
    var bindInterface: String?

    /// 创建 VLESS 出站
    static func vless出站(标签: String,
                          服务器: String,
                          端口: Int,
                          UUID: String,
                          流控: String? = nil,
                          加密: String? = "none",
                          TLS: SingBoxTLS配置? = nil,
                          传输: SingBox传输配置? = nil) -> SingBox出站配置 {
        var 配置 = SingBox出站配置(type: "vless", tag: 标签)
        配置.server = 服务器
        配置.serverPort = 端口
        配置.uuid = UUID
        配置.flow = 流控
        // 注意：VLESS 出站没有 security 字段，那是 VMess 的字段
        // security 字段会导致 sing-box 解析配置失败
        // packet_encoding 不手动设置，使用 sing-box 默认值
        配置.tls = TLS
        配置.transport = 传输
        return 配置
    }

    /// 创建 VMess 出站
    static func vmess出站(标签: String,
                          服务器: String,
                          端口: Int,
                          UUID: String,
                          加密: String? = "auto",
                          alterId: Int? = 0,
                          TLS: SingBoxTLS配置? = nil,
                          传输: SingBox传输配置? = nil) -> SingBox出站配置 {
        var 配置 = SingBox出站配置(type: "vmess", tag: 标签)
        配置.server = 服务器
        配置.serverPort = 端口
        配置.uuid = UUID
        配置.security = 加密
        配置.tls = TLS
        配置.transport = 传输
        return 配置
    }

    /// 创建 Trojan 出站
    static func trojan出站(标签: String,
                           服务器: String,
                           端口: Int,
                           密码: String,
                           TLS: SingBoxTLS配置? = nil,
                           传输: SingBox传输配置? = nil) -> SingBox出站配置 {
        var 配置 = SingBox出站配置(type: "trojan", tag: 标签)
        配置.server = 服务器
        配置.serverPort = 端口
        配置.password = 密码
        配置.tls = TLS
        配置.transport = 传输
        return 配置
    }

    /// 创建 Shadowsocks 出站
    static func shadowsocks出站(标签: String,
                                服务器: String,
                                端口: Int,
                                方法: String,
                                密码: String) -> SingBox出站配置 {
        var 配置 = SingBox出站配置(type: "shadowsocks", tag: 标签)
        配置.server = 服务器
        配置.serverPort = 端口
        配置.method = 方法
        配置.password = 密码
        return 配置
    }

    /// 创建 Direct 出站（标签大写对齐官方客户端）
    /// - Parameter 绑定接口: 物理网卡接口名（en0=WiFi, pdp_ip0=蜂窝），绑定后直连流量走物理网卡避免回环
    static func direct出站(标签: String = "DIRECT", 绑定接口: String? = "en0") -> SingBox出站配置 {
        var 配置 = SingBox出站配置(type: "direct", tag: 标签)
        配置.bindInterface = 绑定接口
        return 配置
    }

    /// 创建 Block 出站（标签大写对齐官方客户端）
    static func block出站(标签: String = "REJECT") -> SingBox出站配置 {
        SingBox出站配置(type: "block", tag: 标签)
    }

    /// 创建 Selector 出站
    static func selector出站(标签: String, 出站列表: [String]) -> SingBox出站配置 {
        var 配置 = SingBox出站配置(type: "selector", tag: 标签)
        配置.outbounds = 出站列表
        return 配置
    }

    /// 创建 URLTest 出站
    static func urlTest出站(标签: String,
                            出站列表: [String],
                            测试URL: String = "http://www.gstatic.com/generate_204",
                            间隔: String = "5m") -> SingBox出站配置 {
        var 配置 = SingBox出站配置(type: "urltest", tag: 标签)
        配置.outbounds = 出站列表
        配置.url = 测试URL
        配置.interval = 间隔
        return 配置
    }

    enum CodingKeys: String, CodingKey {
        case type
        case tag
        case server
        case serverPort = "server_port"
        case tcpFastOpen = "tcp_fast_open"
        case tcpMultiPath = "tcp_multi_path"
        case udpForward = "udp_forward"
        case network
        case username
        case password
        case uuid
        case flow
        case security
        case method
        case tls
        case transport
        case multiplex
        case dialerOptions = "dialer_options"
        case outbounds
        case url
        case interval
        case tolerance
        case blockMethod = "block_method"
        case noDrop = "no_drop"
        case version
        case overrideAddress = "override_address"
        case overridePort = "override_port"
        case packetEncoding = "packet_encoding"
        case bindInterface = "bind_interface"
    }
}

// MARK: - TLS 配置

/// sing-box TLS 配置
struct SingBoxTLS配置: Codable, Equatable {
    /// 是否启用
    var enabled: Bool = true
    /// 服务器名称（SNI）
    var serverName: String?
    /// 是否跳过证书验证
    var insecure: Bool?
    /// ALPN 列表
    var alpn: [String]?
    /// 最小 TLS 版本
    var minVersion: String?
    /// 最大 TLS 版本
    var maxVersion: String?
    /// 证书指纹列表
    var certificateFingerprint: [String]?
    /// 证书路径
    var certificatePath: String?
    /// ECH 配置
    var ech: SingBoxECH配置?
    /// UTLS 配置
    var utls: SingBoxUTLS配置?
    /// Reality 配置
    var reality: SingBoxReality配置?

    /// 创建标准 TLS 配置
    static func 标准TLS(SNI: String? = nil, 跳过验证: Bool = false) -> SingBoxTLS配置 {
        var 配置 = SingBoxTLS配置(enabled: true)
        配置.serverName = SNI
        配置.insecure = 跳过验证
        配置.minVersion = "1.2"
        // uTLS 指纹伪装，模拟 Chrome 浏览器 TLS 握手
        配置.utls = SingBoxUTLS配置(enabled: true, fingerprint: "chrome")
        return 配置
    }

    /// 创建 Reality TLS 配置
    static func realityTLS(SNI: String, 公钥: String, 短ID: String) -> SingBoxTLS配置 {
        var 配置 = SingBoxTLS配置(enabled: true)
        配置.serverName = SNI
        配置.reality = SingBoxReality配置(
            enabled: true,
            publicKey: 公钥,
            shortId: 短ID
        )
        return 配置
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case serverName = "server_name"
        case insecure
        case alpn
        case minVersion = "min_version"
        case maxVersion = "max_version"
        case certificateFingerprint = "certificate_fingerprint"
        case certificatePath = "certificate_path"
        case ech
        case utls
        case reality
    }
}

/// sing-box ECH 配置
struct SingBoxECH配置: Codable, Equatable {
    var enabled: Bool
    var pqSignatureSchemesEnabled: Bool?
}

/// sing-box UTLS 配置
struct SingBoxUTLS配置: Codable, Equatable {
    var enabled: Bool
    var fingerprint: String?
}

/// sing-box Reality 配置
struct SingBoxReality配置: Codable, Equatable {
    var enabled: Bool
    var publicKey: String?
    var shortId: String?
}

// MARK: - 传输配置

/// sing-box 传输配置
struct SingBox传输配置: Codable, Equatable {
    /// 传输类型
    var type: String
    /// 路径（ws/httpupgrade/grpc）
    var path: String?
    /// 主机头（ws/httpupgrade）
    var host: String?
    /// 服务名称（grpc）
    var serviceName: String?
    /// 头部信息（ws）
    var headers: [String: String]?
    /// 是否允许延迟确认（httpupgrade）
    var delayAccept: Bool?
    /// 早期数据大小（httpupgrade）
    var earlyDataHeaderName: String?
    /// 最大早期数据长度（httpupgrade）
    var maxEarlyData: Int?
    /// 模式（meek）
    var mode: String?
    /// URL（meek）
    var url: String?
    /// 是否填充（meek）
    var padding: Bool?
    /// 模拟 XHR（meek）
    var mockXHR: Bool?

    /// 创建 WebSocket 传输
    /// - Parameters:
    ///   - 路径: WebSocket 路径
    ///   - 主机: WebSocket Host 头
    ///   - 头部: 自定义头部
    ///   - 禁用早期数据: 是否禁用 early_data（默认禁用，提升服务端兼容性）
    static func ws传输(路径: String = "/", 主机: String? = nil, 头部: [String: String]? = nil, 禁用早期数据: Bool = true) -> SingBox传输配置 {
        var 配置 = SingBox传输配置(type: "ws")
        配置.path = 路径
        // host 必须放在 headers 中，sing-box 不认识 transport.host 字段
        if let 主机 = 主机, !主机.isEmpty {
            var 合并头部 = 头部 ?? [:]
            合并头部["Host"] = 主机
            配置.headers = 合并头部
        } else {
            配置.headers = 头部
        }
        // 禁用 early_data：部分服务端（Xray/V2Ray 旧版本）不支持 early_data，
        // 启用后会导致服务端直接断开连接（ws closed: 1005）
        if 禁用早期数据 {
            配置.maxEarlyData = 0
        }
        return 配置
    }

    /// 创建 gRPC 传输
    static func grpc传输(服务名: String = "GunService") -> SingBox传输配置 {
        var 配置 = SingBox传输配置(type: "grpc")
        配置.serviceName = 服务名
        return 配置
    }

    /// 创建 HTTPUpgrade 传输
    static func httpUpgrade传输(路径: String = "/", 主机: String? = nil) -> SingBox传输配置 {
        var 配置 = SingBox传输配置(type: "httpupgrade")
        配置.path = 路径
        // host 必须放在 headers 中
        if let 主机 = 主机, !主机.isEmpty {
            配置.headers = ["Host": 主机]
        }
        return 配置
    }

    /// 创建 Meek 传输
    static func meek传输(URL: String, 模式: String = "FIFO") -> SingBox传输配置 {
        var 配置 = SingBox传输配置(type: "meek")
        配置.url = URL
        配置.mode = 模式
        return 配置
    }

    enum CodingKeys: String, CodingKey {
        case type
        case path
        case host
        case serviceName = "service_name"
        case headers
        case delayAccept = "delay_accept"
        case earlyDataHeaderName = "early_data_header_name"
        case maxEarlyData = "max_early_data"
        case mode
        case url
        case padding
        case mockXHR = "mock_xhr"
    }
}

// MARK: - 多路复用配置

/// sing-box 多路复用配置
struct SingBox多路复用配置: Codable, Equatable {
    /// 是否启用
    var enabled: Bool
    /// 协议类型
    var protocol_: String?
    /// 最大连接数
    var maxConnections: Int?
    /// 最小流数
    var minStreams: Int?
    /// 最大流数
    var maxStreams: Int?
    /// 填充
    var padding: Bool?
    /// 暴力模式
    var bruteForce: Bool?

    enum CodingKeys: String, CodingKey {
        case enabled
        case protocol_ = "protocol"
        case maxConnections
        case minStreams
        case maxStreams
        case padding
        case bruteForce
    }
}

// MARK: - 拨号器配置

/// sing-box 拨号器配置
struct SingBox拨号器配置: Codable, Equatable {
    /// 出站接口
    var interfaceName: String? = nil
    /// 路由表索引
    var routingMark: Int? = nil
    /// 连接超时
    var connectTimeout: String? = nil
    /// 域名解析策略
    var domainStrategy: String? = nil
    /// 域名解析器标签
    var domainResolver: String? = nil
    /// 独立栈
    var independentStack: Bool? = nil
    /// TCP 快速打开
    var tcpFastOpen: Bool? = nil
    /// TCP 多路径
    var tcpMultiPath: Bool? = nil
    /// TCP keep-alive 间隔
    var tcpKeepAliveInterval: String? = nil
    /// TCP no-delay
    var tcpNoDelay: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case interfaceName = "interface_name"
        case routingMark = "routing_mark"
        case connectTimeout = "connect_timeout"
        case domainStrategy = "domain_strategy"
        case domainResolver = "domain_resolver"
        case independentStack = "independent_stack"
        case tcpFastOpen = "tcp_fast_open"
        case tcpMultiPath = "tcp_multi_path"
        case tcpKeepAliveInterval = "tcp_keep_alive_interval"
        case tcpNoDelay = "tcp_no_delay"
    }
}

// MARK: - 路由配置

/// sing-box 路由配置（对齐官方客户端格式）
struct SingBox路由配置: Codable, Equatable {
    /// 最终出站标签
    var final: String?
    /// 自动检测接口
    var autoDetectInterface: Bool?
    /// 路由规则列表
    var rules: [SingBox路由规则]?
    /// 规则集列表
    var ruleSet: [SingBox规则集]?

    /// 默认配置（兼容当前 libbox 版本）
    static let 默认 = SingBox路由配置(
        final: "proxy",
        autoDetectInterface: false,
        rules: [
            // 私有 IP 直连
            SingBox路由规则(ipIsPrivate: true, outbound: "DIRECT"),
            // 局域网地址直连
            SingBox路由规则(
                ipCidr: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8"],
                outbound: "DIRECT"
            )
        ]
    )

    enum CodingKeys: String, CodingKey {
        case final
        case autoDetectInterface = "auto_detect_interface"
        case rules
        case ruleSet = "rule_set"
    }
}

/// sing-box 路由规则
struct SingBox路由规则: Codable, Equatable {
    /// 规则标签
    var tag: String?
    /// 域名列表
    var domain: [String]?
    /// 域名后缀列表
    var domainSuffix: [String]?
    /// 域名关键词列表
    var domainKeyword: [String]?
    /// 域名正则列表
    var domainRegex: [String]?
    /// 域名集合
    var domainSet: [String]?
    /// 源域名列表
    var sourceDomain: [String]?
    /// 源域名后缀列表
    var sourceDomainSuffix: [String]?
    /// 源域名关键词列表
    var sourceDomainKeyword: [String]?
    /// 源域名正则列表
    var sourceDomainRegex: [String]?
    /// IP 列表
    var ipCidr: [String]?
    /// IP 集合
    var ipSet: [String]?
    /// 源 IP 列表
    var sourceIpCidr: [String]?
    /// 源 IP 集合
    var sourceIpSet: [String]?
    /// 是否私有 IP
    var ipIsPrivate: Bool?
    /// 源是否私有 IP
    var sourceIpIsPrivate: Bool?
    /// 端口列表
    var port: [Int]?
    /// 端口范围列表
    var portRange: [String]?
    /// 源端口列表
    var sourcePort: [Int]?
    /// 源端口范围列表
    var sourcePortRange: [String]?
    /// 协议列表
    var protocol_: [String]?
    /// 网络列表
    var network: [String]?
    /// 认证用户名列表
    var authUser: [String]?
    /// 出站标签列表（任意匹配）
    var outboundAny: [String]?
    /// 出站标签列表（全部匹配）
    var outboundAll: [String]?
    /// 入站标签列表
    var inbound: [String]?
    /// 进程名称列表
    var processName: [String]?
    /// 进程路径列表
    var processPath: [String]?
    /// 包名列表
    var packageName: [String]?
    /// 网络类型列表
    var networkType: [String]?
    /// 是否被劫持
    var hijackDns: Bool?
    /// 目标出站标签
    var outbound: String?
    /// 规则集标签
    var ruleSet: [String]?
    /// 是否取反
    var invert: Bool?

    enum CodingKeys: String, CodingKey {
        case tag
        case domain
        case domainSuffix
        case domainKeyword
        case domainRegex
        case domainSet
        case sourceDomain
        case sourceDomainSuffix
        case sourceDomainKeyword
        case sourceDomainRegex
        case ipCidr
        case ipSet
        case sourceIpCidr
        case sourceIpSet
        case ipIsPrivate
        case sourceIpIsPrivate
        case port
        case portRange
        case sourcePort
        case sourcePortRange
        case protocol_ = "protocol"
        case network
        case authUser
        case outboundAny
        case outboundAll
        case inbound
        case processName
        case processPath
        case packageName
        case networkType
        case hijackDns
        case outbound
        case ruleSet
        case invert
    }
}

/// sing-box 规则集
struct SingBox规则集: Codable, Equatable {
    /// 规则集标签
    var tag: String
    /// 规则集类型
    var type: String
    /// 规则集格式
    var format: String?
    /// 规则集 URL
    var url: String?
    /// 规则集路径
    var path: String?
    /// 更新间隔
    var updateInterval: String?
    /// 下载拨号器
    var downloadDialer: String?

    enum CodingKeys: String, CodingKey {
        case tag
        case type
        case format
        case url
        case path
        case updateInterval = "update_interval"
        case downloadDialer = "download_dialer"
    }
}

// MARK: - 实验配置

/// sing-box 实验配置
struct SingBox实验配置: Codable, Equatable {
    /// 缓存文件配置
    var cacheFile: SingBox缓存文件配置?
    /// Clash API 配置
    var clashApi: SingBoxClashAPI配置?
    /// V2Ray API 配置
    var v2rayApi: SingBoxV2RayAPI配置?

    enum CodingKeys: String, CodingKey {
        case cacheFile = "cache_file"
        case clashApi = "clash_api"
        case v2rayApi = "v2ray_api"
    }
}

/// sing-box 缓存文件配置
struct SingBox缓存文件配置: Codable, Equatable {
    /// 是否启用
    var enabled: Bool
    /// 缓存文件路径
    var path: String?
    /// 缓存 ID
    var cacheId: String?
    /// 存储假 IP
    var storeFakeip: Bool?
    /// 假 IP 名称
    var fakeipName: String?
    /// 假 IP 服务器
    var fakeipServer: String?
    /// 假 IP 前缀
    var fakeipInet4Range: String?
    var fakeipInet6Range: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case path
        case cacheId = "cache_id"
        case storeFakeip = "store_fakeip"
        case fakeipName = "fakeip_name"
        case fakeipServer = "fakeip_server"
        case fakeipInet4Range = "fakeip_inet4_range"
        case fakeipInet6Range = "fakeip_inet6_range"
    }
}

/// sing-box Clash API 配置
struct SingBoxClashAPI配置: Codable, Equatable {
    /// 是否启用
    var enabled: Bool
    /// 监听地址
    var listen: String?
    /// 外部控制器
    var externalController: String?
    /// 密钥
    var secret: String?
    /// 外部 UI
    var externalUI: String?
    /// 外部 UI 下载 URL
    var externalUIDownloadURL: String?
    /// 访问控制允许来源
    var accessControlAllowOrigin: [String]?
    /// 访问控制允许私有网络
    var accessControlAllowPrivateNetwork: Bool?
    /// 延迟测试 URL
    var delayTestUrl: String?
    /// 延迟测试超时
    var delayTestTimeout: String?
    /// 模式
    var mode: String?
}

/// sing-box V2Ray API 配置
struct SingBoxV2RayAPI配置: Codable, Equatable {
    /// 是否启用
    var enabled: Bool
    /// 监听地址
    var listen: String?
    /// 统计服务
    var stats: SingBox统计服务配置?
}

/// sing-box 统计服务配置
struct SingBox统计服务配置: Codable, Equatable {
    /// 是否启用
    var enabled: Bool
    /// 入站流量
    var inbounds: [String]?
    /// 出站流量
    var outbounds: [String]?
    /// 用户流量
    var users: [String]?
}

// MARK: - sing-box 内核状态

/// sing-box 内核运行状态
enum SingBox内核状态: String, Codable, CaseIterable {
    /// 未启动
    case 未启动 = "未启动"
    /// 正在启动
    case 正在启动 = "正在启动"
    /// 运行中
    case 运行中 = "运行中"
    /// 正在停止
    case 正在停止 = "正在停止"
    /// 已停止
    case 已停止 = "已停止"
    /// 启动失败
    case 启动失败 = "启动失败"
    /// 配置错误
    case 配置错误 = "配置错误"

    /// 是否活动
    var 是否活动: Bool {
        switch self {
        case .运行中, .正在启动: return true
        default: return false
        }
    }

    /// 状态颜色
    var 状态颜色: String {
        switch self {
        case .运行中: return "success"
        case .正在启动: return "warning"
        case .未启动, .已停止: return "secondary"
        case .正在停止: return "warning"
        case .启动失败, .配置错误: return "danger"
        }
    }
}

// MARK: - sing-box 内核日志

/// sing-box 内核日志条目
struct SingBox内核日志: Identifiable, Codable, Equatable {
    /// 唯一标识
    var id: UUID = UUID()
    /// 日志时间
    var 时间: Date
    /// 日志级别
    var 级别: String
    /// 日志内容
    var 内容: String

    /// 时间显示
    var 时间显示: String {
        let 格式 = DateFormatter()
        格式.dateFormat = "HH:mm:ss.SSS"
        return 格式.string(from: 时间)
    }
}
