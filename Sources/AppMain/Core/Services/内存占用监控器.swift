//
//  内存占用监控器.swift
//  NewVPN
//
//  监控当前进程内存占用，用于网络活动页面可视化展示
//

import Foundation
import SwiftUI
import Combine

/// 内存占用监控器：定期采样当前进程内存占用
final class 内存占用监控器: ObservableObject {
    /// 共享单例
    static let 共享 = 内存占用监控器()

    /// 当前内存占用（字节）
    @Published private(set) var 当前占用字节: UInt64 = 0
    /// 当前内存占用百分比（0-100，相对于设备总内存）
    @Published private(set) var 当前占用百分比: Double = 0
    /// 设备总内存（字节）
    private let 设备总内存: UInt64

    /// 采样定时器
    private var 采样定时器: Timer?

    /// 私有初始化
    private init() {
        设备总内存 = ProcessInfo.processInfo.physicalMemory
    }

    // MARK: - 开始/停止监控

    /// 开始内存占用监控
    func 开始监控(间隔: TimeInterval = 2.0) {
        停止监控()
        // 立即采样一次
        采样内存占用()
        let 新定时器 = Timer.scheduledTimer(withTimeInterval: 间隔, repeats: true) { [weak self] _ in
            self?.采样内存占用()
        }
        采样定时器 = 新定时器
        RunLoop.main.add(新定时器, forMode: .common)
    }

    /// 停止内存占用监控
    func 停止监控() {
        采样定时器?.invalidate()
        采样定时器 = nil
    }

    // MARK: - 采样内存占用

    /// 采样当前进程内存占用
    private func 采样内存占用() {
        let 占用 = 获取当前进程内存占用()
        let 百分比 = 设备总内存 > 0 ? Double(占用) / Double(设备总内存) * 100 : 0

        DispatchQueue.main.async { [weak self] in
            self?.当前占用字节 = 占用
            self?.当前占用百分比 = min(max(百分比, 0), 100)
        }
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

        // resident_size 是当前进程占用的物理内存（字节）
        return UInt64(任务信息.resident_size)
    }

    // MARK: - 显示属性

    /// 当前内存占用显示文字（自动格式化）
    var 占用显示: String {
        字节格式化(当前占用字节)
    }

    /// 设备总内存显示文字
    var 总内存显示: String {
        字节格式化(设备总内存)
    }

    /// 内存占用等级
    var 等级: 内存等级 {
        switch 当前占用百分比 {
        case 0..<30: return .低
        case 30..<60: return .中
        case 60..<85: return .高
        default: return .极高
        }
    }

    /// 内存等级枚举
    enum 内存等级 {
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
            case .极高: return "极高"
            }
        }
    }

    // MARK: - 辅助方法

    /// 字节格式化
    private func 字节格式化(_ 字节: UInt64) -> String {
        if 字节 < 1024 {
            return "\(字节) B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.1f KB", Double(字节) / 1024)
        } else if 字节 < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(字节) / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", Double(字节) / (1024 * 1024 * 1024))
        }
    }
}
