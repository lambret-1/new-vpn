//
//  SingBox配置生成器.swift
//  NewVPN
//
//  sing-box 配置生成服务
//  将节点/分流/DNS配置转换为 sing-box JSON 配置
//

import Foundation

// MARK: - sing-box 配置生成器

/// sing-box 配置生成器
final class SingBox配置生成器 {
    /// 共享单例
    static let 共享 = SingBox配置生成器()

    /// 私有初始化
    private init() {}

    // MARK: - 生成完整配置

    /// 生成完整的 sing-box 配置
    /// - Parameters:
    ///   - 节点: 当前选中的节点
    ///   - 节点列表: 所有可用节点（用于 urltest/selector）
    ///   - 分流规则: 分流规则列表
    ///   - DNS配置: DNS 配置
    ///   - 运行模式: 隧道运行模式（规则分流/全局代理/全局直连）
    ///   - 日志级别: 日志级别
    /// - Returns: sing-box 配置
    func 生成配置(节点: 节点模型?,
                  节点列表: [节点模型] = [],
                  分流规则: [分流规则项] = [],
                  DNS配置: DNS配置模型? = nil,
                  运行模式: 隧道运行模式 = .规则分流,
                  日志级别: String = "trace") -> SingBox配置 {
        var 配置 = SingBox配置()

        // 日志配置
        配置.log = SingBox日志配置(
            level: 日志级别,
            timestamp: true
        )

        // DNS 配置
        配置.dns = 生成DNS配置(DNS配置, 节点: 节点, 运行模式: 运行模式)

        // 入站配置
        配置.inbounds = 生成入站配置()

        // 出站配置
        配置.outbounds = 生成出站配置(节点: 节点, 节点列表: 节点列表)

        // 路由配置
        配置.route = 生成路由配置(分流规则: 分流规则, 节点: 节点, 运行模式: 运行模式)

        // 实验配置（缓存文件）
        配置.experimental = SingBox实验配置(
            cacheFile: SingBox缓存文件配置(
                enabled: true,
                path: "cache.db",
                cacheId: "newvpn"
            )
        )

        return 配置
    }

    // MARK: - 生成 DNS 配置（旧格式 address，兼容当前 libbox 版本）

    /// 生成 DNS 配置
    /// - Parameters:
    ///   - DNS配置: 用户自定义 DNS 配置
    ///   - 节点: 当前节点（用于提取代理服务器域名，避免 DNS 回环）
    ///   - 运行模式: 隧道运行模式
    private func 生成DNS配置(_ DNS配置: DNS配置模型?, 节点: 节点模型?, 运行模式: 隧道运行模式) -> SingBoxDNS配置 {
        // DNS 分流策略：
        // dns_resolver: 阿里云 DNS（tcp://223.5.5.5），走 DIRECT，用于国内域名和代理服务器域名解析
        //   关键：必须用 TCP 不能用 UDP。iOS NE 下 DIRECT 出站 bind_interface 后，
        //   UDP 响应包回不到 socket，导致 DNS 超时、代理服务器域名解析失败、proxy 出站无法建立连接。
        // dns_proxy: Google DNS-over-TLS（tls://8.8.8.8），走 proxy，用于国外域名
        let 默认服务器 = [
            SingBoxDNS服务器.tcp服务器(标签: "dns_resolver", 地址: "223.5.5.5", 出站: "DIRECT"),
            SingBoxDNS服务器.tls服务器(标签: "dns_proxy", 地址: "8.8.8.8", 出站: "proxy")
        ]

        // DNS 规则列表
        var DNS规则列表: [SingBoxDNS规则] = []

        // 国内域名走阿里云 DNS 直连解析（域名后缀匹配）
        let 国内域名后缀 = [
            "cn", "com.cn", "net.cn", "org.cn", "gov.cn", "edu.cn",
            "baidu.com", "qq.com", "taobao.com", "tmall.com", "jd.com",
            "weibo.com", "zhihu.com", "bilibili.com", "douyin.com",
            "kuaishou.com", "xiaohongshu.com", "meituan.com", "dianping.com",
            "ctrip.com", "qunar.com", "163.com", "126.com", "sina.com",
            "sohu.com", "ifeng.com", "thepaper.cn", "xinhuanet.com",
            "people.com.cn", "chinadaily.com.cn", "caijing.com.cn",
            "yicai.com", "caixin.com", "36kr.com", "huxiu.com",
            "csdn.net", "jianshu.com", "cnblogs.com", "oschina.net",
            "aliyun.com", "alibaba.com", "alipay.com", "dingtalk.com",
            "feishu.cn", "bytedance.com", "tencent.com", "weixin.qq.com",
            "huawei.com", "xiaomi.com", "oppo.com", "vivo.com.cn",
            "lenovo.com.cn", "zhaopin.com", "51job.com", "liepin.com",
            "bosszhipin.com", "lagou.com", "anjuke.com", "lianjia.com",
            "ke.com", "fang.com", "soufun.com", "eastmoney.com",
            "10jqka.com.cn", "sina.com.cn", "hexun.com", "jrj.com.cn",
            "cnstock.com", "stcn.com", "amap.com", "baidu.cn",
            "autonavi.com", "10086.cn", "189.cn", "10010.com",
            "chinaunicom.cn", "chinatelecom.cn", "chinamobile.com",
            "spdb.com.cn", "icbc.com.cn", "ccb.com", "boc.cn",
            "abchina.com", "cmbchina.com", "bankcomm.com", "cib.com.cn",
            "citicbank.com", "cebbank.com", "psbc.com", "hxb.com.cn",
            "cgbchina.com.cn"
        ]
        DNS规则列表.append(SingBoxDNS规则(域名后缀: 国内域名后缀, 服务器: "dns_resolver"))

        // 关键修复：代理服务器域名强制走直连 DNS 解析，彻底避免 DNS 回环死锁
        // 无论运行模式如何，代理服务器的域名解析都不能走代理通道
        if let 节点地址 = 节点?.地址, !节点地址.isEmpty {
            let 是否IP地址 = 节点地址.allSatisfy({ $0.isNumber || $0 == "." || $0 == ":" })
            if !是否IP地址 {
                DNS规则列表.append(SingBoxDNS规则(域名: [节点地址], 服务器: "dns_resolver"))
            }
        }

        // 根据运行模式决定默认 DNS 服务器
        // 全局直连模式：所有域名都走国内直连 DNS，避免依赖代理通道
        // 规则分流/全局代理：未匹配的域名走代理 DNS（通过隧道查询，避免 DNS 污染）
        let 默认DNS服务器: String
        switch 运行模式 {
        case .全局直连:
            默认DNS服务器 = "dns_resolver"
        case .规则分流, .全局代理:
            默认DNS服务器 = "dns_proxy"
        }

        return SingBoxDNS配置(
            servers: 默认服务器,
            final: 默认DNS服务器,
            strategy: "ipv4_only",
            disableCache: false,
            rules: DNS规则列表
        )
    }

    // MARK: - 生成入站配置

    /// 生成入站配置
    private func 生成入站配置() -> [SingBox入站配置] {
        [
            // TUN 入站（iOS 隧道使用）
            // 注意：Network Extension 中必须用 gvisor 栈，system 栈需要 root 权限
            // auto_route/strict_route 由系统 NEPacketTunnelNetworkSettings 控制，不需 sing-box 管理
            // MTU 降低到 1400：避免物理网卡 MTU 差异导致大包分片被丢弃触发 RST
            // dns_address：拦截发往该地址的 DNS 查询，交由 sing-box 内部 DNS 模块处理（比路由规则+dns-out更可靠）
            // 启用协议嗅探（sniff）：从 TLS Client Hello 中提取 SNI 域名，提升分流精度
            SingBox入站配置.tun入站(
                标签: "tun-in",
                地址: "10.0.0.2/24",
                MTU: 1400,
                自动路由: false,
                严格路由: false,
                网络栈: "gvisor",
                DNS地址: "10.0.0.2",
                启用嗅探: true
            ),
            // Mixed 入站（HTTP+SOCKS5，用于本地应用）
            SingBox入站配置.mixed入站(
                标签: "mixed-in",
                地址: "127.0.0.1",
                端口: 7890
            )
            // 注意：libbox v1.11.0 不支持 api 入站类型，暂不启用
            // API 入站用于查询连接列表，待 libbox 升级后启用
        ]
    }

    // MARK: - 生成出站配置

    /// 生成出站配置
    private func 生成出站配置(节点: 节点模型?, 节点列表: [节点模型]) -> [SingBox出站配置] {
        var 出站列表: [SingBox出站配置] = []

        // 当前节点出站
        if let 节点 = 节点 {
            if let 节点出站 = 节点转换为出站(节点, 标签: "proxy") {
                出站列表.append(节点出站)
            }
        }

        // 所有节点出站（用于 urltest/selector）
        // tag 使用节点真实名称，重名时自动加 _2、_3 后缀
        var 节点标签列表: [String] = []
        var 名称计数: [String: Int] = [:]
        for 节点 in 节点列表 {
            var 标签 = 节点.名称
            if let 已有计数 = 名称计数[节点.名称] {
                名称计数[节点.名称] = 已有计数 + 1
                标签 = "\(节点.名称)_\(已有计数 + 1)"
            } else {
                名称计数[节点.名称] = 1
            }
            if let 节点出站 = 节点转换为出站(节点, 标签: 标签) {
                出站列表.append(节点出站)
                节点标签列表.append(标签)
            }
        }

        // URLTest 出站（自动选择最快节点）
        if !节点标签列表.isEmpty {
            出站列表.append(SingBox出站配置.urlTest出站(
                标签: "urltest",
                出站列表: 节点标签列表,
                测试URL: "http://www.gstatic.com/generate_204",
                间隔: "5m"
            ))
        }

        // Selector 出站（手动选择节点）
        if !节点标签列表.isEmpty {
            var 选择器列表 = 节点标签列表
            if 节点 != nil {
                选择器列表.insert("proxy", at: 0)
            }
            出站列表.append(SingBox出站配置.selector出站(
                标签: "selector",
                出站列表: 选择器列表
            ))
        }

        // Direct 出站（标签大写参考官方客户端）
        // 动态检测当前活动物理网卡并绑定，避免直连流量回环到 TUN 导致 connection refused
        let 活动接口 = 检测当前活动物理网卡()
        NSLog("[SingBox配置] DIRECT 出站绑定物理网卡：%@", 活动接口)
        出站列表.append(SingBox出站配置.direct出站(标签: "DIRECT", 绑定接口: 活动接口))

        // Block 出站
        出站列表.append(SingBox出站配置.block出站(标签: "REJECT"))

        return 出站列表
    }

    /// 将节点模型转换为 sing-box 出站配置
    func 节点转换为出站(_ 节点: 节点模型, 标签: String) -> SingBox出站配置? {
        switch 节点.协议 {
        case .vless:
            return 生成VLESS出站(节点, 标签: 标签)
        case .vmess:
            return 生成VMess出站(节点, 标签: 标签)
        case .trojan:
            return 生成Trojan出站(节点, 标签: 标签)
        case .shadowsocks:
            return 生成Shadowsocks出站(节点, 标签: 标签)
        }
    }

    /// 生成 TLS 配置
    private func 生成TLS配置(_ 节点: 节点模型) -> SingBoxTLS配置? {
        guard 节点.启用TLS else { return nil }
        return SingBoxTLS配置.标准TLS(
            SNI: 节点.服务器名称 ?? 节点.地址,
            跳过验证: false
        )
    }

    /// 生成传输配置
    private func 生成传输配置(_ 节点: 节点模型) -> SingBox传输配置? {
        switch 节点.传输类型 {
        case .ws:
            let 路径 = 节点.ws路径 ?? "/"
            // Host 头回退链：ws主机 → 服务器名称(SNI) → 节点地址
            // 确保 WebSocket 握手时 Host 头始终有值，避免服务端因 Host 缺失而拒绝连接
            let 主机 = 节点.ws主机 ?? 节点.服务器名称 ?? 节点.地址
            return SingBox传输配置.ws传输(路径: 路径, 主机: 主机)
        case .grpc:
            return SingBox传输配置.grpc传输(服务名: "GunService")
        case .quic:
            return nil
        case .tcp:
            return nil
        }
    }

    /// 生成 VLESS 出站
    private func 生成VLESS出站(_ 节点: 节点模型, 标签: String) -> SingBox出站配置 {
        // libbox v1.11.0 不识别 dialer_options 字段，会导致配置解析失败
        // TCP keep-alive 由系统默认处理
        var 配置 = SingBox出站配置.vless出站(
            标签: 标签,
            服务器: 节点.地址,
            端口: 节点.端口,
            UUID: 节点.用户标识 ?? "",
            流控: nil,
            加密: "none",
            TLS: 生成TLS配置(节点),
            传输: 生成传输配置(节点)
        )
        // 出站顶层字段设置 TCP 快速打开（libbox v1.11.0 支持）
        配置.tcpFastOpen = true
        return 配置
    }

    /// 生成 VMess 出站
    private func 生成VMess出站(_ 节点: 节点模型, 标签: String) -> SingBox出站配置 {
        var 配置 = SingBox出站配置.vmess出站(
            标签: 标签,
            服务器: 节点.地址,
            端口: 节点.端口,
            UUID: 节点.用户标识 ?? "",
            加密: "auto",
            TLS: 生成TLS配置(节点),
            传输: 生成传输配置(节点)
        )
        配置.tcpFastOpen = true
        return 配置
    }

    /// 生成 Trojan 出站
    private func 生成Trojan出站(_ 节点: 节点模型, 标签: String) -> SingBox出站配置 {
        var 配置 = SingBox出站配置.trojan出站(
            标签: 标签,
            服务器: 节点.地址,
            端口: 节点.端口,
            密码: 节点.用户标识 ?? "",
            TLS: 生成TLS配置(节点),
            传输: 生成传输配置(节点)
        )
        配置.tcpFastOpen = true
        return 配置
    }

    /// 生成 Shadowsocks 出站
    private func 生成Shadowsocks出站(_ 节点: 节点模型, 标签: String) -> SingBox出站配置 {
        var 配置 = SingBox出站配置.shadowsocks出站(
            标签: 标签,
            服务器: 节点.地址,
            端口: 节点.端口,
            方法: "aes-256-gcm",
            密码: 节点.用户标识 ?? ""
        )
        配置.tcpFastOpen = true
        return 配置
    }

    // MARK: - 生成路由配置（兼容当前 libbox 版本）

    /// 生成路由配置
    /// - Parameters:
    ///   - 分流规则: 用户自定义分流规则
    ///   - 节点: 当前节点（用于代理服务器 IP 直连）
    ///   - 运行模式: 隧道运行模式，决定最终出站
    private func 生成路由配置(分流规则: [分流规则项], 节点: 节点模型?, 运行模式: 隧道运行模式) -> SingBox路由配置 {
        var 规则列表: [SingBox路由规则] = []

        // 私有 IP 直连
        规则列表.append(SingBox路由规则(
            ipIsPrivate: true,
            outbound: "DIRECT"
        ))

        // 局域网地址直连
        规则列表.append(SingBox路由规则(
            ipCidr: [
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16",
                "127.0.0.0/8",
                "169.254.0.0/16",
                "224.0.0.0/4",
                "255.255.255.255/32"
            ],
            outbound: "DIRECT"
        ))

        // DNS 服务器 IP 直连（避免 DNS 查询走代理导致回环）
        规则列表.append(SingBox路由规则(
            ipCidr: ["223.5.5.5/32", "8.8.8.8/32", "1.1.1.1/32"],
            outbound: "DIRECT"
        ))

        // 关键修复：代理服务器地址直连，避免代理流量自身被路由到代理导致回环
        // 无论运行模式如何，到代理服务器的连接必须直接发出
        if let 节点地址 = 节点?.地址, !节点地址.isEmpty {
            let 是否IP地址 = 节点地址.allSatisfy({ $0.isNumber || $0 == "." })
            if 是否IP地址 {
                规则列表.append(SingBox路由规则(
                    ipCidr: ["\(节点地址)/32"],
                    outbound: "DIRECT"
                ))
            } else {
                规则列表.append(SingBox路由规则(
                    domain: [节点地址],
                    outbound: "DIRECT"
                ))
            }
        }

        // 应用分流规则（仅在规则分流模式下生效）
        if 运行模式 == .规则分流 {
            for 规则 in 分流规则 where 规则.启用 {
                if let 路由规则 = 分流规则转换为路由规则(规则) {
                    规则列表.append(路由规则)
                }
            }
        }

        // 根据运行模式决定最终出站
        // 全局直连：所有未匹配流量直接连接
        // 规则分流/全局代理：所有未匹配流量走代理
        let 最终出站: String
        switch 运行模式 {
        case .全局直连:
            最终出站 = "DIRECT"
        case .规则分流, .全局代理:
            最终出站 = "proxy"
        }

        return SingBox路由配置(
            final: 最终出站,
            // 关闭 auto_detect_interface：iOS libbox 的 getInterfaces 返回对象属性不匹配导致 "no available network interface"
            // 改用 DIRECT 出站的 bind_interface 直接绑定物理网卡
            autoDetectInterface: false,
            rules: 规则列表
        )
    }

    /// 将分流规则转换为 sing-box 路由规则
    private func 分流规则转换为路由规则(_ 规则: 分流规则项) -> SingBox路由规则? {
        let 出站标签: String
        switch 规则.动作 {
        case .直连: 出站标签 = "DIRECT"
        case .代理: 出站标签 = "proxy"
        case .拦截, .拒绝: 出站标签 = "REJECT"
        case .全局代理: 出站标签 = "proxy"
        case .放行: return nil // 放行不生成规则
        }

        var 路由规则 = SingBox路由规则(outbound: 出站标签)

        switch 规则.类型 {
        case .域名精确:
            路由规则.domain = [规则.匹配值]
        case .域名后缀:
            路由规则.domainSuffix = [规则.匹配值]
        case .域名关键词:
            路由规则.domainKeyword = [规则.匹配值]
        case .正则表达式:
            路由规则.domainRegex = [规则.匹配值]
        case .IP地址:
            路由规则.ipCidr = ["\(规则.匹配值)/32"]
        case .IP段:
            路由规则.ipCidr = [规则.匹配值]
        case .端口:
            if let 端口 = Int(规则.匹配值) {
                路由规则.port = [端口]
            }
        case .端口范围:
            路由规则.portRange = [规则.匹配值]
        case .协议:
            路由规则.protocol_ = [规则.匹配值.lowercased()]
        case .进程名称:
            路由规则.processName = [规则.匹配值]
        case .用户代理:
            // sing-box 不直接支持 UA 匹配，跳过
            return nil
        case .地理区域:
            // 地理区域需要规则集，跳过
            return nil
        case .全部:
            // 全部匹配，不设置条件
            break
        }

        return 路由规则
    }

    // MARK: - 物理网卡检测

    /// 检测当前活动的物理网卡接口名（WiFi=en0 / 蜂窝=pdp_ip0）
    /// 用于 DIRECT 出站的 bind_interface，避免硬编码 en0 导致蜂窝用户 connection refused
    /// - Returns: 接口名，检测失败返回 "en0"
    private func 检测当前活动物理网卡() -> String {
        var 接口指针: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&接口指针) == 0, let 首接口 = 接口指针 else {
            return "en0"
        }
        defer { freeifaddrs(接口指针) }

        var WiFi接口: String?
        var 蜂窝接口: String?
        var 当前 = 首接口
        while true {
            let 接口名 = String(cString: 当前.pointee.ifa_name)
            let 标志 = 当前.pointee.ifa_flags
            // 只处理已启用的接口
            if (标志 & UInt32(IFF_UP)) != 0,
               // 只处理 IPv4 地址
               当前.pointee.ifa_addr.pointee.sa_family == AF_INET,
               // 跳过回环和隧道接口
               接口名 != "lo0",
               !接口名.hasPrefix("utun"),
               !接口名.hasPrefix("ipsec") {
                // 优先 WiFi（en开头），其次蜂窝（pdp_ip开头）
                if 接口名.hasPrefix("en") && WiFi接口 == nil {
                    WiFi接口 = 接口名
                } else if (接口名.hasPrefix("pdp_ip") || 接口名.hasPrefix("cell")) && 蜂窝接口 == nil {
                    蜂窝接口 = 接口名
                }
            }
            guard let 下一个 = 当前.pointee.ifa_next else { break }
            当前 = 下一个
        }

        // 优先 WiFi，其次蜂窝，最后默认 en0
        return WiFi接口 ?? 蜂窝接口 ?? "en0"
    }

    // MARK: - 配置验证

    /// 验证 sing-box 配置
    func 验证配置(_ 配置: SingBox配置) -> (有效: Bool, 错误: [String]) {
        var 错误列表: [String] = []

        // 检查入站
        if 配置.inbounds?.isEmpty ?? true {
            错误列表.append("至少需要一个入站配置")
        }

        // 检查出站
        if 配置.outbounds?.isEmpty ?? true {
            错误列表.append("至少需要一个出站配置")
        }

        // 检查是否有 proxy 出站
        if let 出站列表 = 配置.outbounds,
           !出站列表.contains(where: { $0.tag == "proxy" }) {
            错误列表.append("缺少标签为 proxy 的出站配置")
        }

        // 检查是否有 DIRECT 出站
        if let 出站列表 = 配置.outbounds,
           !出站列表.contains(where: { $0.tag == "DIRECT" }) {
            错误列表.append("缺少标签为 DIRECT 的出站配置")
        }

        // 检查路由最终出站
        if let 路由 = 配置.route, let 最终 = 路由.final {
            if let 出站列表 = 配置.outbounds,
               !出站列表.contains(where: { $0.tag == 最终 }) {
                错误列表.append("路由最终出站 \(最终) 不存在")
            }
        }

        return (错误列表.isEmpty, 错误列表)
    }

    // MARK: - 配置保存和加载

    /// 保存配置到文件
    func 保存配置(_ 配置: SingBox配置, 到路径: String) -> Bool {
        guard let JSON字符串 = 配置.转换为JSON字符串(格式化: true) else { return false }

        do {
            try JSON字符串.write(toFile: 到路径, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// 从文件加载配置
    func 从文件加载配置(_ 路径: String) -> SingBox配置? {
        guard let 数据 = FileManager.default.contents(atPath: 路径) else { return nil }
        return SingBox配置.从JSON数据(数据)
    }

    /// 获取共享配置路径
    var 共享配置路径: String? {
        guard let 容器URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: 隧道常量.AppGroupID) else {
            return nil
        }
        return 容器URL.appendingPathComponent("singbox_config.json").path
    }
}
