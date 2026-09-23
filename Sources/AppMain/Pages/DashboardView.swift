//
//  DashboardView.swift
//  NewVPN
//
//  主控首页 Dashboard
//  布局：顶部状态区 + 横向功能卡片 + 内容区 + 底部工具栏
//  基于截图精确测量重构
//

import SwiftUI

/// 主控首页视图
struct DashboardView: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 可滚动内容区
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部状态区
                    顶部状态区()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // 横向功能卡片栏
                    顶部功能卡片栏()

                    // 主内容区（根据选中卡片切换）
                    主内容区()
                        .padding(.bottom, 16)
                }
            }

            // 底部固定工具栏
            底部工具栏()
        }
        .background(Color.页面背景.ignoresSafeArea())
        .底部弹窗(弹窗类型: $状态.当前底部弹窗)
    }
}

// MARK: - 顶部状态区

/// 顶部状态区：左侧状态文字 + 右侧开关
private struct 顶部状态区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        HStack {
            // 左侧：隧道状态文字
            Text(状态.隧道状态.显示文字)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(状态文字颜色)

            Spacer()

            // 右侧：电源开关
            Toggle("", isOn: Binding(
                get: { 状态.隧道状态.是否活跃 },
                set: { _ in 状态.切换隧道() }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .成功色))
        }
        .frame(height: 50)
    }

    /// 根据隧道状态返回文字颜色
    private var 状态文字颜色: Color {
        switch 状态.隧道状态 {
        case .运行中: return .成功色
        case .连接中, .准备中, .重连中: return .警告色
        case .错误: return .危险色
        case .已断开: return .primary
        }
    }
}

// MARK: - 主内容区

/// 根据选中顶部卡片切换内容区
private struct 主内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        Group {
            switch 状态.当前顶部卡片 {
            case .节点:
                节点内容区()
            case .网络活动:
                网络活动内容区()
            case .重写规则:
                重写规则内容区()
            case .分流规则:
                分流规则内容区()
            case .日志:
                日志内容区()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: 状态.当前顶部卡片)
    }
}

// MARK: - 预览

#Preview {
    DashboardView()
        .environmentObject(AppState.共享)
}
