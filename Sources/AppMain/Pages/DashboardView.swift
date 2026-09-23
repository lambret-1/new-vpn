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
    /// 是否显示安装描述文件弹窗
    @State private var 显示安装弹窗 = false

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
            // 检测描述文件状态
            隧道管理.检测描述文件状态()
        }
        .onChange(of: 场景阶段) { 新阶段 in
            if 新阶段 == .active {
                // 回到前台时间隔>6小时则检测
                更新管理器.前台检测()
                // 回到前台时重新检测描述文件状态
                隧道管理.检测描述文件状态()
            }
        }
        .onChange(of: 隧道管理.需要安装描述文件) { 需要安装 in
            if 需要安装 {
                显示安装弹窗 = true
            }
        }
        .alert("需要安装 VPN 描述文件", isPresented: $显示安装弹窗) {
            Button("立即安装") {
                安装描述文件()
            }
            Button("稍后再说", role: .cancel) {
                显示安装弹窗 = false
            }
        } message: {
            Text("检测到您尚未安装 VPN 描述文件，需要安装后才能使用隧道连接功能。是否立即安装？")
        }
        .fullScreenCover(isPresented: $隧道管理.正在安装描述文件) {
            安装描述文件进度页面()
                .environmentObject(隧道管理)
        }
    }

    /// 安装描述文件
    private func 安装描述文件() {
        隧道管理.自动安装默认描述文件 { 成功, 错误 in
            if !成功 {
                // 安装失败，显示错误提示
                DispatchQueue.main.async {
                    显示安装弹窗 = true
                }
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
        case .正在连接, .重新加载中: return .警告色
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
            }
        }
        .animation(.easeInOut(duration: 0.2), value: 状态.当前顶部卡片)
    }
}

// MARK: - 安装描述文件进度页面

/// 安装描述文件进度页面
private struct 安装描述文件进度页面: View {
    @EnvironmentObject private var 隧道管理: 隧道管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 安装步骤 = 0
    @State private var 安装完成 = false
    @State private var 安装失败 = false
    @State private var 错误信息 = ""

    private let 步骤列表 = [
        "正在生成 VPN 配置...",
        "正在保存配置到系统...",
        "正在验证配置...",
        "安装完成"
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // 图标
                ZStack {
                    Circle()
                        .stroke(安装失败 ? Color.危险色.opacity(0.3) : Color.主题色.opacity(0.3), lineWidth: 4)
                        .frame(width: 100, height: 100)

                    if 安装完成 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.成功色)
                    } else if 安装失败 {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.危险色)
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }

                // 标题
                VStack(spacing: 8) {
                    Text(安装完成 ? "安装成功" : (安装失败 ? "安装失败" : "正在安装 VPN 描述文件"))
                        .font(.system(size: 22, weight: .bold))

                    if 安装完成 {
                        Text("VPN 描述文件已成功安装，现在可以使用隧道连接功能了")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else if 安装失败 {
                        Text(错误信息)
                            .font(.system(size: 14))
                            .foregroundColor(.危险色)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(步骤列表[min(安装步骤, 步骤列表.count - 1)])
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 40)

                // 步骤指示器
                if !安装完成 && !安装失败 {
                    HStack(spacing: 8) {
                        ForEach(0..<步骤列表.count, id: \.self) { 索引 in
                            Circle()
                                .fill(索引 <= 安装步骤 ? Color.主题色 : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                Spacer()

                // 按钮
                if 安装完成 || 安装失败 {
                    Button {
                        关闭()
                    } label: {
                        HStack {
                            Spacer()
                            Text(安装完成 ? "开始使用" : "关闭")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(安装完成 ? Color.成功色 : Color.危险色)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.页面背景.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                开始安装流程()
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 开始安装流程
    private func 开始安装流程() {
        安装步骤 = 0
        安装完成 = false
        安装失败 = false

        // 模拟步骤进度
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { 定时器 in
            if 安装步骤 < 步骤列表.count - 2 {
                安装步骤 += 1
            } else {
                定时器.invalidate()
            }
        }

        // 执行实际安装
        隧道管理.自动安装默认描述文件 { 成功, 错误 in
            DispatchQueue.main.async {
                if 成功 {
                    安装步骤 = 步骤列表.count - 1
                    安装完成 = true
                } else {
                    安装失败 = true
                    错误信息 = 错误 ?? "未知错误"
                }
            }
        }
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
