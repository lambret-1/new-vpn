//
//  PacketTunnelProvider.swift
//  NewVPN-Tunnel
//
//  PacketTunnel 扩展入口：管理隧道生命周期、网络配置、流量统计
//  预留 sing-box 内核集成接口
//

import NetworkExtension
import Network
import os

// MARK: - 隧道提供者

/// VPN 隧道提供者：负责启动、停止隧道，管理网络配置和流量
class PacketTunnelProvider: NEPacketTunnelProvider {
    // MARK: - 属性

    /// 日志记录器
    private let 日志 = Logger(subsystem: "com.newvpn.app.tunnel", category: "隧道")

    /// 隧道版本
    private let 隧道版本 = "1.0.0"

    /// 上行字节数
    private var 上行字节: UInt64 = 0
    /// 下行字节数
    private var 下行字节: UInt64 = 0

    /// 统计更新定时器
    private var 统计定时器: Timer?

    /// 隧道配置
    private var 隧道配置: [String: Any] = [:]

    /// 节点 ID
    private var 节点ID: String?

    /// 节点名称
    private var 节点名称: String?

    /// 是否正在运行
    private var 是否运行中 = false

    /// DNS 查询开始时间追踪（域名: 开始时间），用于计算响应耗时
    /// 注意：sing-box 日志回调在 Go 运行时的多个并发线程上触发，访问此字典必须经过 扩展数据队列 串行化
    private var DNS查询开始时间: [String: Date] = [:]

    /// sing-box 内核是否运行中
    private var singBox运行中 = false

    /// operation not permitted 错误降噪：上次汇总输出时间
    private var 上次Packet权限错误汇总时间: Date?
    /// operation not permitted 错误计数（降噪周期内）
    private var Packet权限错误计数 = 0

    /// 扩展内共享可变状态的串行队列
    /// sing-box 日志回调会在多个 Go 线程并发回调，同时主线程 Timer 也会清理 DNS 记录，
    /// 无锁并发读写字典/UserDefaults 数组会触发 Swift 独占检查崩溃或堆损坏（对应 commit eb043b4 提到的数据竞争）
    private let 扩展数据队列 = DispatchQueue(label: "com.newvpn.app.tunnel.sharedstate", qos: .utility)

    /// sing-box 内核桥接
    private let singBox桥接 = SingBox内核桥接.共享

    /// 热更新轮询定时器
    private var 热更新定时器: Timer?

    /// 心跳检测定时器
    private var 心跳定时器: Timer?
    /// 心跳连续失败次数
    private var 心跳失败次数 = 0
    /// 自动重连次数
    private var 重连次数 = 0
    /// 重连定时器
    private var 重连定时器: Timer?
    /// 是否正在重连中
    private var 正在重连 = false

    /// 本地抓包代理
    private var 本地抓包代理: 本地HTTP代理?

    /// sing-box 配置文件路径
    private var singBox配置路径: String? {
        guard let 容器URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.newvpn.app") else {
            return nil
        }
        return 容器URL.appendingPathComponent("singbox_config.json").path
    }

    /// 共享 UserDefaults
    private var 共享默认: UserDefaults? {
        UserDefaults(suiteName: "group.com.newvpn.app")
    }

    /// APP 是否在后台（用于低功耗模式）
    private var APP在后台: Bool {
        共享默认?.bool(forKey: "appInBackground") ?? false
    }

    // MARK: - 隧道生命周期

    /// 隧道启动完成回调
    override func startTunnel(options: [String: NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        日志.info("隧道开始启动")
        记录扩展日志(级别: "信息", 模块: "隧道", 内容: "扩展开始启动，进程已唤醒")

        // 解析启动选项
        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "开始解析启动选项")
        if let 选项 = options {
            节点ID = 选项["nodeId"] as? String
            节点名称 = 选项["nodeName"] as? String
            记录扩展日志(级别: "调试", 模块: "隧道", 内容: "启动选项解析完成，节点ID=\(节点ID ?? "空")，节点名=\(节点名称 ?? "空")")
        } else {
            记录扩展日志(级别: "调试", 模块: "隧道", 内容: "无启动选项")
        }

        // 如果节点名称为空，尝试从 sing-box 配置文件解析
        if 节点名称 == nil || 节点名称?.isEmpty == true {
            记录扩展日志(级别: "调试", 模块: "隧道", 内容: "节点名为空，尝试从配置文件解析")
            if let 配置路径 = singBox配置路径 {
                记录扩展日志(级别: "调试", 模块: "隧道", 内容: "配置路径=\(配置路径)")
                if let 配置数据 = try? Data(contentsOf: URL(fileURLWithPath: 配置路径)) {
                    记录扩展日志(级别: "调试", 模块: "隧道", 内容: "配置数据读取成功，大小=\(配置数据.count)")
                    if let 配置JSON = try? JSONSerialization.jsonObject(with: 配置数据) as? [String: Any] {
                        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "JSON解析成功")
                        if let 出站列表 = 配置JSON["outbounds"] as? [[String: Any]] {
                            记录扩展日志(级别: "调试", 模块: "隧道", 内容: "出站列表数量=\(出站列表.count)")
                            if let 第一个出站 = 出站列表.first,
                               let 标签 = 第一个出站["tag"] as? String {
                                节点名称 = 标签
                                记录扩展日志(级别: "调试", 模块: "隧道", 内容: "从配置解析到节点名=\(标签)")
                            }
                        }
                    }
                }
            } else {
                记录扩展日志(级别: "警告", 模块: "隧道", 内容: "配置路径为空")
            }
        }

        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "准备计算显示节点名，节点名=\(节点名称 ?? "nil")")

        let 显示节点名 = 节点名称?.isEmpty == false ? 节点名称! : "未指定"
        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "显示节点名计算完成=\(显示节点名)")

        日志.info("节点：\(显示节点名)")
        记录扩展日志(级别: "信息", 模块: "隧道", 内容: "启动节点：\(显示节点名)")

        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "开始加载隧道配置")

        // 加载配置
        加载隧道配置()

        // 设置网络配置
        设置网络配置 { [weak self] 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                self.日志.error("网络配置设置失败：\(错误.localizedDescription)")
                completionHandler(错误)
                return
            }

            // 启动 sing-box 内核
            self.启动SingBox内核 { 内核启动成功 in
                if 内核启动成功 {
                    self.日志.info("sing-box 内核启动成功，由内核直接处理数据包")
                    self.singBox运行中 = true

                    // 检查抓包或 MITM 是否启用，启用则启动本地 HTTP 代理
                    let 共享默认 = UserDefaults(suiteName: "group.com.newvpn.app")
                    let 抓包启用 = 共享默认?.bool(forKey: "httpCaptureEnabled") ?? false
                    let MITM启用 = 共享默认?.bool(forKey: "mitmEnabled") ?? false
                    if 抓包启用 || MITM启用 {
                        // MITM 启用时加载 CA 证书到签发器
                        if MITM启用 {
                            let 证书PEM = 共享默认?.string(forKey: "mitmCACertificate") ?? ""
                            let 私钥PEM = 共享默认?.string(forKey: "mitmCAPrivateKey") ?? ""
                            if !证书PEM.isEmpty && !私钥PEM.isEmpty {
                                let 加载成功 = MITM证书签发器.共享.加载CA证书(证书PEM: 证书PEM, 私钥PEM: 私钥PEM)
                                if 加载成功 {
                                    self.记录扩展日志(级别: "信息", 模块: "MITM", 内容: "MITM CA证书和私钥加载成功，本地代理启动 127.0.0.1:8888")
                                } else {
                                    self.记录扩展日志(级别: "错误", 模块: "MITM", 内容: "MITM CA证书或私钥加载失败，TLS解密功能不可用")
                                }
                            } else {
                                self.记录扩展日志(级别: "错误", 模块: "MITM", 内容: "MITM CA证书为空，解密功能不可用")
                            }
                        }
                        if 抓包启用 {
                            self.记录扩展日志(级别: "信息", 模块: "抓包", 内容: "HTTP抓包已启用，本地代理启动 127.0.0.1:8888")
                        }
                        本地HTTP代理.共享.启动()
                    }
                } else {
                    self.日志.error("sing-box 内核启动失败，使用基础数据包处理")
                    // 仅在内核启动失败时才启动基础数据包读取循环
                    self.启动数据包处理()
                }

                // 启动统计定时器
                self.启动统计定时器()

                // 启动热更新轮询定时器
                self.启动热更新定时器()

                // 启动心跳检测定时器
                self.启动心跳定时器()

                // 重置重连计数
                self.重连次数 = 0
                self.心跳失败次数 = 0

                // 标记运行中
                self.是否运行中 = true

                // 记录启动日志
                self.记录扩展日志(级别: "信息", 模块: "隧道", 内容: "隧道启动成功，节点：\(self.节点名称 ?? "未知")，sing-box内核：\(内核启动成功 ? "已启用" : "未启用")")

                self.日志.info("隧道启动成功")
                completionHandler(nil)
            }
        }
    }

    /// 隧道停止完成回调
    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        日志.info("隧道开始停止，原因：\(reason.rawValue)")

        // 停止 sing-box 内核
        停止SingBox内核()

        // 停止本地 HTTP 抓包代理
        本地HTTP代理.共享.停止()

        // 停止数据包处理
        停止数据包处理()

        // 停止统计定时器
        停止统计定时器()

        // 停止热更新定时器
        停止热更新定时器()

        // 停止心跳定时器
        停止心跳定时器()

        // 停止重连定时器
        重连定时器?.invalidate()
        重连定时器 = nil
        正在重连 = false

        // 保存最终统计
        保存统计数据()

        // 记录停止日志
        记录扩展日志(级别: "信息", 模块: "隧道", 内容: "隧道已停止，原因：\(停止原因描述(reason))")

        // 标记停止
        是否运行中 = false

        日志.info("隧道停止完成")
        completionHandler()
    }

    /// 处理来自主 App 的消息
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        do {
            if let 消息 = try JSONSerialization.jsonObject(with: messageData) as? [String: Any],
               let 动作 = 消息["action"] as? String {

                日志.debug("收到主 App 消息：\(动作)")

                switch 动作 {
                case "getVersion":
                    let 响应 = ["version": 隧道版本]
                    completionHandler?(try JSONSerialization.data(withJSONObject: 响应))

                case "getStats":
                    let 响应: [String: Any] = [
                        "uploadBytes": 上行字节,
                        "downloadBytes": 下行字节,
                        "running": 是否运行中
                    ]
                    completionHandler?(try JSONSerialization.data(withJSONObject: 响应))

                case "reloadConfig":
                    加载隧道配置()
                    设置网络配置 { _ in }
                    重载SingBox配置()
                    let 响应 = ["success": true]
                    completionHandler?(try JSONSerialization.data(withJSONObject: 响应))

                case "getLogs":
                    let 日志列表 = 读取扩展日志()
                    if let 数据 = try? JSONSerialization.data(withJSONObject: 日志列表) {
                        completionHandler?(数据)
                    } else {
                        completionHandler?(nil)
                    }

                case "testLatency":
                    // 在扩展进程内做 TCP 连接测速：扩展自身出站绕过本 TUN，
                    // 测到的是到远端服务器的真实 RTT（App 进程测会被 TUN 截获，虚高为 ~5ms）
                    guard let 地址 = 消息["address"] as? String,
                          let 端口 = 消息["port"] as? Int else {
                        let 响应 = ["error": "缺少 address/port"]
                        completionHandler?(try? JSONSerialization.data(withJSONObject: 响应))
                        return
                    }
                    记录扩展日志(级别: "信息", 模块: "测速", 内容: "开始测试 \(地址):\(端口)")
                    测试TCP延迟(地址: 地址, 端口: 端口) { 延迟ms in
                        var 响应: [String: Any] = [:]
                        if let ms = 延迟ms {
                            响应["latency"] = ms
                            self.记录扩展日志(级别: "信息", 模块: "测速", 内容: "\(地址):\(端口) = \(ms)ms")
                        } else {
                            响应["error"] = "timeout"
                            self.记录扩展日志(级别: "错误", 模块: "测速", 内容: "\(地址):\(端口) 连接失败")
                        }
                        completionHandler?(try? JSONSerialization.data(withJSONObject: 响应))
                    }

                default:
                    let 响应 = ["error": "未知动作"]
                    completionHandler?(try JSONSerialization.data(withJSONObject: 响应))
                }
            }
        } catch {
            日志.error("处理消息失败：\(error.localizedDescription)")
            completionHandler?(nil)
        }
    }

    // MARK: - 节点测速（扩展进程内，绕过自身 TUN）

    /// 在扩展进程内对 地址:端口 做一次 TCP 连接，返回真实 RTT(ms)，失败返回 nil
    ///
    /// 为什么不能用裸 NWConnection：本隧道 includeAllNetworks=YES（全局 0.0.0.0/0 进 TUN），
    /// 扩展进程里未绑定出接口的 socket 会被路由进 TUN；而扩展进程的 socket 又带“绕过 VPN”
    /// 标记，导致 TUN 接口回包无法匹配回原 socket，连接必然超时（这就是上一版全部测不出的原因）。
    /// 因此这里用 SO_BINDTODEVICE 把探测 socket 钉在物理网卡（en0 / pdp_ip0）上，
    /// 让 SYN 从物理网卡直连节点服务器、SYN-ACK 从物理网卡回来，测到真实 RTT。
    private func 测试TCP延迟(地址: String, 端口: Int, 完成: @escaping (Int?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 完成(nil); return }
            let ms = self.物理接口TCP连接RTT(地址: 地址, 端口: 端口, 超时: 5.0)
            完成(ms)
        }
    }

    /// 绑定物理出接口、带超时地连接 地址:端口，成功返回握手 RTT(ms)，失败返回 nil
    private func 物理接口TCP连接RTT(地址: String, 端口: Int, 超时: TimeInterval) -> Int? {
        // 1. 解析目标地址（域名或 IP 字面量）为内核地址结构
        var 提示 = addrinfo()
        提示.ai_family = AF_INET
        提示.ai_socktype = SOCK_STREAM
        var 链表: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(地址, String(端口), &提示, &链表) == 0,
              let 首节点 = 链表?.pointee,
              let 目标地址 = 首节点.ai_addr else {
            if let 链表 = 链表 { freeaddrinfo(链表) }
            return nil
        }
        defer { if let 链表 = 链表 { freeaddrinfo(链表) } }

        // 2. 创建 TCP socket
        let fd = socket(首节点.ai_family, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var 已关闭 = false
        func 关闭fd() { if !已关闭 { close(fd); 已关闭 = true } }
        defer { 关闭fd() }

        // 3. 关键：把 socket 钉到物理出接口，绕过本 TUN
        // SO_BINDTODEVICE 在 iOS SDK 中 Swift 桥接未导出该符号，其数值为 25
        guard let 接口名 = 首个物理接口名() else { return nil }
        接口名.withCString { 名 in
            setsockopt(fd, SOL_SOCKET, 25, 名, socklen_t(strlen(名)))
        }

        // 4. 设为非阻塞
        let 旧标志 = fcntl(fd, F_GETFL, 0)
        guard 旧标志 >= 0 else { return nil }
        _ = fcntl(fd, F_SETFL, 旧标志 | O_NONBLOCK)

        // 5. 发起连接（非阻塞下会立即返回 EINPROGRESS）
        let 开始 = Date()
        if connect(fd, 目标地址, 首节点.ai_addrlen) < 0 && errno != EINPROGRESS {
            return nil
        }

        // 6. 用 DispatchSource 等待连接完成，另起一个超时兜底
        let 信号 = DispatchSemaphore(value: 0)
        var 最终错误 = 0
        var 已完成 = false

        let 写源 = DispatchSource.makeWriteSource(fileDescriptor: fd, queue: .global())
        写源.setEventHandler {
            var 错误码 = 0
            var 长度 = socklen_t(MemoryLayout<Int>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &错误码, &长度)
            最终错误 = 错误码
            已完成 = true
            写源.cancel()
            信号.signal()
        }
        写源.resume()

        DispatchQueue.global().asyncAfter(deadline: .now() + 超时) {
            if !已完成 { 最终错误 = Int(ETIMEDOUT) }
            信号.signal()
        }

        信号.wait()
        写源.cancel()
        if 最终错误 != 0 { return nil }

        return Int(Date().timeIntervalSince(开始) * 1000)
    }

    /// 枚举本机接口，返回第一个可用物理出接口名（跳过回环与隧道接口）
    private func 首个物理接口名() -> String? {
        var 链表: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&链表) == 0, let 起始 = 链表 else { return nil }
        defer { freeifaddrs(起始) }
        var 当前: UnsafeMutablePointer<ifaddrs>? = 起始
        while let 节点 = 当前 {
            let 项 = 节点.pointee
            if let 名指针 = 项.ifa_name {
                let 名称 = String(cString: 名指针)
                let 跳过 = 名称.hasPrefix("lo") || 名称.hasPrefix("utun")
                    || 名称.hasPrefix("ipsec") || 名称.hasPrefix("tap")
                    || 名称.hasPrefix("bridge")
                if !跳过, 项.ifa_addr != nil {
                    return 名称
                }
            }
            当前 = 项.ifa_next
        }
        return nil
    }

    // MARK: - 网络配置

    /// 设置网络配置
    private func 设置网络配置(完成: @escaping (Error?) -> Void) {
        let 设置 = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")

        // IPv4 设置
        let IPv4设置 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        IPv4设置.includedRoutes = [NEIPv4Route.default()]

        // 排除路由：私有地址 + 代理服务器地址 + DNS 服务器地址
        // 排除这些地址后，它们的流量直接走物理网卡，不会被 TUN 捕获，避免回环
        var 排除路由: [NEIPv4Route] = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),
            // DNS 服务器地址直连，避免 DNS 查询走 TUN 回环
            NEIPv4Route(destinationAddress: "223.5.5.5", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.8.8", subnetMask: "255.255.255.255")
        ]

        // 代理服务器地址直连（如果是 IP 地址）
        if let 代理配置 = 隧道配置["proxy"] as? [String: Any],
           let 代理服务器 = 代理配置["server"] as? String,
           !代理服务器.isEmpty {
            let 是否IP = 代理服务器.allSatisfy({ $0.isNumber || $0 == "." })
            if 是否IP {
                排除路由.append(NEIPv4Route(destinationAddress: 代理服务器, subnetMask: "255.255.255.255"))
                NSLog("[隧道] 代理服务器地址已加入排除路由：\(代理服务器)")
            }
        }

        IPv4设置.excludedRoutes = 排除路由
        设置.ipv4Settings = IPv4设置

        // DNS 设置
        // 关键：DNS 服务器不能设为 TUN 接口自身地址（10.0.0.2），否则发到接口自身的包可能不进 TUN
        // 设为同网段的网关地址 10.0.0.1，DNS 查询包走默认路由进 TUN，被路由规则端口53拦截到 dns-out
        // matchDomains = [""] 确保所有域名都走这个 DNS 服务器
        let DNS设置 = NEDNSSettings(servers: ["10.0.0.1"])
        DNS设置.matchDomains = [""]
        设置.dnsSettings = DNS设置

        // MTU（降低到 1400 避免物理网卡 MTU 差异导致分片丢包）
        设置.mtu = 1400

        // 代理设置（可选）
        if let 代理配置 = 隧道配置["proxy"] as? [String: Any],
           let 代理类型 = 代理配置["type"] as? String,
           代理类型 != "direct" {
            let 代理设置 = NEProxySettings()
            if let 服务器 = 代理配置["server"] as? String,
               let 端口 = 代理配置["port"] as? Int {
                代理设置.httpsEnabled = true
                代理设置.httpsServer = NEProxyServer(address: 服务器, port: 端口)
            }
            设置.proxySettings = 代理设置
        }

        setTunnelNetworkSettings(设置) { 错误 in
            if let 错误 = 错误 {
                self.日志.error("设置网络配置失败：\(错误.localizedDescription)")
            } else {
                self.日志.info("网络配置设置成功")
            }
            完成(错误)
        }
    }

    // MARK: - 数据包处理

    /// 启动数据包处理
    private func 启动数据包处理() {
        日志.debug("启动数据包读取循环")

        // 持续读取数据包
        packetFlow.readPackets { [weak self] 数据包列表, 协议列表 in
            guard let self = self else { return }

            for (索引, 数据包) in 数据包列表.enumerated() {
                let 协议 = 协议列表[索引]

                // 统计上行流量
                self.上行字节 += UInt64(数据包.count)

                // 处理数据包（此处为占位，实际应转发到代理内核）
                self.处理数据包(数据包, 协议: 协议)
            }

            // 继续读取
            if self.是否运行中 {
                self.启动数据包处理()
            }
        }
    }

    /// 停止数据包处理
    private func 停止数据包处理() {
        日志.debug("停止数据包处理")
    }

    /// 处理单个数据包
    private func 处理数据包(_ 数据包: Data, 协议: NSNumber) {
        // 当前为占位实现：sing-box 内核尚未集成
        // 数据包被读取后未转发到代理服务器，因此网络不通
        // TODO: 集成 sing-box Go 库后，将数据包发送到内核处理

        // 记录前10个数据包的大小，用于调试
        if 上行字节 < UInt64(数据包.count) * 10 {
            日志.debug("收到数据包：大小=\(数据包.count)字节，协议=\(协议)")
        }

        // 模拟下行响应（实际应从代理内核接收）
        // let 响应数据 = Data()
        // packetFlow.writePackets([响应数据], withProtocols: [协议])
        // 下行字节 += UInt64(响应数据.count)
    }

    // MARK: - 流量统计

    /// 启动统计定时器
    private func 启动统计定时器() {
        停止统计定时器()

        统计定时器 = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.保存统计数据()
            self?.清理超时的DNS查询开始时间()
        }
        RunLoop.main.add(统计定时器!, forMode: .common)
    }

    /// 清理超过 30 秒的 DNS 查询开始时间记录，防止字典无限增长导致内存超限
    private func 清理超时的DNS查询开始时间() {
        let 超时阈值: TimeInterval = 30
        扩展数据队列.async {
            let 现在 = Date()
            self.DNS查询开始时间 = self.DNS查询开始时间.filter { _, 开始时间 in
                现在.timeIntervalSince(开始时间) <= 超时阈值
            }
        }
    }

    /// 停止统计定时器
    private func 停止统计定时器() {
        统计定时器?.invalidate()
        统计定时器 = nil
    }

    /// 保存统计数据到共享 UserDefaults
    private func 保存统计数据() {
        guard let 共享默认 = 共享默认 else { return }

        // 如果 sing-box 内核运行中，从内核同步真实流量统计
        if singBox运行中 {
            singBox桥接.更新统计()
            上行字节 = singBox桥接.上行字节
            下行字节 = singBox桥接.下行字节
        }

        // 采样 VPN 扩展进程内存占用，写入共享存储供主 APP 显示
        let 扩展内存 = 获取当前进程内存占用()
        共享默认.set(扩展内存, forKey: "tunnelMemoryBytes")

        共享默认.set(上行字节, forKey: "uploadBytes")
        共享默认.set(下行字节, forKey: "downloadBytes")
        共享默认.set(是否运行中, forKey: "tunnelRunning")
        共享默认.set(Date(), forKey: "lastStatsUpdate")
    }

    /// 获取当前进程内存占用（字节）
    private func 获取当前进程内存占用() -> UInt64 {
        var 任务信息 = mach_task_basic_info()
        var 信息数 = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)

        let 结果 = withUnsafeMutablePointer(to: &任务信息) { 指针 in
            指针.withMemoryRebound(to: integer_t.self, capacity: Int(信息数)) { 重绑定指针 in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), 重绑定指针, &信息数)
            }
        }

        guard 结果 == KERN_SUCCESS else {
            return 0
        }

        return UInt64(任务信息.resident_size)
    }

    // MARK: - DNS 查询记录

    /// 已知的 DNS 记录类型关键字（用于动态定位，不依赖固定位置）
    private let 已知记录类型: Set<String> = ["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SOA", "PTR", "SRV", "CAA", "HTTPS", "SVCB"]

    /// 解析 sing-box DNS 日志并记录到共享 UserDefaults
    /// 支持格式：
    /// - dns: exchanged example.com. 300 IN A 1.2.3.4（成功解析）
    /// - dns: exchanged example.com. NXDOMAIN 300（域名不存在）
    /// - dns: lookup failed for example.com: timeout（查询失败）
    /// - dns: lookup example.com（查询开始，用于记录开始时间计算耗时）
    private func 解析并记录DNS查询(_ 日志内容: String) {
        // 只处理 DNS 相关日志
        guard 日志内容.contains("dns:") else { return }

        // 格式0：查询开始 dns: lookup example.com（记录开始时间，用于计算响应耗时）
        if 日志内容.contains("lookup "),
           !日志内容.contains("lookup failed"),
           !日志内容.contains("exchanged"),
           let 范围 = 日志内容.range(of: "lookup ") {
            let 剩余部分 = String(日志内容[范围.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            let 域名 = 剩余部分.components(separatedBy: .whitespaces).first ?? 剩余部分
            if !域名.isEmpty {
                // 串行化写：与主线程清理 Timer、以及 exchanged 分支的读取在同一队列
                扩展数据队列.async {
                    self.DNS查询开始时间[域名] = Date()
                }
            }
            return
        }

        // 格式1：成功解析 dns: exchanged example.com. 300 IN A 1.2.3.4
        if 日志内容.contains("exchanged"),
           let 范围 = 日志内容.range(of: "exchanged ") {
            let 剩余部分 = String(日志内容[范围.upperBound...])
            let 部分 = 剩余部分.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard 部分.count >= 2 else { return }

            // 域名始终是第一个字段，去掉末尾的点
            let 原始域名 = 部分[0]
            let 域名 = 原始域名.hasSuffix(".") ? String(原始域名.dropLast()) : 原始域名
            guard !域名.isEmpty else { return }

            // 计算响应耗时
            let 响应时间 = 计算DNS响应时间(域名: 域名)

            // 判断是否 NXDOMAIN
            if 部分.count >= 2 && 部分[1].uppercased() == "NXDOMAIN" {
                let TTL = 部分.count > 2 ? (Int(部分[2]) ?? 60) : 60
                保存DNS记录(域名: 域名, 记录类型: "A", 解析结果: [], TTL: TTL, DNS服务器: "sing-box", 来源: "远程", 是否失败: true, 响应时间: 响应时间)
                return
            }

            // 动态查找记录类型的位置（不依赖固定位置，兼容不同 sing-box 版本格式）
            var 类型索引 = -1
            var 记录类型字符串 = "A"
            for (索引, 字段) in 部分.enumerated() {
                if 索引 == 0 { continue } // 跳过域名
                let 大写字段 = 字段.uppercased()
                if 已知记录类型.contains(大写字段) {
                    类型索引 = 索引
                    记录类型字符串 = 大写字段
                    break
                }
            }

            // 没找到已知类型，尝试用位置3作为类型（兼容旧格式）
            if 类型索引 == -1 {
                if 部分.count >= 4 {
                    记录类型字符串 = 部分[3].uppercased()
                    类型索引 = 3
                } else {
                    // 格式不认识，跳过
                    return
                }
            }

            // TTL：类型索引前面的数字字段（通常在域名后面）
            var TTL = 300
            for i in 1..<类型索引 {
                if let 数字 = Int(部分[i]) {
                    TTL = 数字
                    break
                }
            }

            // 解析结果：类型索引后面的所有字段
            let 解析结果 = 类型索引 + 1 < 部分.count ? Array(部分[(类型索引 + 1)...]) : []

            保存DNS记录(域名: 域名, 记录类型: 记录类型字符串, 解析结果: 解析结果, TTL: TTL, DNS服务器: "sing-box", 来源: "远程", 是否失败: false, 响应时间: 响应时间)
            return
        }

        // 格式2：查询失败 dns: lookup failed for example.com: timeout
        if 日志内容.contains("lookup failed"),
           let 范围 = 日志内容.range(of: "lookup failed for ") {
            let 剩余部分 = String(日志内容[范围.upperBound...])
            // 格式：域名: 错误信息
            let 部分 = 剩余部分.components(separatedBy: ": ")
            guard !部分.isEmpty else { return }
            let 域名 = 部分[0].trimmingCharacters(in: .whitespaces)
            guard !域名.isEmpty else { return }
            let 响应时间 = 计算DNS响应时间(域名: 域名)
            保存DNS记录(域名: 域名, 记录类型: "A", 解析结果: [], TTL: 0, DNS服务器: "sing-box", 来源: "远程", 是否失败: true, 响应时间: 响应时间)
        }
    }

    /// 计算 DNS 响应耗时（毫秒），查找不到开始时间则返回 nil
    private func 计算DNS响应时间(域名: String) -> Int? {
        var 耗时: Int?
        // 与写入、清理在同一串行队列，保证读-删原子
        扩展数据队列.sync {
            guard let 开始时间 = self.DNS查询开始时间[域名] else { return }
            self.DNS查询开始时间.removeValue(forKey: 域名)
            let ms = Int(Date().timeIntervalSince(开始时间) * 1000)
            耗时 = ms > 0 ? ms : nil
        }
        return 耗时
    }

    /// 保存 DNS 记录到共享 UserDefaults
    private func 保存DNS记录(域名: String, 记录类型: String, 解析结果: [String], TTL: Int, DNS服务器: String, 来源: String, 是否失败: Bool, 响应时间: Int?) {
        // 解析结果统一去掉末尾的点（CNAME/MX/NS 等域名类型的值带末尾点，IP 类型不受影响）
        let 清理后的结果 = 解析结果.map { 值 -> String in
            值.hasSuffix(".") ? String(值.dropLast()) : 值
        }
        var DNS记录: [String: Any] = [
            "域名": 域名,
            "记录类型": 记录类型,
            "解析结果": 清理后的结果,
            "TTL": TTL,
            "查询时间": Date().timeIntervalSince1970,
            "DNS服务器": DNS服务器,
            "来源": 来源,
            "是否失败": 是否失败
        ]
        // 响应时间为 nil 时不写入，避免显示 0ms
        if let 耗时 = 响应时间 {
            DNS记录["响应时间"] = 耗时
        }

        DispatchQueue.main.async {
            guard let 共享默认 = self.共享默认 else { return }
            var 记录列表 = 共享默认.array(forKey: "dnsQueryRecords") as? [[String: Any]] ?? []
            记录列表.insert(DNS记录, at: 0)
            if 记录列表.count > 200 {
                记录列表 = Array(记录列表.prefix(200))
            }
            共享默认.set(记录列表, forKey: "dnsQueryRecords")
        }
    }

    // MARK: - 连接记录（用于规则命中统计）

    /// 解析 sing-box 连接日志并记录目标域名/IP到共享 UserDefaults
    /// 支持的日志格式：
    /// - connection: inbound connection from 10.0.0.2:12345 to example.com:443
    /// - connection: outbound connection to example.com:443
    private func 解析并记录连接(_ 日志内容: String) {
        // 只处理连接相关日志
        guard 日志内容.contains("connection:") else { return }

        // 提取目标地址（域名或IP:端口）
        var 目标地址: String?

        // 格式1：inbound connection from ... to example.com:443
        if let 范围 = 日志内容.range(of: "to ") {
            let 剩余 = String(日志内容[范围.upperBound...])
            if let 空格范围 = 剩余.rangeOfCharacter(from: .whitespacesAndNewlines) {
                目标地址 = String(剩余[..<空格范围.lowerBound])
            } else {
                目标地址 = 剩余.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let 地址 = 目标地址, !地址.isEmpty else { return }

        // 提取域名或IP（去掉端口）
        let 域名或IP: String
        if let 冒号范围 = 地址.range(of: ":", options: .backwards) {
            域名或IP = String(地址[..<冒号范围.lowerBound])
        } else {
            域名或IP = 地址
        }

        // 过滤掉无效地址和内网地址
        guard !域名或IP.isEmpty,
              !域名或IP.hasPrefix("10."),
              !域名或IP.hasPrefix("192.168."),
              !域名或IP.hasPrefix("172.16.") else { return }

        // 串行化写入
        扩展数据队列.async { [weak self] in
            guard let self = self, let 共享默认 = self.共享默认 else { return }

            var 记录列表 = 共享默认.array(forKey: "connectionRecords") as? [[String: Any]] ?? []

            // 去重：最近10条内相同域名不重复记录
            let 最近域名 = Set(记录列表.prefix(10).compactMap { $0["域名"] as? String })
            guard !最近域名.contains(域名或IP) else { return }

            let 连接记录: [String: Any] = [
                "域名": 域名或IP,
                "时间": Date().timeIntervalSince1970
            ]

            记录列表.insert(连接记录, at: 0)
            if 记录列表.count > 100 {
                记录列表 = Array(记录列表.prefix(100))
            }
            共享默认.set(记录列表, forKey: "connectionRecords")
        }
    }

    // MARK: - 配置管理

    /// 加载隧道配置
    private func 加载隧道配置() {
        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "加载隧道配置-开始")

        // 从协议配置读取
        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "加载隧道配置-读取协议配置")
        if let 协议配置 = protocolConfiguration as? NETunnelProviderProtocol,
           let 提供者配置 = 协议配置.providerConfiguration {
            隧道配置 = 提供者配置
            记录扩展日志(级别: "调试", 模块: "隧道", 内容: "加载隧道配置-协议配置读取成功，键数量=\(提供者配置.count)")
        } else {
            记录扩展日志(级别: "调试", 模块: "隧道", 内容: "加载隧道配置-无协议配置")
        }

        // 从共享 UserDefaults 读取额外配置
        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "加载隧道配置-读取UserDefaults")
        if let 共享默认 = 共享默认,
           let 配置数据 = 共享默认.data(forKey: "tunnelConfig"),
           let 配置 = try? JSONSerialization.jsonObject(with: 配置数据) as? [String: Any] {
            隧道配置.merge(配置) { _, 新 in 新 }
            记录扩展日志(级别: "调试", 模块: "隧道", 内容: "加载隧道配置-UserDefaults读取成功")
        } else {
            记录扩展日志(级别: "调试", 模块: "隧道", 内容: "加载隧道配置-无UserDefaults配置")
        }

        记录扩展日志(级别: "调试", 模块: "隧道", 内容: "加载隧道配置-完成")
        日志.debug("隧道配置加载完成")
    }

    // MARK: - 日志管理

    /// 扩展日志条目（与主 App 隧道日志模型格式一致）
    private struct 扩展日志条目: Codable {
        let id: UUID
        let 时间: Date
        let 级别: String
        let 模块: String
        let 内容: String
    }

    /// 记录扩展日志
    private func 记录扩展日志(级别: String, 模块: String, 内容: String) {
        // 后台低功耗模式：不记录调试日志，减少 IO
        if APP在后台 && 级别 == "调试" {
            return
        }

        let 条目 = 扩展日志条目(id: UUID(), 时间: Date(), 级别: 级别, 模块: 模块, 内容: 内容)

        // 保存到共享 UserDefaults（格式与主 App 读取一致）
        // 必须串行化：日志回调来自多个 Go 线程，并发 decode-insert-encode-set 会丢日志并可能损坏
        扩展数据队列.async { [weak self] in
            guard let 自 = self, let 共享默认 = 自.共享默认 else { return }
            var 日志列表: [扩展日志条目] = []
            if let 日志数据 = 共享默认.data(forKey: "tunnelLogs"),
               let 已存列表 = try? JSONDecoder().decode([扩展日志条目].self, from: 日志数据) {
                日志列表 = 已存列表
            }
            日志列表.insert(条目, at: 0)
            if 日志列表.count > 500 {
                日志列表.removeLast(日志列表.count - 500)
            }
            if let 编码数据 = try? JSONEncoder().encode(日志列表) {
                共享默认.set(编码数据, forKey: "tunnelLogs")
            }
        }

        // 输出到系统日志
        switch 级别 {
        case "错误":
            日志.error("\(模块): \(内容)")
        case "警告":
            日志.warning("\(模块): \(内容)")
        case "调试":
            日志.debug("\(模块): \(内容)")
        default:
            日志.info("\(模块): \(内容)")
        }
    }

    /// 读取扩展日志（供主 App 通过 IPC 查询）
    private func 读取扩展日志() -> [[String: Any]] {
        guard let 共享默认 = 共享默认,
              let 日志数据 = 共享默认.data(forKey: "tunnelLogs"),
              let 日志列表 = try? JSONDecoder().decode([扩展日志条目].self, from: 日志数据) else {
            return []
        }
        return 日志列表.map { [
            "id": $0.id.uuidString,
            "time": $0.时间.timeIntervalSince1970,
            "level": $0.级别,
            "module": $0.模块,
            "content": $0.内容
        ]}
    }

    // MARK: - 工具方法

    /// 停止原因描述
    private func 停止原因描述(_ 原因: NEProviderStopReason) -> String {
        switch 原因 {
        case .none: return "无"
        case .userInitiated: return "用户主动断开"
        case .providerFailed: return "提供者失败"
        case .noNetworkAvailable: return "无可用网络"
        case .unrecoverableNetworkChange: return "不可恢复的网络变更"
        case .providerDisabled: return "提供者被禁用"
        case .authenticationCanceled: return "认证取消"
        case .configurationFailed: return "配置失败"
        case .idleTimeout: return "空闲超时"
        case .configurationDisabled: return "配置被禁用"
        case .configurationRemoved: return "配置被移除"
        case .superceded: return "被取代"
        case .userLogout: return "用户注销"
        case .userSwitch: return "用户切换"
        case .connectionFailed: return "连接失败"
        case .sleep: return "设备睡眠"
        case .appUpdate: return "应用更新"
        @unknown default: return "未知原因"
        }
    }

    // MARK: - sing-box 内核控制

    /// 启动 sing-box 内核
    /// - Parameter 完成: 完成回调（是否启动成功）
    private func 启动SingBox内核(完成: @escaping (Bool) -> Void) {
        guard !singBox运行中 else {
            完成(true)
            return
        }

        // 检查配置文件是否存在
        guard let 配置路径 = singBox配置路径,
              FileManager.default.fileExists(atPath: 配置路径) else {
            日志.warning("sing-box 配置文件不存在，跳过内核启动")
            记录扩展日志(级别: "警告", 模块: "sing-box", 内容: "配置文件不存在，跳过内核启动")
            完成(false)
            return
        }

        日志.info("正在启动 sing-box 内核，配置：\(配置路径)")
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "正在启动内核，配置路径存在")

        // 读取配置文件内容
        guard let 配置数据 = try? Data(contentsOf: URL(fileURLWithPath: 配置路径)),
              let 配置内容 = String(data: 配置数据, encoding: .utf8) else {
            日志.error("读取 sing-box 配置文件失败")
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "读取配置文件失败")
            完成(false)
            return
        }
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "配置读取成功，大小：\(配置内容.utf8.count) 字节")
        // 完整配置调试输出已关闭（内容过长导致手机卡顿），如需排查可临时开启

        // 获取工作目录（App Group 容器目录）
        let 工作目录 = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.newvpn.app")?.path ?? NSTemporaryDirectory()
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "工作目录：\(工作目录)")

        // 初始化 libbox
        singBox桥接.初始化(工作目录: 工作目录)
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "libbox 初始化完成")

        // 设置日志回调
        singBox桥接.日志回调 = { [weak self] 级别, 内容 in
            guard let self = self else { return }
            let 级别字符串: String
            switch 级别 {
            case 0: 级别字符串 = "追踪"
            case 1: 级别字符串 = "调试"
            case 2: 级别字符串 = "信息"
            case 3: 级别字符串 = "警告"
            case 4: 级别字符串 = "错误"
            case 5: 级别字符串 = "致命"
            default: 级别字符串 = "未知"
            }

            // operation not permitted 错误降噪：iOS 沙盒不支持出站 packet 监听，属良性错误
            // 10 秒内同类错误只输出一条汇总，避免刷屏
            // 纳入内核日志采集开关控制，关闭时不输出
            if 内容.contains("listen outbound packet connection: operation not permitted") {
                self.扩展数据队列.async {
                    self.Packet权限错误计数 += 1
                    let 现在 = Date()
                    if let 上次 = self.上次Packet权限错误汇总时间,
                       现在.timeIntervalSince(上次) < 10 {
                        return // 降噪周期内，跳过单条输出
                    }
                    let 计数 = self.Packet权限错误计数
                    self.Packet权限错误计数 = 0
                    self.上次Packet权限错误汇总时间 = 现在
                    // 只有内核日志采集开关开启时才输出汇总警告
                    let 调试日志开启 = self.共享默认?.bool(forKey: "debugLogEnabled") ?? true
                    if 调试日志开启 {
                        self.记录扩展日志(级别: "警告", 模块: "sing-box内核",
                            内容: "【出站Packet权限受限】iOS不支持出站packet监听，UDP无法代理，TCP/MITM不受影响。近10秒累计\(计数)条")
                    }
                }
                return
            }

            // 调试日志总开关：关闭时不写入 UserDefaults（减少 IO），但仍解析 DNS 查询记录
            let 调试日志开启 = self.共享默认?.bool(forKey: "debugLogEnabled") ?? true
            if 调试日志开启 {
                self.记录扩展日志(级别: 级别字符串, 模块: "sing-box内核", 内容: 内容)
            }
            // 解析 DNS 查询日志并记录（独立于调试日志开关）
            self.解析并记录DNS查询(内容)
            // 解析连接日志并记录（用于规则命中统计）
            self.解析并记录连接(内容)
        }
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "日志回调已设置")

        // 获取 TUN 文件描述符，多种方式依次尝试，记录每种方式的结果
        // 方式1：libbox 官方提供的全局函数（专门为 iOS Network Extension 设计）
        let libboxFD = LibboxGetTunnelFileDescriptor()
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "方式1 LibboxGetTunnelFileDescriptor 返回 fd=\(libboxFD)")

        var tun文件描述符 = libboxFD

        // 方式2：如果官方函数返回无效，通过运行时反射从 packetFlow 提取
        if tun文件描述符 < 0 {
            var 获取错误: NSError?
            let 反射FD = Libbox平台接口OC.安全获取文件描述符(packetFlow, error: &获取错误)
            记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "方式2 反射提取返回 fd=\(反射FD)")
            if let 错误 = 获取错误 {
                记录扩展日志(级别: "警告", 模块: "sing-box", 内容: "反射提取详情：\(错误.localizedDescription)")
            }
            tun文件描述符 = 反射FD
        }

        guard tun文件描述符 >= 0 else {
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "所有方式均未获取到有效 TUN 文件描述符，sing-box 无法接管流量")
            完成(false)
            return
        }

        // 直接用完整配置启动内核
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "调用 LibboxNewService 创建服务...")
        let 成功 = singBox桥接.启动内核(配置内容: 配置内容, tun文件描述符: tun文件描述符)

        if 成功 {
            singBox运行中 = true
            记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "内核启动成功，TUN 由 sing-box 直接接管")
        } else {
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "内核启动失败，请查看上方 sing-box内核 错误日志")
        }

        完成(成功)
    }

    /// 停止 sing-box 内核
    private func 停止SingBox内核() {
        guard singBox运行中 else { return }

        日志.info("正在停止 sing-box 内核")
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "正在停止内核...")

        singBox桥接.停止内核()
        singBox运行中 = false

        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "内核已停止")
    }

    /// 重新加载 sing-box 内核配置
    private func 重载SingBox配置() {
        guard singBox运行中 else {
            记录扩展日志(级别: "警告", 模块: "sing-box", 内容: "内核未运行，跳过重载")
            return
        }

        guard let 配置路径 = singBox配置路径,
              let 配置数据 = try? Data(contentsOf: URL(fileURLWithPath: 配置路径)),
              let 配置内容 = String(data: 配置数据, encoding: .utf8) else {
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "读取配置文件失败，无法重载")
            return
        }

        日志.info("正在重新加载 sing-box 配置")
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "正在重新加载配置...")

        // 先停止当前内核
        singBox桥接.停止内核()
        singBox运行中 = false

        // 重新获取 TUN 文件描述符（停止内核后原 fd 可能已失效）
        let libboxFD = LibboxGetTunnelFileDescriptor()
        var tun文件描述符 = libboxFD
        if tun文件描述符 < 0 {
            var 获取错误: NSError?
            let 反射FD = Libbox平台接口OC.安全获取文件描述符(packetFlow, error: &获取错误)
            tun文件描述符 = 反射FD
            记录扩展日志(级别: "警告", 模块: "sing-box", 内容: "重载时 LibboxGetTunnelFileDescriptor 无效，使用反射提取 fd=\(反射FD)")
        }

        guard tun文件描述符 >= 0 else {
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "重载失败：无法获取有效 TUN 文件描述符")
            return
        }

        // 使用新配置重启内核
        let 成功 = singBox桥接.启动内核(配置内容: 配置内容, tun文件描述符: tun文件描述符)
        if 成功 {
            singBox运行中 = true
            记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "配置重载成功，内核已重启")
        } else {
            singBox运行中 = false
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "配置重载失败，内核启动失败，请查看上方错误日志")
        }
    }

    /// 获取 sing-box 内核统计
    private func 获取SingBox统计() -> [String: Any] {
        [
            "running": singBox运行中,
            "uploadBytes": singBox桥接.上行字节,
            "downloadBytes": singBox桥接.下行字节
        ]
    }

    // MARK: - 热更新

    /// 启动热更新轮询定时器
    private func 启动热更新定时器() {
        热更新定时器?.invalidate()
        热更新定时器 = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.检查热更新指令()
        }
        记录扩展日志(级别: "信息", 模块: "热更新", 内容: "热更新轮询定时器已启动")
    }

    /// 停止热更新定时器
    private func 停止热更新定时器() {
        热更新定时器?.invalidate()
        热更新定时器 = nil
    }

    // MARK: - 心跳检测与自动重连

    /// 启动心跳检测定时器（30秒一次）
    private func 启动心跳定时器() {
        停止心跳定时器()
        心跳定时器 = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.执行心跳检测()
        }
        RunLoop.main.add(心跳定时器!, forMode: .common)
        记录扩展日志(级别: "信息", 模块: "保活", 内容: "心跳检测定时器已启动，间隔30秒")
    }

    /// 停止心跳定时器
    private func 停止心跳定时器() {
        心跳定时器?.invalidate()
        心跳定时器 = nil
    }

    /// 执行心跳检测：检查 sing-box 内核状态和网络连通性
    private func 执行心跳检测() {
        guard 是否运行中 else { return }

        // 检查 sing-box 内核是否运行
        guard singBox运行中 else {
            心跳失败次数 += 1
            记录扩展日志(级别: "警告", 模块: "保活", 内容: "心跳检测失败：sing-box内核未运行，连续失败\(心跳失败次数)次")
            if 心跳失败次数 >= 3 {
                触发自动重连()
            }
            return
        }

        // 检查网络连通性：通过 Clash API 获取连接数判断内核是否正常工作
        let 配置 = URLSessionConfiguration.ephemeral
        配置.timeoutIntervalForRequest = 5
        let 会话 = URLSession(configuration: 配置)
        guard let url = URL(string: "http://127.0.0.1:9090/connections") else { return }

        let 任务 = 会话.dataTask(with: url) { [weak self] _, 响应, 错误 in
            guard let self = self else { return }
            if 错误 != nil || (响应 as? HTTPURLResponse)?.statusCode != 200 {
                self.心跳失败次数 += 1
                self.记录扩展日志(级别: "警告", 模块: "保活", 内容: "心跳检测失败：Clash API无响应，连续失败\(self.心跳失败次数)次")
                if self.心跳失败次数 >= 3 {
                    DispatchQueue.main.async {
                        self.触发自动重连()
                    }
                }
            } else {
                // 心跳成功，重置计数
                if self.心跳失败次数 > 0 {
                    self.记录扩展日志(级别: "信息", 模块: "保活", 内容: "心跳检测恢复正常")
                }
                self.心跳失败次数 = 0
                // 更新心跳时间戳，供 APP 后台监控
                self.共享默认?.set(Date(), forKey: "tunnelHeartbeatTime")
            }
        }
        任务.resume()
    }

    /// 触发自动重连（指数退避：3s→6s→12s→30s→60s，上限60s）
    private func 触发自动重连() {
        guard !正在重连 else { return }
        正在重连 = true
        重连次数 += 1

        let 延迟秒数: TimeInterval
        switch 重连次数 {
        case 1: 延迟秒数 = 3
        case 2: 延迟秒数 = 6
        case 3: 延迟秒数 = 12
        case 4: 延迟秒数 = 30
        default: 延迟秒数 = 60
        }

        记录扩展日志(级别: "警告", 模块: "保活", 内容: "触发自动重连，第\(重连次数)次，延迟\(Int(延迟秒数))秒后执行")

        重连定时器?.invalidate()
        重连定时器 = Timer.scheduledTimer(withTimeInterval: 延迟秒数, repeats: false) { [weak self] _ in
            self?.执行重连()
        }
    }

    /// 执行重连：停止内核后重新启动
    private func 执行重连() {
        记录扩展日志(级别: "信息", 模块: "保活", 内容: "开始执行自动重连")

        // 停止当前内核
        停止SingBox内核()

        // 延迟一小段时间后重新加载配置并启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            self.加载隧道配置()
            self.设置网络配置 { _ in }
            self.重载SingBox配置()

            self.正在重连 = false
            self.心跳失败次数 = 0
            self.记录扩展日志(级别: "信息", 模块: "保活", 内容: "自动重连完成")
        }
    }

    /// 检查并处理热更新指令
    private func 检查热更新指令() {
        guard let 指令 = 抓包存储管理器.共享.读取热更新指令() else {
            return
        }

        记录扩展日志(级别: "信息", 模块: "热更新", 内容: "收到热更新指令：抓包=\(指令.抓包启用 ? "开启" : "关闭")")

        // 执行热更新
        执行热更新(指令: 指令)
    }

    /// 执行热更新：重启 sing-box 内核，动态加载/卸载抓包入站
    private func 执行热更新(指令: 抓包存储管理器.热更新指令) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                // 1. 停止当前 sing-box 内核
                self.停止SingBox内核()

                // 2. 停止本地抓包代理
                本地HTTP代理.共享.停止()

                // 3. 修改配置文件，添加或移除抓包入站
                try self.更新抓包配置(抓包启用: 指令.抓包启用)

                // 4. 如果抓包启用，启动本地抓包代理
                if 指令.抓包启用 {
                    本地HTTP代理.共享.启动()
                    self.记录扩展日志(级别: "信息", 模块: "热更新", 内容: "本地抓包代理已启动")
                }

                // 5. 重新启动 sing-box 内核
                self.启动SingBox内核 { 成功 in
                    if 成功 {
                        self.singBox运行中 = true
                        抓包存储管理器.共享.写入热更新结果(指令ID: 指令.指令ID, 成功: true)
                        self.记录扩展日志(级别: "信息", 模块: "热更新", 内容: "热更新成功，sing-box 内核已重启")
                    } else {
                        抓包存储管理器.共享.写入热更新结果(指令ID: 指令.指令ID, 成功: false, 错误信息: "sing-box 内核启动失败")
                        self.记录扩展日志(级别: "错误", 模块: "热更新", 内容: "热更新失败：sing-box 内核启动失败")
                    }
                }
            } catch {
                抓包存储管理器.共享.写入热更新结果(指令ID: 指令.指令ID, 成功: false, 错误信息: error.localizedDescription)
                self.记录扩展日志(级别: "错误", 模块: "热更新", 内容: "热更新失败：\(error.localizedDescription)")
            }
        }
    }

    /// 更新抓包配置：在配置文件中添加或移除抓包入站和路由规则
    private func 更新抓包配置(抓包启用: Bool) throws {
        guard let 配置路径 = singBox配置路径 else {
            throw NSError(domain: "HotUpdate", code: 1, userInfo: [NSLocalizedDescriptionKey: "配置文件路径不存在"])
        }

        let 配置URL = URL(fileURLWithPath: 配置路径)
        let 配置数据 = try Data(contentsOf: 配置URL)

        guard var 配置字典 = try JSONSerialization.jsonObject(with: 配置数据) as? [String: Any] else {
            throw NSError(domain: "HotUpdate", code: 2, userInfo: [NSLocalizedDescriptionKey: "配置文件格式错误"])
        }

        // 处理入站配置
        if var 入站列表 = 配置字典["inbounds"] as? [[String: Any]] {
            if 抓包启用 {
                // 检查是否已存在抓包入站
                let 已有抓包入站 = 入站列表.contains { ($0["tag"] as? String) == "capture-proxy" }
                if !已有抓包入站 {
                    // 添加抓包入站
                    let 抓包入站: [String: Any] = [
                        "type": "http",
                        "tag": "capture-proxy",
                        "listen": "127.0.0.1",
                        "listen_port": 8888
                    ]
                    入站列表.append(抓包入站)
                    配置字典["inbounds"] = 入站列表
                    记录扩展日志(级别: "信息", 模块: "热更新", 内容: "已添加抓包入站 capture-proxy")
                }
            } else {
                // 移除抓包入站
                let 过滤后 = 入站列表.filter { ($0["tag"] as? String) != "capture-proxy" }
                配置字典["inbounds"] = 过滤后
                记录扩展日志(级别: "信息", 模块: "热更新", 内容: "已移除抓包入站 capture-proxy")
            }
        }

        // 处理路由规则
        if var 路由 = 配置字典["route"] as? [String: Any],
           var 规则列表 = 路由["rules"] as? [[String: Any]] {
            if 抓包启用 {
                // 检查是否已存在抓包路由规则
                let 已有抓包规则 = 规则列表.contains { rule in
                    if let 出站 = rule["outbound"] as? String, 出站 == "capture-proxy",
                       let 端口 = rule["port"] as? Int, 端口 == 80 {
                        return true
                    }
                    return false
                }
                if !已有抓包规则 {
                    // 添加 HTTP(80) 流量转发到抓包代理的规则
                    let 抓包规则: [String: Any] = [
                        "port": 80,
                        "outbound": "capture-proxy"
                    ]
                    规则列表.insert(抓包规则, at: 0)
                    路由["rules"] = 规则列表
                    配置字典["route"] = 路由
                    记录扩展日志(级别: "信息", 模块: "热更新", 内容: "已添加抓包路由规则(端口80)")
                }
            } else {
                // 移除抓包路由规则
                let 过滤后 = 规则列表.filter { rule in
                    if let 出站 = rule["outbound"] as? String, 出站 == "capture-proxy" {
                        return false
                    }
                    return true
                }
                路由["rules"] = 过滤后
                配置字典["route"] = 路由
                记录扩展日志(级别: "信息", 模块: "热更新", 内容: "已移除抓包路由规则")
            }
        }

        // 写回配置文件
        let 新配置数据 = try JSONSerialization.data(withJSONObject: 配置字典, options: [.prettyPrinted])
        try 新配置数据.write(to: 配置URL)

        记录扩展日志(级别: "信息", 模块: "热更新", 内容: "配置文件已更新，抓包=\(抓包启用 ? "开启" : "关闭")")
    }
}
