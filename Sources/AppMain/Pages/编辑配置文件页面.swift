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
                本地配置视图()
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

// MARK: - 本地配置视图

/// 本地配置列表视图
private struct 本地配置视图: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(状态.本地配置列表) { 配置 in
                    本地配置行(配置: 配置)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }
}

/// 本地配置行
private struct 本地配置行: View {
    let 配置: 本地配置模型

    var body: some View {
        HStack(spacing: 12) {
            // 配置图标
            Image(systemName: 配置.是否当前 ? "star.fill" : "doc")
                .font(.system(size: 18))
                .foregroundColor(配置.是否当前 ? .警告色 : .主题色)
                .frame(width: 36, height: 36)
                .background((配置.是否当前 ? Color.警告色 : Color.主题色).opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(配置.名称)
                    .font(.system(size: 15, weight: .medium))
                HStack(spacing: 8) {
                    Text(配置.来源)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(配置.大小显示)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if 配置.是否当前 {
                Text("使用中")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.成功色)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 本地配置模型

/// 本地配置文件模型
struct 本地配置模型: Identifiable {
    let id = UUID()
    let 名称: String
    let 来源: String
    let 文件大小: Int
    let 是否当前: Bool

    var 大小显示: String {
        if 文件大小 < 1024 {
            return "\(文件大小)B"
        } else if 文件大小 < 1024 * 1024 {
            return String(format: "%.1fKB", Double(文件大小) / 1024)
        } else {
            return String(format: "%.1fMB", Double(文件大小) / (1024 * 1024))
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        编辑配置文件页面()
            .environmentObject(AppState.共享)
    }
}
