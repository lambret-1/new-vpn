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
    /// 更新管理器（从全局环境获取）
    @EnvironmentObject private var 更新管理器: AppUpdateManager
    /// 隧道管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器
    /// 场景阶段
    @Environment(\.scenePhase) private var 场景阶段

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
        .onAppear {
            // 启动时每日检测更新
            更新管理器.每日启动检测()
            // 每次打开都检测描述文件状态
            隧道管理.检测描述文件状态()
        }
        .onChange(of: 场景阶段) { 新阶段 in
            if 新阶段 == .active {
                // 回到前台时间隔>6小时则检测
                更新管理器.前台检测()
            }
        }
    }
}

// MARK: - 顶部状态区

/// 顶部状态区：左侧状态文字 + 右侧开关
private struct 顶部状态区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 隧道管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器

    var body: some View {
        HStack(alignment: .top) {
            // 左侧：隧道状态文字 + 当前节点
            VStack(alignment: .leading, spacing: 4) {
                Text(隧道管理.当前状态.rawValue)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(状态文字颜色)

                if let 当前节点 = 状态.当前节点 {
                    HStack(spacing: 4) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(当前节点.名称)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 右侧：电源开关
            Toggle("", isOn: Binding(
                get: { 隧道管理.当前状态.是否活动 },
                set: { _ in 隧道管理.切换连接() }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .成功色))
            .padding(.top, 4)
        }
        .frame(height: 50)
    }

    /// 根据隧道状态返回文字颜色
    private var 状态文字颜色: Color {
        switch 隧道管理.当前状态 {
        case .已连接: return .成功色
        case .正在连接, .重新加载中, .准备中, .重连中: return .警告色
        case .连接失败, .配置无效: return .危险色
        case .已断开, .正在断开: return .primary
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
            case .调试日志:
                调试日志内容区()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: 状态.当前顶部卡片)
    }
}

// MARK: - 预览

#Preview {
    DashboardView()
        .environmentObject(AppState.共享)
        .environmentObject(AppUpdateManager.共享)
        .environmentObject(AppDownloadManager.共享)
        .environmentObject(隧道管理器.共享)
}
