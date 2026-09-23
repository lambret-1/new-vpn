//
//  NewVPNApp.swift
//  NewVPN
//
//  主 App 入口：注入全局状态，配置外观
//

import SwiftUI

@main
struct NewVPNApp: App {
    /// 全局应用状态
    @StateObject private var 状态 = AppState.共享

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(状态)
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
