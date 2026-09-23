//
//  订阅管理视图.swift
//  NewVPN
//
//  远程订阅管理视图：订阅列表、新增、更新、删除、自动更新
//

import SwiftUI

/// 远程订阅管理视图
struct 订阅管理视图: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 显示新增订阅弹窗
    @State private var 显示新增弹窗 = false
    /// 待删除的订阅（用于确认弹窗）
    @State private var 待删除订阅: 远程订阅模型?
    /// Toast 提示
    @State private var toast信息: String?
    @State private var toast显示 = false

    var body: some View {
        ZStack {
            if 状态.远程订阅列表.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无远程订阅")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("点击右上角 + 添加订阅链接")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 订阅列表
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach($状态.远程订阅列表) { $订阅 in
                            订阅行视图(
                                订阅: $订阅,
                                删除操作: { 待删除订阅 = 订阅 },
                                toast回调: { 信息 in 显示Toast(信息) }
                            )
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }

            // Toast 提示
            if toast显示, let 信息 = toast信息 {
                VStack {
                    Spacer()
                    Text(信息)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("远程订阅")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    显示新增弹窗 = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $显示新增弹窗) {
            新增订阅弹窗 { 新订阅 in
                状态.添加订阅(新订阅)
                显示Toast("订阅已添加")
            }
        }
        .alert(item: $待删除订阅) { 订阅 in
            Alert(
                title: Text("删除订阅"),
                message: Text("确定要删除「\(订阅.名称)」吗？本地配置文件也会被删除。"),
                primaryButton: .destructive(Text("删除")) {
                    状态.删除订阅(订阅)
                    显示Toast("订阅已删除")
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - Toast 方法

    /// 显示 Toast 提示
    private func 显示Toast(_ 信息: String) {
        toast信息 = 信息
        withAnimation(.easeInOut(duration: 0.2)) {
            toast显示 = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                toast显示 = false
            }
        }
    }
}

// MARK: - 订阅行视图

/// 单个订阅行视图
private struct 订阅行视图: View {
    /// 订阅数据绑定
    @Binding var 订阅: 远程订阅模型
    /// 全局状态
    @EnvironmentObject private var 状态: AppState
    /// 删除操作
    let 删除操作: () -> Void
    /// Toast 回调
    let toast回调: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一行：名称 + 状态
            HStack {
                Text(订阅.名称)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                状态标签(状态: 订阅.上次状态)
            }

            // 第二行：订阅地址
            Text(订阅.地址显示)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)

            // 第三行：上次更新时间 + 操作按钮
            HStack {
                Text("上次更新：\(订阅.上次更新显示)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // 手动更新按钮
                Button {
                    手动更新()
                } label: {
                    HStack(spacing: 4) {
                        if 订阅.上次状态.是否更新中 {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                        }
                        Text("更新")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.主题色)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.主题色.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(订阅.上次状态.是否更新中)

                // 自动更新开关
                Toggle("", isOn: $订阅.自动更新启用)
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .onChange(of: 订阅.自动更新启用) { 新值 in
                        状态.保存订阅列表()
                    }

                // 删除按钮
                Button {
                    删除操作()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.危险色)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    /// 手动更新订阅
    private func 手动更新() {
        状态.更新订阅(订阅ID: 订阅.id) { 结果 in
            switch 结果 {
            case .success:
                toast回调("「\(订阅.名称)」更新成功")
            case .failure(let 错误):
                toastCallback("更新失败：\(错误.localizedDescription)")
            }
        }
    }

    /// 修复回调命名（避免中文方法名冲突）
    private func toastCallback(_ 信息: String) {
        toast回调(信息)
    }
}

// MARK: - 状态标签

/// 订阅状态标签
private struct 状态标签: View {
    let 状态: 订阅状态

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(状态颜色)
                .frame(width: 6, height: 6)
            Text(状态.显示文字)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(状态颜色)
        }
    }

    private var 状态颜色: Color {
        switch 状态 {
        case .空闲: return .secondary
        case .更新中: return .主题色
        case .成功: return .成功色
        case .失败: return .危险色
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        订阅管理视图()
            .environmentObject(AppState.共享)
    }
}
