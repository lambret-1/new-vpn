//
//  CPU占用监控器.swift
//  NewVPN
//
//  监控当前进程 CPU 使用率，用于网络活动页面可视化展示
//

import Foundation
import MachO
import SwiftUI
import Combine

/// CPU 占用监控器：定期采样当前进程 CPU 使用率
final class CPU占用监控器: ObservableObject {
    /// 共享单例
    static let 共享 = CPU占用监控器()

    /// 当前 CPU 使用率（0-100）
    @Published private(set) var 当前使用率: Double = 0

    /// 采样定时器
    private var 采样定时器: Timer?

    /// 上次采样的线程使用时间
    private var 上次总使用时间: UInt64 = 0
    /// 上次采样的系统时间
    private var 上次系统时间: UInt64 = 0

    /// 私有初始化
    private init() {}

    // MARK: - 开始/停止监控

    /// 开始 CPU 占用监控
    func 开始监控(间隔: TimeInterval = 2.0) {
        停止监控()
        // 立即采样一次
        采样CPU使用率()
        采样定时器 = Timer.scheduledTimer(withTimeInterval: 间隔, repeats: true) { [weak self] _ in
            self?.采样CPU使用率()
        }
        RunLoop.main.add(采样定时器!, forMode: .common)
    }

    /// 停止 CPU 占用监控
    func 停止监控() {
        采样定时器?.invalidate()
        采样定时器 = nil
    }

    // MARK: - 采样 CPU 使用率

    /// 采样当前进程 CPU 使用率
    private func 采样CPU使用率() {
        let 任务 = mach_task_self_
        var 线程数: mach_msg_type_number_t = 0
        var 线程列表: thread_act_array_t?

        // 获取所有线程
        guard task_threads(任务, &线程列表, &线程数) == KERN_SUCCESS else {
            return
        }

        var 总使用时间: UInt64 = 0

        // 遍历所有线程，累加用户态和内核态使用时间
        for 索引 in 0..<Int(线程数) {
            guard let 线程 = 线程列表?[索引] else { continue }
            var 线程信息 = thread_basic_info()
            var 信息数 = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)

            let 结果 = withUnsafeMutablePointer(to: &线程信息) { 指针 in
                指针.withMemoryRebound(to: integer_t.self, capacity: Int(信息数)) { 重绑定指针 in
                    thread_info(线程, THREAD_BASIC_INFO, 重绑定指针, &信息数)
                }
            }

            if 结果 == KERN_SUCCESS {
                let 用户时间 = UInt64(线程信息.user_time.seconds) * 1_000_000 + UInt64(线程信息.user_time.microseconds)
                let 系统时间 = UInt64(线程信息.system_time.seconds) * 1_000_000 + UInt64(线程信息.system_time.microseconds)
                总使用时间 += 用户时间 + 系统时间
            }
        }

        // 释放线程列表内存
        if let 列表 = 线程列表, 线程数 > 0 {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: 列表), vm_size_t(Int(线程数) * MemoryLayout<thread_t>.size))
        }

        // 获取当前系统时间（纳秒）
        let 当前系统时间 = DispatchTime.now().uptimeNanoseconds

        // 计算 CPU 使用率
        if 上次总使用时间 > 0 && 上次系统时间 > 0 {
            let 使用时间差 = Double(总使用时间 - 上次总使用时间) // 微秒
            let 系统时间差 = Double(当前系统时间 - 上次系统时间) / 1000 // 纳秒转微秒

            if 系统时间差 > 0 {
                // CPU 使用率 = 使用时间差 / 系统时间差 * 100
                // 多核 CPU 可能超过 100%，限制在 0-100 范围显示
                let 使用率 = min(max(使用时间差 / 系统时间差 * 100, 0), 100)
                DispatchQueue.main.async {
                    self.当前使用率 = 使用率
                }
            }
        }

        上次总使用时间 = 总使用时间
        上次系统时间 = 当前系统时间
    }

    /// CPU 使用率等级
    var 等级: CPU等级 {
        switch 当前使用率 {
        case 0..<30: return .低
        case 30..<60: return .中
        case 60..<85: return .高
        default: return .极高
        }
    }

    /// CPU 等级枚举
    enum CPU等级 {
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
}
