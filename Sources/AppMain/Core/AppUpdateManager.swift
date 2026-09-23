//
//  AppUpdateManager.swift
//  NewVPN
//
//  应用更新检测管理器
//  负责检测新版本、版本比较、忽略版本管理
//

import Foundation

/// 应用更新检测管理器
final class AppUpdateManager: ObservableObject {
    /// 全局单例
    static let 共享 = AppUpdateManager()

    // MARK: - 发布状态

    /// 当前检测状态
    @Published var 检测状态: 更新检测状态 = .空闲

    /// 当前版本号（从 Info.plist 读取）
    var 当前版本号: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    // MARK: - 本地存储键

    private let 忽略版本键 = "AppUpdate_忽略版本"
    private let 稍后提醒时间键 = "AppUpdate_稍后提醒时间"

    // MARK: - 初始化

    private init() {}

    // MARK: - 开始检测

    /// 开始检测更新
    /// - Parameter 静默模式: true=后台静默检测（有新版本才弹窗），false=手动检测（始终弹窗）
    func 开始检测(静默模式: Bool = false) {
        guard 检测状态 == .空闲 else { return }

        // 检查是否在稍后提醒冷却期内
        if 静默模式, let 提醒时间 = UserDefaults.standard.object(forKey: 稍后提醒时间键) as? Date,
           Date().timeIntervalSince(提醒时间) < 24 * 3600 {
            return
        }

        Task {
            await 执行检测流程(静默模式: 静默模式)
        }
    }

    // MARK: - 检测流程

    /// 执行完整检测流程
    private func 执行检测流程(静默模式: Bool) async {
        // 步骤1：连接服务器
        await 更新状态(.检测中(.正在连接服务器))
        try? await Task.sleep(nanoseconds: 600_000_000)

        // 步骤2：获取版本信息
        await 更新状态(.检测中(.获取版本信息))
        try? await Task.sleep(nanoseconds: 600_000_000)

        // 步骤3：校验版本号
        await 更新状态(.检测中(.校验版本号))
        try? await Task.sleep(nanoseconds: 400_000_000)

        // 模拟获取版本信息（实际应从 GitHub Release API 获取）
        let 模拟版本信息 = 模拟获取版本信息()

        // 步骤4：检测完成，判断结果
        await 更新状态(.检测中(.检测完成))
        try? await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            if 版本比较器.有新版本(当前版本: 当前版本号, 最新版本: 模拟版本信息.最新版本) {
                // 检查是否被忽略
                if 静默模式, 模拟版本信息.最新版本 == 已忽略版本 {
                    检测状态 = .空闲
                    return
                }
                检测状态 = .发现新版本(模拟版本信息)
            } else {
                if 静默模式 {
                    // 静默模式下已是最新版本不弹窗
                    检测状态 = .空闲
                } else {
                    检测状态 = .已是最新
                }
            }
        }
    }

    /// 在主线程更新状态
    private func 更新状态(_ 新状态: 更新检测状态) async {
        await MainActor.run {
            self.检测状态 = 新状态
        }
    }

    // MARK: - 模拟数据

    /// 模拟从服务器获取版本信息
    private func 模拟获取版本信息() -> 版本信息模型 {
        版本信息模型(
            最新版本: "0.2.0",
            发布日期: "2026-09-24",
            构建环境: "Xcode 15.4 / macOS 14",
            最低iOS版本: "iOS 16.0",
            产物文件名: "newVPN-v0.2.0.ipa",
            产物描述: "未签名IPA（需自签名或侧载安装）",
            下载地址: "https://github.com/lambret-1/new-vpn/releases/download/v0.2.0/newVPN-v0.2.0.ipa",
            详情地址: "https://github.com/lambret-1/new-vpn/releases/tag/v0.2.0",
            更新说明: "新增检查更新功能，优化Dashboard界面"
        )
    }

    // MARK: - 忽略版本管理

    /// 已忽略的版本号
    var 已忽略版本: String? {
        UserDefaults.standard.string(forKey: 忽略版本键)
    }

    /// 忽略当前版本
    func 忽略当前版本(_ 版本号: String) {
        UserDefaults.standard.set(版本号, forKey: 忽略版本键)
        关闭弹窗()
    }

    /// 稍后提醒（24小时冷却）
    func 稍后提醒() {
        UserDefaults.standard.set(Date(), forKey: 稍后提醒时间键)
        关闭弹窗()
    }

    /// 关闭弹窗
    func 关闭弹窗() {
        检测状态 = .空闲
    }
}
