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
    ///   - 日志级别: 日志级别
    /// - Returns: sing-box 配置
    func 生成配置(节点: 节点模型?,
                  节点列表: [节点模型] = [],
                  分流规则: [分流规则项] = [],
                  DNS配置: DNS配置模型? = nil,
                  日志级别: String = "info") -> SingBox配置 {
        var 配置 = SingBox配置()

        // 日志配置
        配置.log = SingBox日志配置(
            level: 日志级别,
            timestamp: true
        )

        // DNS 配置
        配置.dns = 生成DNS配置(DNS配置)

        // 入站配置
        配置.inbounds = 生成入站配置()

        // 出站配置
        配置.outbounds = 生成出站配置(节点: 节点, 节点列表: 节点列表)

        // 路由配置
        配置.route = 生成路由配置(分流规则: 分流规则, 节点: 节点)

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

    // MARK: - 生成 DNS 配置

    /// 生成 DNS 配置
    private func 生成DNS配置(_ DNS配置: DNS配置模型?) -> SingBoxDNS配置 {
        var 服务器列表: [SingBoxDNS服务器] = []

        if let 配置 = DNS配置, 配置.启用自定义DNS {
            for (索引, 服务器) in 配置.启用服务器.enumerated() {
                let 标签 = "dns-\(索引)"
                let 地址: String

                switch 服务器.类型 {
                case .doh:
                    地址 = 服务器.地址.hasPrefix("https://") ? 服务器.地址 : "https://\(服务器.地址)/dns-query"
                case .dot:
                    地址 = "tls://\(服务器.地址)"
                case .tcp:
                    地址 = "tcp://\(服务器.地址):\(服务器.端口)"
                case .udp:
                    地址 = "\(服务器.地址):\(服务器.端口)"
                }

                服务器列表.append(SingBoxDNS服务器(
                    tag: 标签,
                    address: 地址,
                    detour: "proxy"
                ))
            }
        }

        // 默认 DNS 服务器
        // TUN 入站 dns_address 直接拦截 DNS 查询交给 DNS 模块
        // detour=proxy 让上游 DNS 查询通过代理出站发送
        if 服务器列表.isEmpty {
            服务器列表 = [
                SingBoxDNS服务器(tag: "dns-google", address: "8.8.8.8", detour: "proxy"),
                SingBoxDNS服务器(tag: "dns-cloudflare", address: "1.1.1.1", detour: "proxy")
            ]
        }

        return SingBoxDNS配置(
            servers: 服务器列表,
            final: 服务器列表.first?.tag ?? "dns-google",
            strategy: "ipv4_only",
            disableCache: false
        )
    }

    // MARK: - 生成入站配置

    /// 生成入站配置
    private func 生成入站配置() -> [SingBox入站配置] {
        [
            // TUN 入站（iOS 隧道使用）
            // 注意：Network Extension 中必须用 gvisor 栈，system 栈需要 root 权限
            // auto_route/strict_route 由系统 NEPacketTunnelNetworkSettings 控制，不需 sing-box 管理
            SingBox入站配置.tun入站(
                标签: "tun-in",
                地址: "10.0.0.2/24",
                MTU: 4064,
                自动路由: false,
                严格路由: false,
                网络栈: "gvisor",
                DNS地址: "10.0.0.2"
            ),
            // Mixed 入站（HTTP+SOCKS5，用于本地应用）
            SingBox入站配置.mixed入站(
                标签: "mixed-in",
                地址: "127.0.0.1",
                端口: 7890
            )
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
        var 节点标签列表: [String] = []
        for (索引, 节点) in 节点列表.enumerated() {
            let 标签 = "node-\(索引)"
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

        // Direct 出站
        出站列表.append(SingBox出站配置.direct出站(标签: "direct"))

        // Block 出站
        出站列表.append(SingBox出站配置.block出站(标签: "block"))

        // 注意：不再需要 dns-out 出站，TUN 入站的 dns_address 直接拦截 DNS 查询交给 DNS 模块

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
            return SingBox传输配置.ws传输(路径: "/", 主机: 节点.服务器名称)
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
        SingBox出站配置.vless出站(
            标签: 标签,
            服务器: 节点.地址,
            端口: 节点.端口,
            UUID: 节点.用户标识 ?? "",
            流控: nil,
            加密: "none",
            TLS: 生成TLS配置(节点),
            传输: 生成传输配置(节点)
        )
    }

    /// 生成 VMess 出站
    private func 生成VMess出站(_ 节点: 节点模型, 标签: String) -> SingBox出站配置 {
        SingBox出站配置.vmess出站(
            标签: 标签,
            服务器: 节点.地址,
            端口: 节点.端口,
            UUID: 节点.用户标识 ?? "",
            加密: "auto",
            TLS: 生成TLS配置(节点),
            传输: 生成传输配置(节点)
        )
    }

    /// 生成 Trojan 出站
    private func 生成Trojan出站(_ 节点: 节点模型, 标签: String) -> SingBox出站配置 {
        SingBox出站配置.trojan出站(
            标签: 标签,
            服务器: 节点.地址,
            端口: 节点.端口,
            密码: 节点.用户标识 ?? "",
            TLS: 生成TLS配置(节点),
            传输: 生成传输配置(节点)
        )
    }

    /// 生成 Shadowsocks 出站
    private func 生成Shadowsocks出站(_ 节点: 节点模型, 标签: String) -> SingBox出站配置 {
        SingBox出站配置.shadowsocks出站(
            标签: 标签,
            服务器: 节点.地址,
            端口: 节点.端口,
            方法: "aes-256-gcm",
            密码: 节点.用户标识 ?? ""
        )
    }

    // MARK: - 生成路由配置

    /// 生成路由配置
    private func 生成路由配置(分流规则: [分流规则项], 节点: 节点模型?) -> SingBox路由配置 {
        var 规则列表: [SingBox路由规则] = []

        // 注意：DNS 查询由 TUN 入站的 dns_address 直接拦截交给 DNS 模块
        // 不再需要 protocol=dns → dns-out 路由规则，从根源避免 DNS 回环

        // 私有 IP 直连
        规则列表.append(SingBox路由规则(
            ipIsPrivate: true,
            outbound: "direct"
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
            outbound: "direct"
        ))

        // 应用分流规则
        for 规则 in 分流规则 where 规则.启用 {
            if let 路由规则 = 分流规则转换为路由规则(规则) {
                规则列表.append(路由规则)
            }
        }

        return SingBox路由配置(
            final: "proxy",
            autoDetectInterface: true,
            rules: 规则列表
        )
    }

    /// 将分流规则转换为 sing-box 路由规则
    private func 分流规则转换为路由规则(_ 规则: 分流规则项) -> SingBox路由规则? {
        let 出站标签: String
        switch 规则.动作 {
        case .直连: 出站标签 = "direct"
        case .代理: 出站标签 = "proxy"
        case .拦截, .拒绝: 出站标签 = "block"
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

        // 检查是否有 direct 出站
        if let 出站列表 = 配置.outbounds,
           !出站列表.contains(where: { $0.tag == "direct" }) {
            错误列表.append("缺少标签为 direct 的出站配置")
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
