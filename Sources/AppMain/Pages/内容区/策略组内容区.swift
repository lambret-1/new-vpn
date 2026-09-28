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
                            策略组卡片(组: 组)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - 策略组卡片

/// 单个策略组卡片
private struct 策略组卡片: View {
    let 组: 策略组模型

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 组名 + 类型标签
            HStack {
                Text(组.名称)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.主文字)
                Spacer()
                Text(组.类型标题)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.白色)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(组.类型颜色)
                    .cornerRadius(4)
            }

            // 当前选中节点
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.成功色)
                    .font(.system(size: 14))
                Text(组.当前选中)
                    .font(.system(size: 14))
                    .foregroundColor(.主文字)
            }

            // 节点数
            Text("共 \(组.节点数量) 个节点")
                .font(.system(size: 12))
                .foregroundColor(.次要文字)
        }
        .padding(14)
        .background(Color.卡片背景)
        .cornerRadius(12)
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
}
