//
//  测速服务.swift
//  NewVPN
//
//  节点测速核心服务
//  仅支持 TCP 连接延迟测试
//

import Foundation
import Network

// MARK: - 测速服务

/// 节点测速服务
final class 测速服务 {
    /// 共享单例
    static let 共享 = 测速服务()

    /// 私有初始化
    private init() {}

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
    private func 单次TCP连接测试(地址: String, 端口: Int, 超时: TimeInterval) -> Int? {
        guard let 端口号 = NWEndpoint.Port(rawValue: UInt16(端口)) else {
            return nil
        }

        let 主机 = NWEndpoint.Host(地址)
        let 连接 = NWConnection(host: 主机, port: 端口号, using: .tcp)

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
