//
//  测速组件.swift
//  NewVPN
//
//  测速相关 UI 组件
//  测速按钮、测速结果展示、批量测速进度
//

import SwiftUI

// MARK: - 测速按钮

/// 测速按钮组件
struct 测速按钮: View {
    /// 节点ID
    let 节点ID: UUID
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器
    /// 点击回调
    let 点击: () -> Void

    var body: some View {
        Button {
            点击()
        } label: {
            HStack(spacing: 4) {
                if 测速管理器.节点测速状态[节点ID]?.是否测速中 == true {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "gauge")
                        .font(.system(size: 14, weight: .medium))
                }
                Text("测速")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.主题色)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.主题色.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(测速管理器.节点测速状态[节点ID]?.是否测速中 == true)
    }
}

// MARK: - 测速结果展示

/// 节点测速结果展示组件
struct 测速结果展示: View {
    /// 节点ID
    let 节点ID: UUID
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    var body: some View {
        let 状态 = 测速管理器.节点测速状态[节点ID] ?? .未测速
        let 结果 = 测速管理器.测速结果缓存[节点ID]

        HStack(spacing: 16) {
            // 延迟
            VStack(alignment: .trailing, spacing: 2) {
                if 状态.是否测速中 {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                        .scaleEffect(0.7)
                } else if let 结果 = 结果, 结果.成功 {
                    Text("\(结果.延迟毫秒 ?? 0)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(结果.延迟颜色)
                    Text("ms")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("-")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50)
        }
    }
}

// MARK: - 测速历史记录视图

/// 测速历史记录列表
struct 测速历史记录视图: View {
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    var body: some View {
        if 测速管理器.历史记录.isEmpty {
            EmptyStateView(
                图标: "clock",
                标题: "暂无测速记录",
                说明: "完成测速后会在这里显示历史记录"
            )
        } else {
            List {
                ForEach(测速管理器.历史记录) { 记录 in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(格式化时间(记录.时间))
                                .font(.system(size: 14, weight: .medium))
                            Text("\(记录.节点数)个节点")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let 延迟 = 记录.平均延迟 {
                            Text("平均 \(延迟)ms")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.主题色)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    /// 格式化时间
    private func 格式化时间(_ 时间: Date) -> String {
        let 格式 = DateFormatter()
        格式.dateFormat = "MM/dd HH:mm:ss"
        return 格式.string(from: 时间)
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        测速按钮(节点ID: UUID()) {}
            .environmentObject(测速管理器.共享)
        测速结果展示(节点ID: UUID())
            .environmentObject(测速管理器.共享)
    }
    .padding()
    .background(Color.页面背景)
}
