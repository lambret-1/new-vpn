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
    /// 一期内存优化：扩展内存分桶指标（日志/DNS/连接/计时表/可用内存/压力等级）
    @Published private(set) var 分桶: [String: Any] = [:]
    /// 一期内存优化：最近一次系统内存压力事件
    @Published private(set) var 最近压力事件: [String: Any] = [:]
    /// 一期内存优化：最近一次手动清理的前后对比结果
    @Published private(set) var 清理结果: [String: Any] = [:]
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

    /// 从 App Group 读取 VPN 扩展内存占用与分桶指标
    private func 读取扩展内存() {
        guard let 共享默认 = 共享默认 else { return }
        // 注意：UserDefaults存储UInt64时桥接为NSNumber，读取时必须用as? NSNumber再取uint64Value
        // 直接as? UInt64会静默失败，始终得到0，导致数值不刷新
        let 内存对象 = 共享默认.object(forKey: "tunnelMemoryBytes") as? NSNumber
        let 内存值 = 内存对象?.uint64Value ?? 0
        // 一期内存优化：读取分桶、压力事件、清理结果
        let 分桶值 = 共享默认.dictionary(forKey: "tunnelMemoryBuckets") ?? [:]
        let 压力值 = 共享默认.dictionary(forKey: "tunnelMemoryPressureEvent") ?? [:]
        let 清理值 = 共享默认.dictionary(forKey: "tunnelMemoryCleanupResult") ?? [:]
        DispatchQueue.main.async { [weak self] in
            self?.当前占用字节 = 内存值
            self?.分桶 = 分桶值
            self?.最近压力事件 = 压力值
            self?.清理结果 = 清理值
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

    // MARK: - 一期内存优化：分桶与压力事件显示

    /// 分桶中的整数值读取（容错）
    private func 分桶整数(_ 键: String) -> Int {
        (分桶[键] as? NSNumber)?.intValue ?? 0
    }

    /// 隧道日志条数
    var 日志条数: Int { 分桶整数("日志条数") }
    /// 日志 JSON 编码字节数
    var 日志编码字节: Int { 分桶整数("日志编码字节") }
    /// DNS 记录条数
    var DNS记录条数: Int { 分桶整数("DNS记录条数") }
    /// 连接记录条数
    var 连接记录条数: Int { 分桶整数("连接记录条数") }
    /// DNS 查询计时表条数
    var DNS计时表条数: Int { 分桶整数("DNS计时表条数") }
    /// 系统可用内存（字节），-1 表示不可用
    var 可用内存字节: Int { 分桶整数("可用内存字节") }
    /// 当前压力等级（normal/warning/critical）
    var 当前压力等级: String { (分桶["压力等级"] as? String) ?? "normal" }

    /// 可用内存显示文字
    var 可用内存显示: String {
        let 值 = 可用内存字节
        guard 值 > 0 else { return "不可用" }
        return 字节格式化(UInt64(值))
    }

    /// 最近压力事件显示文字
    var 压力事件显示: String {
        guard !最近压力事件.isEmpty,
              let 等级 = 最近压力事件["等级"] as? String else { return "无" }
        return 等级
    }

    /// 最近一次清理释放的字节数
    var 清理释放字节: UInt64 {
        (清理结果["释放字节"] as? NSNumber)?.uint64Value ?? 0
    }

    /// 最近一次清理释放显示文字
    var 清理释放显示: String {
        let 字节 = 清理释放字节
        guard 字节 > 0 else { return "无" }
        return 字节格式化(字节)
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
