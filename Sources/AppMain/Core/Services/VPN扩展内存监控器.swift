//
//  VPN扩展内存监控器.swift
//  NewVPN
//
//  从 App Group 读取 VPN 隧道扩展进程内存占用，用于网络活动页面可视化展示
//

import Foundation
import SwiftUI
import Combine

/// VPN 扩展内存监控器：定期从 App Group 读取隧道扩展内存占用
final class VPN扩展内存监控器: ObservableObject {
    /// 共享单例
    static let 共享 = VPN扩展内存监控器()

    /// 当前 VPN 扩展内存占用（字节）
    @Published private(set) var 当前占用字节: UInt64 = 0
    /// 采样定时器（使用DispatchSourceTimer，不受RunLoop模式影响，确保稳定刷新）
    private var 采样定时器: DispatchSourceTimer?
    /// 定时器队列
    private let 定时器队列 = DispatchQueue(label: "com.newvpn.tunnelMemoryMonitor", qos: .utility)
    /// App Group UserDefaults
    private var 共享默认: UserDefaults? {
        UserDefaults(suiteName: "group.com.newvpn.app")
    }

    /// 私有初始化
    private init() {}

    // MARK: - 开始/停止监控

    /// 开始 VPN 扩展内存监控
    func 开始监控(间隔: TimeInterval = 2.0) {
        停止监控()
        // 立即读取一次
        读取扩展内存()

        let 定时器 = DispatchSource.makeTimerSource(queue: 定时器队列)
        定时器.schedule(deadline: .now() + 间隔, repeating: 间隔, leeway: .milliseconds(100))
        定时器.setEventHandler { [weak self] in
            self?.读取扩展内存()
        }
        定时器.resume()
        采样定时器 = 定时器
    }

    /// 停止 VPN 扩展内存监控
    func 停止监控() {
        采样定时器?.cancel()
        采样定时器 = nil
    }

    // MARK: - 立即采样

    /// 立即采样一次扩展内存（不等待定时器）
    func 立即采样() {
        读取扩展内存()
    }

    // MARK: - 清理扩展内存

    /// 通知 VPN 扩展执行内存清理（触发 Go GC、清理缓存）
    func 清理扩展内存() {
        guard let 共享默认 = 共享默认 else { return }
        // 写入清理指令和时间戳，扩展端轮询检测到后执行清理
        共享默认.set(Date().timeIntervalSince1970, forKey: "tunnelMemoryCleanupCommand")
        共享默认.synchronize()
    }

    // MARK: - 读取扩展内存

    /// 从 App Group 读取 VPN 扩展内存占用
    private func 读取扩展内存() {
        guard let 共享默认 = 共享默认 else { return }
        // 注意：UserDefaults存储UInt64时桥接为NSNumber，读取时必须用as? NSNumber再取uint64Value
        // 直接as? UInt64会静默失败，始终得到0，导致数值不刷新
        let 内存对象 = 共享默认.object(forKey: "tunnelMemoryBytes") as? NSNumber
        let 内存值 = 内存对象?.uint64Value ?? 0
        DispatchQueue.main.async { [weak self] in
            self?.当前占用字节 = 内存值
        }
    }

    // MARK: - 显示属性

    /// 当前内存占用显示文字（自动格式化，精确到小数点后两位）
    var 占用显示: String {
        字节格式化(当前占用字节)
    }

    /// 重置为0（VPN断开时调用）
    func 重置为零() {
        当前占用字节 = 0
    }

    /// VPN 扩展内存等级（扩展内存限制严格，阈值较低）
    var 等级: 扩展内存等级 {
        // VPN 扩展内存限制通常为 15-50 MB，按 30 MB 为基准分级
        let 基准MB: Double = 30
        let 百分比 = min(Double(当前占用字节) / (基准MB * 1024 * 1024) * 100, 100)
        switch 百分比 {
        case 0..<40: return .低
        case 40..<70: return .中
        case 70..<90: return .高
        default: return .极高
        }
    }

    /// 占用百分比（用于进度条，基于 30MB 基准）
    var 占用百分比: Double {
        let 基准MB: Double = 30
        return min(Double(当前占用字节) / (基准MB * 1024 * 1024) * 100, 100)
    }

    /// 扩展内存等级枚举
    enum 扩展内存等级 {
        case 低
        case 中
        case 高
        case 极高

        /// 对应颜色
        var 颜色: Color {
            switch self {
            case .低: return .green
            case .中: return .orange
            case .高: return .red
            case .极高: return Color(red: 0.8, green: 0.0, blue: 0.0)
            }
        }

        /// 等级文字
        var 文字: String {
            switch self {
            case .低: return "正常"
            case .中: return "中等"
            case .高: return "较高"
            case .极高: return "危险"
            }
        }
    }

    // MARK: - 辅助方法

    /// 字节格式化（精确到小数点后两位，便于观察变化）
    private func 字节格式化(_ 字节: UInt64) -> String {
        if 字节 == 0 {
            return "0 B"
        } else if 字节 < 1024 {
            return "\(字节) B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.2f KB", Double(字节) / 1024)
        } else {
            return String(format: "%.2f MB", Double(字节) / (1024 * 1024))
        }
    }
}
