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
    /// 采样定时器
    private var 采样定时器: Timer?
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
        let 新定时器 = Timer.scheduledTimer(withTimeInterval: 间隔, repeats: true) { [weak self] _ in
            self?.读取扩展内存()
        }
        采样定时器 = 新定时器
        RunLoop.main.add(新定时器, forMode: .common)
    }

    /// 停止 VPN 扩展内存监控
    func 停止监控() {
        采样定时器?.invalidate()
        采样定时器 = nil
    }

    // MARK: - 读取扩展内存

    /// 从 App Group 读取 VPN 扩展内存占用
    private func 读取扩展内存() {
        guard let 共享默认 = 共享默认 else { return }
        let 内存 = 共享默认.object(forKey: "tunnelMemoryBytes") as? UInt64 ?? 0
        DispatchQueue.main.async { [weak self] in
            self?.当前占用字节 = 内存
        }
    }

    // MARK: - 显示属性

    /// 当前内存占用显示文字（自动格式化）
    var 占用显示: String {
        字节格式化(当前占用字节)
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

    /// 字节格式化
    private func 字节格式化(_ 字节: UInt64) -> String {
        if 字节 < 1024 {
            return "\(字节) B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.1f KB", Double(字节) / 1024)
        } else {
            return String(format: "%.1f MB", Double(字节) / (1024 * 1024))
        }
    }
}
