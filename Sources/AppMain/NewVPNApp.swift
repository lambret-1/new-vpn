//
//  NewVPNApp.swift
//  NewVPN
//
//  主 App 入口：注入全局状态，配置外观，承载全局更新弹窗
//

import SwiftUI

@main
struct NewVPNApp: App {
    /// 全局应用状态
    @StateObject private var 状态 = AppState.共享
    /// 更新管理器
    @StateObject private var 更新管理器 = AppUpdateManager.共享
    /// 下载管理器
    @StateObject private var 下载管理器 = AppDownloadManager.共享

    var body: some Scene {
        WindowGroup {
            根视图()
                .environmentObject(状态)
                .environmentObject(更新管理器)
                .environmentObject(下载管理器)
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
