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

            // 下载速度
            VStack(alignment: .trailing, spacing: 2) {
                if let 结果 = 结果, 结果.成功, let 下载 = 结果.下载速率Mbps {
                    Text(String(format: "%.0f", 下载))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.成功色)
                    Text("Mbps")
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

// MARK: - 批量测速进度条

/// 批量测速进度条组件
struct 批量测速进度条: View {
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器
    /// 取消回调
    let 取消: () -> Void

    var body: some View {
        if let 进度 = 测速管理器.批量进度 {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "gauge")
                        .font(.system(size: 14))
                        .foregroundColor(.主题色)
                    Text("正在测速")
                        .font(.system(size: 14, weight: .medium))
                    if let 当前 = 进度.当前节点名称 {
                        Text(当前)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(进度.进度显示)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.主题色)
                    Button {
                        取消()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                ProgressView(value: 进度.进度百分比)
                    .progressViewStyle(LinearProgressViewStyle(tint: .主题色))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.卡片背景)
            .cornerRadius(12)
            .padding(.horizontal, 15)
        }
    }
}

// MARK: - 测速类型选择器

/// 测速类型选择器
struct 测速类型选择器: View {
    /// 绑定选中类型
    @Binding var 选中类型: 测速类型

    var body: some View {
        Picker("测速类型", selection: $选中类型) {
            ForEach(测速类型.allCases, id: \.self) { 类型 in
                Text(类型.rawValue).tag(类型)
            }
        }
        .pickerStyle(.segmented)
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
                副标题: "完成测速后会在这里显示历史记录"
            )
        } else {
            List {
                ForEach(测速管理器.历史记录) { 记录 in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(格式化时间(记录.时间))
                                .font(.system(size: 14, weight: .medium))
                            Text("\(记录.节点数)个节点 · \(记录.类型.rawValue)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            if let 延迟 = 记录.平均延迟 {
                                Text("平均 \(延迟)ms")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.主题色)
                            }
                            if let 下载 = 记录.平均下载 {
                                Text(String(format: "%.1fMbps", 下载))
                                    .font(.system(size: 12))
                                    .foregroundColor(.成功色)
                            }
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
