//
//  编辑配置文件页面.swift
//  NewVPN
//
//  编辑配置文件页面：本地配置列表 + 远程订阅管理
//

import SwiftUI

/// 编辑配置文件页面
struct 编辑配置文件页面: View {
    /// 当前选中的分段
    @State private var 当前分段: 配置分段 = .本地配置

    /// 配置分段类型
    enum 配置分段: String, CaseIterable {
        case 本地配置 = "本地配置"
        case 远程订阅 = "远程订阅"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 分段选择器
            Picker("", selection: $当前分段) {
                ForEach(配置分段.allCases, id: \.self) { 分段 in
                    Text(分段.rawValue).tag(分段)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 内容区
            TabView(selection: $当前分段) {
                配置描述文件列表页面()
                    .tag(配置分段.本地配置)

                订阅管理视图()
                    .tag(配置分段.远程订阅)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: 当前分段)
        }
        .background(Color.页面背景)
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        编辑配置文件页面()
            .environmentObject(AppState.共享)
            .environmentObject(配置描述文件管理器.共享)
    }
}
