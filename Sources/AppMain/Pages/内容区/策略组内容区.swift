//
//  策略组内容区.swift
//  NewVPN
//
//  策略组卡片对应的内容区：展示当前配置文件中定义的出站策略组（selector/urltest），
//  支持手动切换组内节点、查看组类型与延迟
//

import SwiftUI

/// 策略组内容区视图
struct 策略组内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 展开的组名集合
    @State private var 展开组集合: Set<String> = []

    var body: some View {
        VStack(spacing: 10) {
            if 状态.策略组列表.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无策略组")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("策略组由订阅或配置文件自动生成\n订阅节点后将自动出现选择器与自动测速组")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                // 策略组列表
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(状态.策略组列表) { 组 in
                            策略组卡片(
                                组: 组,
                                展开: 展开组集合.contains(组.名称)
                            ) {
                                切换展开(组.名称)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            策略组管理器.共享.开始轮询()
        }
        .onDisappear {
            策略组管理器.共享.停止轮询()
        }
    }

    /// 切换组展开状态
    private func 切换展开(_ 组名: String) {
        if 展开组集合.contains(组名) {
            展开组集合.remove(组名)
        } else {
            展开组集合.insert(组名)
        }
    }
}

// MARK: - 策略组卡片

/// 单个策略组卡片
private struct 策略组卡片: View {
    let 组: 策略组模型
    let 展开: Bool
    let 点击头部: () -> Void

    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 测速中节点名
    @State private var 测速中节点: String?
    /// 切换中节点名
    @State private var 切换中节点: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部
            Button(action: 点击头部) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        // 组名 + 类型标签
                        HStack(spacing: 8) {
                            Text(组.名称)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(组.类型标题)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(组.类型颜色)
                                .cornerRadius(4)
                        }

                        // 当前选中节点 + 延迟
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.成功色)
                                .font(.system(size: 14))
                            Text(组.当前选中)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            if !组.当前选中.isEmpty {
                                Text(组.延迟文本(组.当前选中))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(组.延迟颜色(组.当前选中))
                            }
                        }
                    }

                    Spacer()

                    // 右侧：节点数 + 展开箭头
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(组.节点数量)节点")
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                        Image(systemName: 展开 ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // 展开内容：节点列表
            if 展开 {
                Divider()
                    .padding(.horizontal, 14)

                VStack(spacing: 0) {
                    ForEach(Array(组.节点列表.enumerated()), id: \.element) { 索引, 节点名 in
                        节点行(
                            节点名: 节点名,
                            组: 组,
                            索引: 索引,
                            测速中: 测速中节点 == 节点名,
                            切换中: 切换中节点 == 节点名
                        ) {
                            切换节点(节点名)
                        } 测速回调: {
                            测速节点(节点名)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    /// 切换节点
    private func 切换节点(_ 节点名: String) {
        guard 节点名 != 组.当前选中 else { return }
        切换中节点 = 节点名
        策略组管理器.共享.切换节点(组名: 组.名称, 节点名: 节点名) { 成功 in
            切换中节点 = nil
            if !成功 {
                // 切换失败提示
            }
        }
    }

    /// 测速单个节点
    private func 测速节点(_ 节点名: String) {
        测速中节点 = 节点名
        策略组管理器.共享.测速单个节点(节点名: 节点名) { _ in
            测速中节点 = nil
        }
    }
}

// MARK: - 节点行

/// 节点行视图
private struct 节点行: View {
    let 节点名: String
    let 组: 策略组模型
    let 索引: Int
    let 测速中: Bool
    let 切换中: Bool
    let 切换回调: () -> Void
    let 测速回调: () -> Void

    /// 是否为当前选中
    private var 选中: Bool { 组.当前选中 == 节点名 }

    var body: some View {
        Button(action: 切换回调) {
            HStack(spacing: 12) {
                // 选中指示器
                Image(systemName: 选中 ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(选中 ? .成功色 : .secondary.opacity(0.4))
                    .font(.system(size: 18))

                // 节点名称
                Text(节点名)
                    .font(.system(size: 14))
                    .foregroundColor(选中 ? .primary : .次要文字)
                    .lineLimit(1)

                Spacer()

                // 延迟或测速状态
                if 测速中 {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if 切换中 {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text(组.延迟文本(节点名))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(组.延迟颜色(节点名))
                }

                // 测速按钮
                Button(action: 测速回调) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(测速中)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(选中 ? Color.成功色.opacity(0.08) : Color.clear)
    }
}

// MARK: - 策略组数据模型

/// 策略组模型（从 sing-box 配置或订阅解析得到）
struct 策略组模型: Identifiable {
    let id = UUID()
    /// 组名称（如 "代理"、"自动选择"）
    let 名称: String
    /// 组类型：selector / urltest
    let 类型: String
    /// 当前选中节点
    let 当前选中: String
    /// 组内节点数
    let 节点数量: Int
    /// 组内节点名称列表
    let 节点列表: [String]
    /// 节点延迟字典（节点名: 延迟毫秒）
    let 节点延迟: [String: Int]
    /// 是否正在测速
    var 测速中: Bool = false

    /// 类型中文标题
    var 类型标题: String {
        switch 类型 {
        case "selector": return "手动选择"
        case "urltest": return "自动测速"
        default: return 类型
        }
    }

    /// 类型标签颜色
    var 类型颜色: Color {
        switch 类型 {
        case "selector": return Color(red: 0.24, green: 0.77, blue: 0.82)
        case "urltest": return Color(red: 0.98, green: 0.72, blue: 0.20)
        default: return .gray
        }
    }

    /// 获取节点延迟显示文本
    func 延迟文本(_ 节点名: String) -> String {
        guard let 延迟 = 节点延迟[节点名] else { return "未测" }
        if 延迟 <= 0 { return "超时" }
        return "\(延迟)ms"
    }

    /// 获取节点延迟颜色
    func 延迟颜色(_ 节点名: String) -> Color {
        guard let 延迟 = 节点延迟[节点名] else { return .secondary }
        if 延迟 <= 0 { return .red }
        if 延迟 < 100 { return Color(red: 0.20, green: 0.80, blue: 0.40) }
        if 延迟 < 300 { return Color(red: 0.95, green: 0.70, blue: 0.20) }
        return .red
    }
}
