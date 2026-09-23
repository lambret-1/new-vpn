//
//  节点内容区.swift
//  NewVPN
//
//  节点卡片对应的内容区：分组列表 + 展开节点详情
//  分组左侧图标点击测速，分组行点击展开/折叠
//

import SwiftUI

/// 节点内容区视图
struct 节点内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach($状态.节点分组列表) { $分组 in
                分组行视图(分组: $分组)
            }
        }
        .padding(.horizontal, 15)
    }
}

// MARK: - 分组行视图

/// 节点分组行视图
private struct 分组行视图: View {
    /// 分组数据绑定
    @Binding var 分组: 节点分组模型
    /// 全局状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 分组标题行
            HStack(spacing: 12) {
                // 左侧测速图标按钮
                Button {
                    状态.执行分组测速(分组ID: 分组.id)
                } label: {
                    ZStack {
                        if 分组.测速中 {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                        } else {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.主题色)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(分组.测速中)

                // 分组名称
                Text(分组.名称)
                    .font(.system(size: 15, weight: .medium))

                Spacer()

                // 节点数量 + 展开箭头
                HStack(spacing: 8) {
                    Text("\(分组.节点数量)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Image(systemName: 分组.是否展开 ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.卡片背景)
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    分组.是否展开.toggle()
                }
            }

            // 展开的节点列表
            if 分组.是否展开 {
                VStack(spacing: 8) {
                    ForEach(分组.节点列表) { 节点 in
                        节点行视图(节点: 节点)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - 节点行视图

/// 单个节点行视图
private struct 节点行视图: View {
    /// 节点数据
    let 节点: 节点模型

    var body: some View {
        HStack(spacing: 10) {
            // 左侧：协议 + 名称 + 标签
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(节点.协议.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.主题色)
                        .cornerRadius(4)
                    Text(节点.地址)
                        .font(.system(size: 14))
                        .lineLimit(1)
                }
                Text(节点.标签.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 右侧：测速信息
            if let 测速 = 节点.测速数据, 测速.成功 {
                HStack(spacing: 16) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f", 测速.下载速率 ?? 0))
                            .font(.system(size: 14, weight: .medium))
                        Text("Mbps")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(测速.延迟毫秒 ?? 0)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(延迟颜色(测速.延迟毫秒 ?? 0))
                        Text("ms")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("未测速")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    /// 根据延迟返回颜色
    private func 延迟颜色(_ 延迟: Int) -> Color {
        switch 延迟 {
        case 0..<100: return .成功色
        case 100..<200: return .警告色
        default: return .危险色
        }
    }
}

// MARK: - 预览

#Preview {
    节点内容区()
        .environmentObject(AppState.共享)
        .background(Color.页面背景)
}
