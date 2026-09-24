//
//  PacketTunnelProvider.swift
//  NewVPN-Tunnel
//
//  PacketTunnel 扩展入口：管理隧道生命周期、网络配置、流量统计
//  预留 sing-box 内核集成接口
//

import NetworkExtension
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

    /// sing-box 内核是否运行中
    private var singBox运行中 = false

    /// sing-box 内核桥接
    private let singBox桥接 = SingBox内核桥接.共享

    // MARK: - socketpair 数据包转发

    /// socketpair：sing-box 端文件描述符
    private var singBox端fd: Int32 = -1
    /// socketpair：转发端文件描述符（与 packetFlow 之间转发）
    private var 转发端fd: Int32 = -1
    /// 数据包转发队列
    private let 转发队列 = DispatchQueue(label: "com.newvpn.packetforward", qos: .userInteractive)
    /// 转发是否运行中
    private var 转发运行中 = false

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
                } else {
                    self.日志.error("sing-box 内核启动失败，使用基础数据包处理")
                    // 仅在内核启动失败时才启动基础数据包读取循环
                    self.启动数据包处理()
                }

                // 启动统计定时器
                self.启动统计定时器()

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

        // 停止数据包处理
        停止数据包处理()

        // 停止统计定时器
        停止统计定时器()

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

    // MARK: - 网络配置

    /// 设置网络配置
    private func 设置网络配置(完成: @escaping (Error?) -> Void) {
        let 设置 = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")

        // IPv4 设置
        let IPv4设置 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        IPv4设置.includedRoutes = [NEIPv4Route.default()]
        IPv4设置.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0")
        ]
        设置.ipv4Settings = IPv4设置

        // DNS 设置
        let DNS设置 = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        DNS设置.matchDomains = [""]
        设置.dnsSettings = DNS设置

        // MTU（sing-box Network Extension 推荐 4064）
        设置.mtu = 4064

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
        }
        RunLoop.main.add(统计定时器!, forMode: .common)
    }

    /// 停止统计定时器
    private func 停止统计定时器() {
        统计定时器?.invalidate()
        统计定时器 = nil
    }

    /// 保存统计数据到共享 UserDefaults
    private func 保存统计数据() {
        guard let 共享默认 = 共享默认 else { return }

        共享默认.set(上行字节, forKey: "uploadBytes")
        共享默认.set(下行字节, forKey: "downloadBytes")
        共享默认.set(是否运行中, forKey: "tunnelRunning")
        共享默认.set(Date(), forKey: "lastStatsUpdate")
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
        let 条目 = 扩展日志条目(id: UUID(), 时间: Date(), 级别: 级别, 模块: 模块, 内容: 内容)

        // 保存到共享 UserDefaults（格式与主 App 读取一致）
        if let 共享默认 = 共享默认 {
            var 日志列表: [扩展日志条目] = []
            if let 日志数据 = 共享默认.data(forKey: "tunnelLogs"),
               let 已存列表 = try? JSONDecoder().decode([扩展日志条目].self, from: 日志数据) {
                日志列表 = 已存列表
            }
            日志列表.insert(条目, at: 0)
            if 日志列表.count > 300 {
                日志列表.removeLast(日志列表.count - 300)
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
            self.记录扩展日志(级别: 级别字符串, 模块: "sing-box内核", 内容: 内容)
        }
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "日志回调已设置")

        // 输出配置前1000字符用于排查
        let 配置预览 = String(配置内容.prefix(1000))
        记录扩展日志(级别: "调试", 模块: "sing-box", 内容: "配置预览：\(配置预览)")

        // 创建 socketpair：一端给 sing-box，另一端与 packetFlow 转发
        // NEPacketTunnelFlow 不暴露文件描述符，因此用 socketpair 桥接
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "创建 socketpair...")
        var socketPair: [Int32] = [-1, -1]
        let 创建结果 = socketpair(AF_UNIX, SOCK_DGRAM, 0, &socketPair)
        guard 创建结果 == 0 else {
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "socketpair 创建失败，errno=\(errno)")
            完成(false)
            return
        }
        singBox端fd = socketPair[0]
        转发端fd = socketPair[1]
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "socketpair 创建成功，sing-box端=\(singBox端fd)，转发端=\(转发端fd)")

        // 第一步：用 nil 平台接口测试（排查平台接口是否导致崩溃）
        let 最小配置 = """
        {
          "inbounds": [{"type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 7890}],
          "outbounds": [{"type": "direct", "tag": "direct"}]
        }
        """
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "第一步：nil 平台接口测试...")
        let nil接口成功 = singBox桥接.测试创建服务无平台接口(配置内容: 最小配置)
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "nil 平台接口测试结果：\(nil接口成功 ? "成功" : "失败")")

        if !nil接口成功 {
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "nil 平台接口也崩溃，问题出在libbox框架或配置")
            关闭SocketPair()
            完成(false)
            return
        }

        // 第二步：用平台接口 + 最小配置测试
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "第二步：平台接口 + 最小配置测试...")
        let 最小配置成功 = singBox桥接.启动内核(配置内容: 最小配置, tun文件描述符: singBox端fd)
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "最小配置测试结果：\(最小配置成功 ? "成功" : "失败")")

        if 最小配置成功 {
            // 最小配置成功，停止后用完整配置启动
            singBox桥接.停止内核()
            记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "最小配置成功，用完整配置启动...")
            let 成功 = singBox桥接.启动内核(配置内容: 配置内容, tun文件描述符: singBox端fd)

            if 成功 {
                singBox运行中 = true
                记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "内核启动成功，启动数据包转发")
                启动数据包转发()
            } else {
                记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "完整配置启动失败，请查看上方 sing-box内核 错误日志")
                关闭SocketPair()
            }
            完成(成功)
        } else {
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "平台接口导致崩溃，问题出在平台接口实现")
            关闭SocketPair()
            完成(false)
        }
    }

    /// 停止 sing-box 内核
    private func 停止SingBox内核() {
        guard singBox运行中 else { return }

        日志.info("正在停止 sing-box 内核")
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "正在停止内核...")

        singBox桥接.停止内核()
        singBox运行中 = false

        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "内核已停止")

        // 停止数据包转发并关闭 socketpair
        停止数据包转发()
        关闭SocketPair()
    }

    // MARK: - socketpair 数据包转发

    /// 启动数据包转发：在转发端fd和packetFlow之间双向转发IP包
    private func 启动数据包转发() {
        guard !转发运行中 else { return }
        转发运行中 = true
        记录扩展日志(级别: "信息", 模块: "转发", 内容: "数据包转发启动")

        // 方向1：packetFlow -> 转发端fd（上行）
        开始从PacketFlow读取()

        // 方向2：转发端fd -> packetFlow（下行）
        转发队列.async { [weak self] in
            self?.从转发端读取循环()
        }
    }

    /// 停止数据包转发
    private func 停止数据包转发() {
        转发运行中 = false
    }

    /// 关闭 socketpair
    private func 关闭SocketPair() {
        if singBox端fd >= 0 {
            close(singBox端fd)
            singBox端fd = -1
        }
        if 转发端fd >= 0 {
            close(转发端fd)
            转发端fd = -1
        }
        记录扩展日志(级别: "信息", 模块: "转发", 内容: "socketpair 已关闭")
    }

    /// 从 packetFlow 读取数据包并写入转发端fd（上行）
    private func 开始从PacketFlow读取() {
        guard 转发运行中 else { return }

        packetFlow.readPackets { [weak self] 数据包列表, 协议号列表 in
            guard let self = self, self.转发运行中 else { return }

            for (数据包, 协议号) in zip(数据包列表, 协议号列表) {
                // 写入转发端fd，sing-box会从singBox端fd读取
                let 发送结果 = 数据包.withUnsafeBytes { 指针 -> Int in
                    guard let 基地址 = 指针.baseAddress else { return -1 }
                    return write(self.转发端fd, 基地址, 数据包.count)
                }
                if 发送结果 > 0 {
                    self.上行字节 += UInt64(发送结果)
                }
            }

            // 继续读取下一批
            self.开始从PacketFlow读取()
        }
    }

    /// 从转发端fd读取数据包并写回 packetFlow（下行）
    private func 从转发端读取循环() {
        let 缓冲区 = UnsafeMutablePointer<UInt8>.allocate(capacity: 65535)
        defer { 缓冲区.deallocate() }

        while 转发运行中 && 转发端fd >= 0 {
            let 读取字节数 = read(转发端fd, 缓冲区, 65535)
            guard 读取字节数 > 0 else {
                if 读取字节数 < 0 && errno != EAGAIN && errno != EINTR {
                    记录扩展日志(级别: "错误", 模块: "转发", 内容: "从转发端读取失败，errno=\(errno)")
                }
                continue
            }

            // 从IP头判断协议版本：IPv4=0x40, IPv6=0x60
            let 版本 = (缓冲区.pointee & 0xF0) >> 4
            let 协议号: NSNumber
            if 版本 == 4 {
                协议号 = NSNumber(value: AF_INET)
            } else if 版本 == 6 {
                协议号 = NSNumber(value: AF_INET6)
            } else {
                continue // 未知IP版本，丢弃
            }

            let 数据包 = Data(bytes: 缓冲区, count: 读取字节数)
            packetFlow.writePackets([数据包], withProtocols: [协议号])
            下行字节 += UInt64(读取字节数)
        }
    }

    /// 重新加载 sing-box 内核配置
    private func 重载SingBox配置() {
        guard singBox运行中 else { return }

        guard let 配置路径 = singBox配置路径,
              let 配置数据 = try? Data(contentsOf: URL(fileURLWithPath: 配置路径)),
              let 配置内容 = String(data: 配置数据, encoding: .utf8) else {
            记录扩展日志(级别: "错误", 模块: "sing-box", 内容: "读取配置文件失败，无法重载")
            return
        }

        日志.info("正在重新加载 sing-box 配置")
        记录扩展日志(级别: "信息", 模块: "sing-box", 内容: "正在重新加载配置...")

        _ = singBox桥接.重载配置(配置内容: 配置内容)
    }

    /// 获取 sing-box 内核统计
    private func 获取SingBox统计() -> [String: Any] {
        [
            "running": singBox运行中,
            "uploadBytes": singBox桥接.上行字节,
            "downloadBytes": singBox桥接.下行字节
        ]
    }
}
