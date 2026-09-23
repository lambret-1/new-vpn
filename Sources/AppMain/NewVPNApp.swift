//
//  NewVPNApp.swift
//  NewVPN
//
//  主 App 入口：注入全局状态，配置外观，承载全局更新弹窗
//

import SwiftUI
import BackgroundTasks

/// 后台任务标识符
enum 后台任务标识 {
    /// 订阅自动更新任务
    static let 订阅更新 = "com.newvpn.app.subscriptionRefresh"
}

@main
struct NewVPNApp: App {
    /// 全局应用状态
    @StateObject private var 状态 = AppState.共享
    /// 更新管理器
    @StateObject private var 更新管理器 = AppUpdateManager.共享
    /// 下载管理器
    @StateObject private var 下载管理器 = AppDownloadManager.共享
    /// 测速管理器
    @StateObject private var 测速管理 = 测速管理器.共享
    /// DNS 管理器
    @StateObject private var DNS管理 = DNS管理器.共享
    /// App 代理
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            根视图()
                .environmentObject(状态)
                .environmentObject(更新管理器)
                .environmentObject(下载管理器)
                .environmentObject(测速管理)
                .environmentObject(DNS管理)
                .preferredColorScheme(颜色方案)
        }
    }

    /// 根据设置返回配色方案
    private var 颜色方案: ColorScheme? {
        switch 状态.主题 {
        case .跟随系统: return nil
        case .浅色: return .light
        case .深色: return .dark
        }
    }
}

// MARK: - App 代理

/// App 代理，处理后台任务注册
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 注册后台订阅更新任务
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: 后台任务标识.订阅更新,
            using: nil
        ) { 任务 in
            self.处理订阅更新任务(任务 as! BGAppRefreshTask)
        }

        // 调度下次后台任务
        调度后台订阅更新()

        return true
    }

    /// 处理订阅更新后台任务
    private func 处理订阅更新任务(_ 任务: BGAppRefreshTask) {
        // 调度下次任务
        调度后台订阅更新()

        // 执行订阅更新
        let 状态 = AppState.共享
        状态.批量更新自动更新订阅()

        // 设置任务过期处理
        任务.expirationHandler = {
            // 任务即将过期，清理资源
        }

        // 标记任务完成（实际项目中应在更新完成后调用）
        任务.setTaskCompleted(success: true)
    }

    /// 调度后台订阅更新任务
    private func 调度后台订阅更新() {
        let 请求 = BGAppRefreshTaskRequest(identifier: 后台任务标识.订阅更新)
        // 最早1小时后执行
        请求.earliestBeginDate = Date(timeIntervalSinceNow: 3600)

        do {
            try BGTaskScheduler.shared.submit(请求)
        } catch {
            print("后台任务调度失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 根视图（承载全局弹窗）

/// 应用根视图，承载全局更新弹窗
private struct 根视图: View {
    /// 更新管理器
    @EnvironmentObject private var 更新管理器: AppUpdateManager
    /// 下载管理器
    @EnvironmentObject private var 下载管理器: AppDownloadManager

    var body: some View {
        ZStack {
            DashboardView()

            // 全局更新弹窗（居中显示，在设置页面也能弹出）
            if 更新管理器.是否显示弹窗 || 下载管理器.下载状态 == .下载中 {
                AppUpdateAlert(
                    更新管理器: 更新管理器,
                    下载管理器: 下载管理器
                ) {
                    更新管理器.关闭弹窗()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: 更新管理器.是否显示弹窗)
    }
}
