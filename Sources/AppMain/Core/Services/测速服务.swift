//
//  测速服务.swift
//  NewVPN
//
//  节点测速核心服务
//  仅支持 TCP 连接延迟测试
//  VPN 连接时自动使用物理网络接口测速，避免隧道接管导致虚假低延迟
//

import Foundation
import Network

// MARK: - 测速服务

/// 节点测速服务
final class 测速服务 {
    /// 共享单例
    static let 共享 = 测速服务()

    /// 网络路径监视器（用于检测当前物理网络接口类型）
    private let 路径监视器 = NWPathMonitor()
    /// 监视器队列
    private let 监视器队列 = DispatchQueue(label: "com.newvpn.pathmonitor")
    /// 当前物理网络接口类型
    private var 当前接口类型: NWInterface.InterfaceType?

    /// 私有初始化
    private init() {
        启动网络监测()
    }

    // MARK: - 网络监测

    /// 启动网络路径监测，记录当前物理接口类型
    private func 启动网络监测() {
        路径监视器.pathUpdateHandler = { [weak self] 路径 in
            guard let self = self else { return }
            // 优先获取 WiFi，其次蜂窝，排除 VPN（.other）和回环
            if 路径.usesInterfaceType(.wifi) {
                self.当前接口类型 = .wifi
            } else if 路径.usesInterfaceType(.cellular) {
                self.当前接口类型 = .cellular
            } else if 路径.usesInterfaceType(.wiredEthernet) {
                self.当前接口类型 = .wiredEthernet
            } else {
                self.当前接口类型 = nil
            }
        }
        路径监视器.start(queue: 监视器队列)
    }

    // MARK: - TCP 延迟测试

    /// TCP 连接延迟测试（使用 Network 框架 NWConnection）
    /// - Parameters:
    ///   - 地址: 节点服务器地址
    ///   - 端口: 节点端口
    ///   - 超时: 超时时间
    ///   - 次数: 测试次数（取平均值）
    /// - Returns: 平均延迟（毫秒）、抖动、丢包率
    func TCP延迟测试(地址: String, 端口: Int, 超时: TimeInterval = 5.0, 次数: Int = 3) -> (延迟: Int?, 抖动: Int?, 丢包率: Double?) {
        var 延迟列表: [Int] = []
        var 成功次数 = 0

        for _ in 0..<次数 {
            if let 延迟 = 单次TCP连接测试(地址: 地址, 端口: 端口, 超时: 超时) {
                延迟列表.append(延迟)
                成功次数 += 1
            }
        }

        guard !延迟列表.isEmpty else {
            return (nil, nil, 100.0)
        }

        // 计算平均延迟
        let 平均延迟 = Int(延迟列表.reduce(0, +) / 延迟列表.count)

        // 计算抖动（相邻延迟差的平均值）
        var 抖动 = 0
        if 延迟列表.count >= 2 {
            var 差值总和 = 0
            for i in 1..<延迟列表.count {
                差值总和 += abs(延迟列表[i] - 延迟列表[i-1])
            }
            抖动 = 差值总和 / (延迟列表.count - 1)
        }

        // 丢包率
        let 丢包率 = Double(次数 - 成功次数) / Double(次数) * 100.0

        return (平均延迟, 抖动, 丢包率)
    }

    /// 单次 TCP 连接测试（使用 NWConnection）
    /// VPN 连接时优先使用物理接口，失败后降级为默认路由
    private func 单次TCP连接测试(地址: String, 端口: Int, 超时: TimeInterval) -> Int? {
        guard let 端口号 = NWEndpoint.Port(rawValue: UInt16(端口)) else {
            return nil
        }

        let 主机 = NWEndpoint.Host(地址)

        // 优先尝试物理接口测速（绕过 VPN 隧道）
        if let 物理接口 = 当前接口类型 {
            if let 延迟 = 尝试连接(主机: 主机, 端口: 端口号, 超时: 超时, 强制接口: 物理接口) {
                return 延迟
            }
            // 物理接口失败，降级为默认路由重试一次
        }

        // 降级：使用默认路由（可能走 VPN，但至少能成功）
        return 尝试连接(主机: 主机, 端口: 端口号, 超时: 超时, 强制接口: nil)
    }

    /// 尝试建立 TCP 连接并返回延迟
    /// - Parameters:
    ///   - 主机: 目标主机
    ///   - 端口: 目标端口
    ///   - 超时: 超时时间
    ///   - 强制接口: 强制使用的网络接口类型，nil 表示默认路由
    /// - Returns: 连接延迟（毫秒），失败返回 nil
    private func 尝试连接(主机: NWEndpoint.Host, 端口: NWEndpoint.Port, 超时: TimeInterval, 强制接口: NWInterface.InterfaceType?) -> Int? {
        let 参数 = NWParameters.tcp

        // 如果指定了物理接口，强制使用该接口（绕过 VPN）
        if let 接口 = 强制接口 {
            参数.requiredInterfaceType = 接口
        }

        let 连接 = NWConnection(host: 主机, port: 端口, using: 参数)

        let 信号 = DispatchSemaphore(value: 0)
        var 延迟: Int?
        let 开始时间 = Date()
        var 已完成 = false

        连接.stateUpdateHandler = { 状态 in
            guard !已完成 else { return }

            switch 状态 {
            case .ready:
                已完成 = true
                延迟 = Int(Date().timeIntervalSince(开始时间) * 1000)
                连接.cancel()
                信号.signal()
            case .failed:
                已完成 = true
                连接.cancel()
                信号.signal()
            case .cancelled:
                已完成 = true
                信号.signal()
            default:
                break
            }
        }

        连接.start(queue: .global(qos: .userInitiated))

        // 等待连接完成或超时
        let 结果 = 信号.wait(timeout: .now() + 超时)
        if 结果 == .timedOut {
            已完成 = true
            连接.cancel()
            // 等待 cancel 完成
            _ = 信号.wait(timeout: .now() + 0.5)
        }

        return 延迟
    }

    // MARK: - 节点测速

    /// 对单个节点执行延迟测速
    /// - Parameters:
    ///   - 节点: 节点模型
    ///   - 配置: 测速配置
    /// - Returns: 测速结果
    func 测速节点(_ 节点: 节点模型, 配置: 测速配置 = .默认) -> 测速结果模型 {
        var 结果 = 测速结果模型.空结果(节点ID: 节点.id)

        // TCP 延迟测试
        let TCP结果 = TCP延迟测试(
            地址: 节点.地址,
            端口: 节点.端口,
            超时: 配置.延迟超时,
            次数: 配置.延迟测试次数
        )

        结果.延迟毫秒 = TCP结果.延迟
        结果.抖动毫秒 = TCP结果.抖动
        结果.丢包率 = TCP结果.丢包率

        if TCP结果.延迟 != nil {
            结果.成功 = true
        } else {
            结果.成功 = false
            结果.错误信息 = "无法连接到节点"
        }

        结果.测速时间 = Date()
        return 结果
    }
}
