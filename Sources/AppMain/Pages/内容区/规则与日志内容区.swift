//
//  规则与日志内容区.swift
//  NewVPN
//
//  重写规则、分流规则、日志三个内容区视图
//

import SwiftUI

// MARK: - 重写规则内容区

/// 重写规则内容区视图
struct 重写规则内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(状态.重写规则列表) { 规则 in
                重写规则行(规则: 规则)
            }
        }
        .padding(.horizontal, 15)
    }
}

/// 单个重写规则行
private struct 重写规则行: View {
    let 规则: 重写规则模型

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(规则.名称)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Toggle("", isOn: .constant(规则.启用))
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            HStack(spacing: 6) {
                Text(规则.重写类型)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.99, green: 0.33, blue: 0.63))
                    .cornerRadius(4)
                Text(规则.域名后缀)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Text(规则.匹配表达式)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 分流规则内容区

/// 分流规则内容区视图
struct 分流规则内容区: View {
    var body: some View {
        分流规则页面()
    }
}

// MARK: - 日志内容区

/// 日志内容区视图
struct 日志内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(状态.日志列表) { 日志 in
                日志行(日志: 日志)
                if 日志.id != 状态.日志列表.last?.id {
                    Divider()
                        .padding(.leading, 15)
                }
            }
        }
        .background(Color.卡片背景)
        .cornerRadius(12)
        .padding(.horizontal, 15)
    }
}

/// 单个日志行
private struct 日志行: View {
    let 日志: 日志模型

    /// 时间格式化器
    private let 时间格式: DateFormatter = {
        let 格式 = DateFormatter()
        格式.dateFormat = "HH:mm:ss"
        return 格式
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 级别圆点
            Circle()
                .fill(级别颜色(日志.级别))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(日志.模块)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(时间格式.string(from: 日志.时间))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Text(日志.内容)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }

    private func 级别颜色(_ 级别: 日志级别) -> Color {
        switch 级别 {
        case .致命: return Color(red: 0.56, green: 0.38, blue: 0.95)
        case .错误: return .危险色
        case .警告: return .警告色
        case .信息: return .主题色
        case .调试: return .secondary
        case .追踪: return .secondary
        }
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        重写规则内容区()
            .environmentObject(AppState.共享)
    }
    .background(Color.页面背景)
}
