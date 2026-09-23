//
//  StateBadge.swift
//  NewVPN
//
//  状态标签组件：圆角小标签，四种语义颜色
//

import SwiftUI

/// 状态标签类型
enum StateBadge类型 {
    /// 成功/正常
    case 成功
    /// 警告/注意
    case 警告
    /// 错误/危险
    case 错误
    /// 信息/中性
    case 信息

    /// 对应颜色
    var 颜色: Color {
        switch self {
        case .成功: return .成功色
        case .警告: return .警告色
        case .错误: return .危险色
        case .信息: return .主题色
        }
    }
}

/// 状态标签组件：小圆角背景 + 文字
struct StateBadge: View {
    /// 标签文字
    let 文字: String
    /// 标签类型
    let 类型: StateBadge类型
    /// 是否带圆点图标
    let 带圆点: Bool

    var body: some View {
        HStack(spacing: 4) {
            if 带圆点 {
                Circle()
                    .fill(类型.颜色)
                    .frame(width: 6, height: 6)
            }

            Text(文字)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(类型.颜色)
        }
        .padding(.horizontal, 间距常量.紧凑)
        .padding(.vertical, 4)
        .background(类型.颜色.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 圆角常量.小))
    }
}

// MARK: - 状态标签预览

#Preview("状态标签集合") {
    VStack(alignment: .leading, spacing: 间距常量.紧凑) {
        HStack {
            StateBadge(文字: "运行中", 类型: .成功, 带圆点: true)
            StateBadge(文字: "连接中", 类型: .警告, 带圆点: true)
        }
        HStack {
            StateBadge(文字: "已断开", 类型: .错误, 带圆点: true)
            StateBadge(文字: "未启用", 类型: .信息, 带圆点: false)
        }
    }
    .padding()
    .background(Color.卡片背景)
}
