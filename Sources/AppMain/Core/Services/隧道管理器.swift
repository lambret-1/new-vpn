//
//  隧道管理器.swift
//  NewVPN
//
//  隧道管理器：VPN配置管理、连接控制、状态监控、流量统计
//

import Foundation
import NetworkExtension
import Combine
import UIKit

// MARK: - 隧道管理器

/// 隧道全局管理器
final class 隧道管理器: NSObject, ObservableObject {
    /// 共享单例
    static let 共享 = 隧道管理器()

    // MARK: - 发布状态

    /// 当前隧道状态
    @Published var 当前状态: 隧道状态 = .已断开
    /// 隧道配置
    @Published var 配置: 隧道配置模型 = .默认
    /// 流量统计
    @Published var 流量统计: 隧道流量统计 = 隧道流量统计()
    /// 隧道日志
    @Published var 日志列表: [隧道日志模型] = []
    /// 最近错误
    @Published var 最近错误: 隧道错误?
    /// 是否正在加载配置
    @Published var 是否加载中 = false
    /// 当前连接信息
    @Published var 当前连接: 隧道连接信息?
    /// 历史连接记录
    @Published var 历史连接: [隧道连接信息] = []
    /// 是否需要安装 VPN 描述文件
    @Published var 需要安装描述文件 = false
    /// 是否正在安装描述文件
    @Published var 正在安装描述文件 = false
    /// 是否需要用户手动安装描述文件（自动安装失败时）
    @Published var 需要手动安装描述文件 = false

    // MARK: - 内部属性

    /// VPN 管理器
    private var vpn管理器: NETunnelProviderManager?
    /// 统计更新定时器
    private var 统计定时器: Timer?
    /// 连接开始时间
    private var 连接开始时间: Date?
    /// 上次统计字节数
    private var 上次上行字节: UInt64 = 0
    private var 上次下行字节: UInt64 = 0

    /// 私有初始化
    private override init() {
        super.init()
        加载配置()
        注册通知监听()
        // 首次初始化时检测描述文件状态
        检测描述文件状态()
    }

    // MARK: - 配置管理

    /// 加载 VPN 配置
    func 加载配置() {
        是否加载中 = true

        NETunnelProviderManager.loadAllFromPreferences { [weak self] 管理器列表, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                self.记录日志(级别: .错误, 模块: "配置", 内容: "加载配置失败：\(错误.localizedDescription)")
                self.最近错误 = .未知错误(错误.localizedDescription)
                self.是否加载中 = false
                return
            }

            // 查找或创建配置
            if let 现有管理器 = 管理器列表?.first(where: { $0.localizedDescription == self.配置.隧道名称 }) {
                self.vpn管理器 = 现有管理器
            } else if let 第一个 = 管理器列表?.first {
                self.vpn管理器 = 第一个
            } else {
                // 创建新配置
                let 新管理器 = NETunnelProviderManager()
                新管理器.localizedDescription = self.配置.隧道名称
                self.vpn管理器 = 新管理器
            }

            // 更新状态
            if let 会话 = self.vpn管理器?.connection as? NETunnelProviderSession {
                self.当前状态 = 隧道状态.从NEVPN状态(会话.status)
            }

            self.是否加载中 = false
            self.记录日志(级别: .信息, 模块: "配置", 内容: "VPN 配置加载完成")
        }
    }

    /// 保存 VPN 配置
    func 保存配置(完成: ((Bool, Error?) -> Void)? = nil) {
        guard let 管理器 = vpn管理器 else {
            完成?(false, 隧道错误.扩展未安装)
            return
        }

        // 配置隧道协议
        let 协议配置 = NETunnelProviderProtocol()
        协议配置.providerBundleIdentifier = 隧道常量.扩展BundleID
        协议配置.serverAddress = 配置.服务器地址.isEmpty ? "NewVPN" : 配置.服务器地址
        协议配置.username = 配置.用户名
        协议配置.providerConfiguration = [
            "mtu": 配置.MTU,
            "logLevel": 配置.日志级别.rawValue,
            "enableStats": 配置.启用流量统计,
            "dnsServers": 配置.DNS服务器
        ]

        管理器.protocolConfiguration = 协议配置
        管理器.localizedDescription = 配置.隧道名称
        管理器.isEnabled = true
        管理器.isOnDemandEnabled = 配置.按需连接

        // 配置按需连接规则
        if 配置.按需连接 {
            var 规则: [NEOnDemandRule] = []

            if !配置.包含网络.isEmpty {
                let 连接规则 = NEOnDemandRuleConnect()
                连接规则.ssidMatch = 配置.包含网络
                规则.append(连接规则)
            }

            if !配置.排除网络.isEmpty {
                let 断开规则 = NEOnDemandRuleDisconnect()
                断开规则.ssidMatch = 配置.排除网络
                规则.append(断开规则)
            }

            if 规则.isEmpty {
                let 默认规则 = NEOnDemandRuleConnect()
                规则.append(默认规则)
            }

            管理器.onDemandRules = 规则
        }

        // 保存到偏好设置
        管理器.saveToPreferences { [weak self] 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                self.记录日志(级别: .错误, 模块: "配置", 内容: "保存配置失败：\(错误.localizedDescription)")
                self.最近错误 = .未知错误(错误.localizedDescription)
                完成?(false, 错误)
                return
            }

            self.记录日志(级别: .信息, 模块: "配置", 内容: "VPN 配置保存成功")
            完成?(true, nil)

            // 重新加载以获取最新状态
            self.加载配置()
        }
    }

    /// 重置配置
    func 重置配置() {
        配置 = .默认
        保存配置()
    }

    // MARK: - VPN 描述文件管理

    /// 描述文件是否已安装
    var 描述文件是否已安装: Bool {
        guard let 管理器 = vpn管理器 else { return false }
        return 管理器.protocolConfiguration != nil
    }

    /// 检测 VPN 描述文件状态
    /// - Parameter 完成: 完成回调（是否已安装）
    func 检测描述文件状态(完成: ((Bool) -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] 管理器列表, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                self.记录日志(级别: .错误, 模块: "描述文件", 内容: "检测描述文件状态失败：\(错误.localizedDescription)")
                完成?(false)
                return
            }

            // 查找已安装的配置
            let 已安装 = 管理器列表?.contains(where: { 管理器 in
                管理器.protocolConfiguration != nil
            }) ?? false

            DispatchQueue.main.async {
                self.需要安装描述文件 = !已安装
                self.记录日志(级别: .信息, 模块: "描述文件", 内容: 已安装 ? "VPN 描述文件已安装" : "VPN 描述文件未安装")
                完成?(已安装)
            }
        }
    }

    /// 生成默认 VPN 描述文件并保存为 .mobileconfig 文件
    /// - Returns: 描述文件 URL，失败返回 nil
    func 生成默认描述文件URL() -> URL? {
        let 默认描述文件 = VPN描述文件模型(
            名称: 配置.隧道名称,
            类型: .自定义,
            状态: .未安装,
            扩展BundleID: "com.newvpn.app.tunnel",
            服务器地址: "127.0.0.1"
        )
        return VPN描述文件服务.共享.保存描述文件到临时目录(默认描述文件)
    }

    /// 自动生成并安装默认 VPN 描述文件
    /// - Parameter 完成: 完成回调（是否成功）
    func 自动安装默认描述文件(完成: @escaping (Bool, String?) -> Void) {
        正在安装描述文件 = true
        需要手动安装描述文件 = false
        记录日志(级别: .信息, 模块: "描述文件", 内容: "开始自动生成并安装 VPN 描述文件")

        // 使用 loadAllFromPreferences 查找现有配置或创建新配置
        NETunnelProviderManager.loadAllFromPreferences { [weak self] 管理器列表, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                DispatchQueue.main.async {
                    self.正在安装描述文件 = false
                    self.需要手动安装描述文件 = true
                    self.记录日志(级别: .错误, 模块: "描述文件", 内容: "加载配置失败：\(错误.localizedDescription)")

                    // 检测是否是权限错误
                    let 错误描述 = 错误.localizedDescription.lowercased()
                    if 错误描述.contains("permission") || 错误描述.contains("denied") {
                        完成(false, "VPN 权限被拒绝\n\n请在弹出的 App 设置页面中检查 VPN 权限，或手动前往「设置 > 通用 > VPN 与设备管理」操作，也可尝试卸载后重新安装应用")
                    } else {
                        完成(false, "加载配置失败：\(错误.localizedDescription)\n\n请前往「设置 > 通用 > VPN」手动添加 VPN 配置")
                    }
                }
                return
            }

            // 查找现有配置或创建新配置
            let 管理器: NETunnelProviderManager
            if let 现有管理器 = 管理器列表?.first(where: { $0.localizedDescription == self.配置.隧道名称 }) {
                管理器 = 现有管理器
                self.记录日志(级别: .信息, 模块: "描述文件", 内容: "找到现有配置，正在更新")
            } else if let 第一个 = 管理器列表?.first {
                管理器 = 第一个
                self.记录日志(级别: .信息, 模块: "描述文件", 内容: "使用第一个现有配置")
            } else {
                管理器 = NETunnelProviderManager()
                self.记录日志(级别: .信息, 模块: "描述文件", 内容: "创建新配置")
            }

            // 创建 PacketTunnel 协议配置
            let 协议 = NETunnelProviderProtocol()
            协议.providerBundleIdentifier = "com.newvpn.app.tunnel"
            协议.serverAddress = "127.0.0.1"
            协议.providerConfiguration = [
                "serverAddress": "127.0.0.1"
            ]

            // 配置管理器
            管理器.protocolConfiguration = 协议
            管理器.localizedDescription = self.配置.隧道名称
            管理器.isEnabled = true
            管理器.isOnDemandEnabled = false

            // 保存配置
            管理器.saveToPreferences { [weak self] 保存错误 in
                guard let self = self else { return }

                if let 保存错误 = 保存错误 {
                    DispatchQueue.main.async {
                        self.正在安装描述文件 = false
                        self.需要手动安装描述文件 = true
                        self.记录日志(级别: .错误, 模块: "描述文件", 内容: "安装描述文件失败：\(保存错误.localizedDescription)")

                        // 检测是否是权限错误
                        let 错误描述 = 保存错误.localizedDescription.lowercased()
                        if 错误描述.contains("permission") || 错误描述.contains("denied") {
                            完成(false, "VPN 权限被拒绝\n\n请在弹出的 App 设置页面中检查 VPN 权限，或手动前往「设置 > 通用 > VPN 与设备管理」操作，也可尝试卸载后重新安装应用")
                        } else {
                            完成(false, "安装描述文件失败：\(保存错误.localizedDescription)\n\n请前往「设置 > 通用 > VPN」手动添加 VPN 配置")
                        }
                        return
                    }
                    return
                }

                // 重新加载以确认
                管理器.loadFromPreferences { _ in
                    DispatchQueue.main.async {
                        self.vpn管理器 = 管理器
                        self.需要安装描述文件 = false
                        self.需要手动安装描述文件 = false
                        self.记录日志(级别: .信息, 模块: "描述文件", 内容: "VPN 描述文件安装成功")
                        self.正在安装描述文件 = false
                        完成(true, nil)
                    }
                }
            }
        }
    }

    /// 跳转到 iOS 设置页面（App 设置）
    /// - Parameter 完成: 完成回调（是否成功跳转）
    func 跳转到设置页面(完成: ((Bool) -> Void)? = nil) {
        // iOS 10+ 禁止使用 App-Prefs: URL scheme 跳转到系统设置
        // 只能跳转到 App 自身的设置页面
        guard let 设置URL = URL(string: UIApplication.openSettingsURLString) else {
            完成?(false)
            return
        }

        UIApplication.shared.open(设置URL) { 成功 in
            完成?(成功)
        }
    }

    // MARK: - 连接控制

    /// 启动隧道连接
    func 启动连接(节点ID: UUID? = nil, 节点名称: String? = nil) {
        // 先检测描述文件状态
        检测描述文件状态 { [weak self] 已安装 in
            guard let self = self else { return }

            if !已安装 {
                // 未安装描述文件，提示安装
                DispatchQueue.main.async {
                    self.需要安装描述文件 = true
                    self.最近错误 = .扩展未安装
                    self.记录日志(级别: .警告, 模块: "连接", 内容: "VPN 描述文件未安装，请先安装描述文件")
                }
                return
            }

            // 已安装，继续连接流程
            self.执行隧道连接(节点ID: 节点ID, 节点名称: 节点名称)
        }
    }

    /// 执行隧道连接（内部方法，描述文件已确认安装后调用）
    private func 执行隧道连接(节点ID: UUID? = nil, 节点名称: String? = nil) {
        guard let 管理器 = vpn管理器 else {
            最近错误 = .扩展未安装
            记录日志(级别: .错误, 模块: "连接", 内容: "隧道扩展未安装，无法连接")
            return
        }

        // 先保存配置
        保存配置 { [weak self] 成功, 错误 in
            guard let self = self else { return }

            guard 成功 else {
                self.最近错误 = .配置无效(错误?.localizedDescription ?? "未知错误")
                return
            }

            do {
                // 建立连接
                let 会话 = 管理器.connection as? NETunnelProviderSession
                try 会话?.startTunnel(options: [
                    "nodeId": 节点ID?.uuidString ?? "",
                    "nodeName": 节点名称 ?? ""
                ])

                self.连接开始时间 = Date()
                self.当前连接 = 隧道连接信息(
                    开始时间: Date(),
                    状态: .正在连接,
                    节点ID: 节点ID,
                    节点名称: 节点名称
                )
                self.当前状态 = .正在连接
                self.记录日志(级别: .信息, 模块: "连接", 内容: "开始连接隧道\(节点名称.map { "：\($0)" } ?? "")")

                // 启动统计定时器
                self.启动统计定时器()

            } catch {
                self.最近错误 = .未知错误(error.localizedDescription)
                self.当前状态 = .连接失败
                self.记录日志(级别: .错误, 模块: "连接", 内容: "启动隧道失败：\(error.localizedDescription)")
            }
        }
    }

    /// 停止隧道连接
    func 停止连接() {
        guard let 管理器 = vpn管理器 else { return }

        let 会话 = 管理器.connection as? NETunnelProviderSession
        会话?.stopTunnel()

        当前状态 = .正在断开
        记录日志(级别: .信息, 模块: "连接", 内容: "正在断开隧道连接")

        // 停止统计定时器
        停止统计定时器()

        // 记录历史连接
        if var 连接 = 当前连接 {
            连接.结束时间 = Date()
            连接.状态 = .已断开
            连接.流量统计 = 流量统计
            历史连接.insert(连接, at: 0)
            if 历史连接.count > 50 {
                历史连接.removeLast()
            }
            当前连接 = nil
        }
    }

    /// 重新连接
    func 重新连接() {
        let 节点ID = 当前连接?.节点ID
        let 节点名称 = 当前连接?.节点名称

        停止连接()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.启动连接(节点ID: 节点ID, 节点名称: 节点名称)
        }
    }

    /// 切换连接状态
    func 切换连接(节点ID: UUID? = nil, 节点名称: String? = nil) {
        if 当前状态.是否活动 {
            停止连接()
        } else {
            启动连接(节点ID: 节点ID, 节点名称: 节点名称)
        }
    }

    // MARK: - 状态监控

    /// 注册通知监听
    private func 注册通知监听() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(处理VPN状态变更),
            name: .NEVPNStatusDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(处理配置变更),
            name: .NEVPNConfigurationChange,
            object: nil
        )
    }

    /// 处理 VPN 状态变更
    @objc private func 处理VPN状态变更(_ 通知: Notification) {
        guard let 会话 = 通知.object as? NETunnelProviderSession else { return }

        let 新状态 = 隧道状态.从NEVPN状态(会话.status)
        当前状态 = 新状态

        // 更新当前连接状态
        if var 连接 = 当前连接 {
            连接.状态 = 新状态
            当前连接 = 连接
        }

        switch 新状态 {
        case .已连接:
            记录日志(级别: .信息, 模块: "连接", 内容: "隧道连接成功")
            启动统计定时器()
        case .已断开:
            记录日志(级别: .信息, 模块: "连接", 内容: "隧道已断开")
            停止统计定时器()
        case .连接失败:
            记录日志(级别: .错误, 模块: "连接", 内容: "隧道连接失败")
            停止统计定时器()
        default:
            break
        }

        // 发送状态更新通知
        NotificationCenter.default.post(name: 隧道常量.状态更新通知, object: 新状态)
    }

    /// 处理配置变更
    @objc private func 处理配置变更() {
        记录日志(级别: .调试, 模块: "配置", 内容: "VPN 配置已变更")
    }

    // MARK: - 流量统计

    /// 启动统计定时器
    private func 启动统计定时器() {
        停止统计定时器()

        统计定时器 = Timer.scheduledTimer(withTimeInterval: 隧道常量.统计更新间隔, repeats: true) { [weak self] _ in
            self?.更新流量统计()
        }
        RunLoop.main.add(统计定时器!, forMode: .common)
    }

    /// 停止统计定时器
    private func 停止统计定时器() {
        统计定时器?.invalidate()
        统计定时器 = nil
    }

    /// 更新流量统计
    private func 更新流量统计() {
        guard let 会话 = vpn管理器?.connection as? NETunnelProviderSession else { return }

        // 从共享 UserDefaults 读取统计数据
        if let 共享默认 = UserDefaults(suiteName: 隧道常量.AppGroupID) {
            let 上行 = 共享默认.object(forKey: "uploadBytes") as? UInt64 ?? 0
            let 下行 = 共享默认.object(forKey: "downloadBytes") as? UInt64 ?? 0

            // 计算速度
            let 时间间隔 = 隧道常量.统计更新间隔
            let 上行速度 = 时间间隔 > 0 ? Double(上行 - 上次上行字节) / 时间间隔 : 0
            let 下行速度 = 时间间隔 > 0 ? Double(下行 - 上次下行字节) / 时间间隔 : 0

            上次上行字节 = 上行
            上次下行字节 = 下行

            // 计算连接时长
            let 连接时长 = 连接开始时间.map { Date().timeIntervalSince($0) } ?? 0

            流量统计 = 隧道流量统计(
                上行字节: 上行,
                下行字节: 下行,
                上行速度: max(0, 上行速度),
                下行速度: max(0, 下行速度),
                连接时长: 连接时长,
                最后更新时间: Date()
            )

            // 发送统计更新通知
            NotificationCenter.default.post(name: 隧道常量.统计更新通知, object: 流量统计)
        }
    }

    /// 重置流量统计
    func 重置流量统计() {
        流量统计 = 隧道流量统计()
        上次上行字节 = 0
        上次下行字节 = 0

        if let 共享默认 = UserDefaults(suiteName: 隧道常量.AppGroupID) {
            共享默认.removeObject(forKey: "uploadBytes")
            共享默认.removeObject(forKey: "downloadBytes")
        }
    }

    // MARK: - 日志管理

    /// 记录日志
    func 记录日志(级别: 隧道日志级别, 模块: String, 内容: String) {
        let 日志 = 隧道日志模型(
            时间: Date(),
            级别: 级别,
            模块: 模块,
            内容: 内容
        )

        DispatchQueue.main.async { [weak self] in
            self?.日志列表.insert(日志, at: 0)
            if (self?.日志列表.count ?? 0) > 500 {
                self?.日志列表.removeLast()
            }
        }

        // 发送日志更新通知
        NotificationCenter.default.post(name: 隧道常量.日志更新通知, object: 日志)
    }

    /// 清除日志
    func 清除日志() {
        日志列表.removeAll()
    }

    /// 从隧道扩展读取日志
    func 从扩展读取日志() {
        guard let 共享默认 = UserDefaults(suiteName: 隧道常量.AppGroupID),
              let 日志数据 = 共享默认.data(forKey: "tunnelLogs"),
              let 扩展日志 = try? JSONDecoder().decode([隧道日志模型].self, from: 日志数据) else {
            return
        }

        for 日志 in 扩展日志 {
            if !日志列表.contains(where: { $0.id == 日志.id }) {
                日志列表.insert(日志, at: 0)
            }
        }

        if 日志列表.count > 500 {
            日志列表.removeLast(日志列表.count - 500)
        }
    }

    // MARK: - 隧道扩展通信

    /// 发送消息到隧道扩展
    func 发送消息到扩展(_ 消息: [String: Any], 完成: (([String: Any]?, Error?) -> Void)? = nil) {
        guard let 会话 = vpn管理器?.connection as? NETunnelProviderSession else {
            完成?(nil, 隧道错误.扩展未安装)
            return
        }

        do {
            let 数据 = try JSONSerialization.data(withJSONObject: 消息)
            try 会话.sendProviderMessage(数据) { 响应数据 in
                guard let 响应数据 = 响应数据 else {
                    完成?(nil, nil)
                    return
                }

                do {
                    if let 响应 = try JSONSerialization.jsonObject(with: 响应数据) as? [String: Any] {
                        完成?(响应, nil)
                    } else {
                        完成?(nil, nil)
                    }
                } catch {
                    完成?(nil, error)
                }
            }
        } catch {
            完成?(nil, error)
        }
    }

    /// 获取隧道扩展版本
    func 获取扩展版本(完成: @escaping (String?) -> Void) {
        发送消息到扩展(["action": "getVersion"]) { 响应, _ in
            let 版本 = 响应?["version"] as? String
            DispatchQueue.main.async {
                完成(版本)
            }
        }
    }

    /// 重新加载隧道配置
    func 重新加载配置() {
        发送消息到扩展(["action": "reloadConfig"]) { [weak self] _, 错误 in
            if let 错误 = 错误 {
                self?.记录日志(级别: .错误, 模块: "配置", 内容: "重新加载配置失败：\(错误.localizedDescription)")
            } else {
                self?.记录日志(级别: .信息, 模块: "配置", 内容: "隧道配置已重新加载")
            }
        }
    }

    // MARK: - 权限

    /// 请求 VPN 权限
    func 请求VPN权限(完成: @escaping (Bool) -> Void) {
        保存配置 { 成功, 错误 in
            if 成功 {
                完成(true)
            } else {
                完成(false)
            }
        }
    }

    /// 检查 VPN 权限状态
    var 是否有权限: Bool {
        vpn管理器 != nil
    }
}
