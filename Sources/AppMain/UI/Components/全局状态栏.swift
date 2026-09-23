//
//  全局状态栏.swift
//  NewVPN
//
//  常驻顶部状态栏：隧道开关、状态指示灯、当前节点、实时速率
//

import SwiftUI

/// 全局顶部状态栏，常驻所有页面
struct 全局状态栏: View {
    /// 全局状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        HStack(spacing: 间距常量.中等) {
            // 隧道开关按钮
            Button {
                状态.切换隧道()
            } label: {
                Image(systemName: 状态.隧道状态.是否活跃 ? "power.circle.fill" : "power.circle")
                    .font(.system(size: 22))
                    .foregroundColor(指示灯颜色)
            }
            .buttonStyle(.plain)

            // 状态指示灯 + 文字
            HStack(spacing: 6) {
                Circle()
                    .fill(指示灯颜色)
                    .frame(width: 8, height: 8)
                    .if(状态.隧道状态 == .连接中 || 状态.隧道状态 == .重连中) { 视图 in
                        视图.overlay(
                            Circle()
                                .stroke(指示灯颜色.opacity(0.4), lineWidth: 2)
                                .scaleEffect(1.8)
                                .opacity(0.6)
                        )
                    }

                Text(状态.隧道状态.显示文字)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }

            Divider().frame(height: 20)

            // 当前节点名称
            if let 节点 = 状态.当前节点 {
                Label(节点.名称, systemImage: "globe")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("未选择节点")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 实时上下行速率
            if 状态.隧道状态 == .运行中 {
                HStack(spacing: 间距常量.中等) {
                    速率显示(图标: "arrow.up", 速率: 状态.上行速率, 颜色: .成功色)
                    速率显示(图标: "arrow.down", 速率: 状态.下行速率, 颜色: .主题色)
                }
            }
        }
        .padding(.horizontal, 间距常量.标准)
        .padding(.vertical, 间距常量.紧凑)
        .background(.ultraThinMaterial)
    }

    /// 速率显示组件
    private func 速率显示(图标: String, 速率: Int64, 颜色: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: 图标)
                .font(.system(size: 10))
            Text(格式化速率(速率))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
        .foregroundColor(颜色)
    }

    /// 状态指示灯颜色
    private var 指示灯颜色: Color {
        switch 状态.隧道状态 {
        case .运行中:
            return .成功色
        case .连接中, .准备中, .重连中:
            return .警告色
        case .已断开:
            return .secondary
        case .错误:
            return .危险色
        }
    }

    /// 格式化速率显示
    private func 格式化速率(_ 字节: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowsNonnumericFormatting = false
        let 文字 = formatter.string(fromByteCount: 字节)
        return 文字.replacingOccurrences(of: "bytes", with: "B") + "/s"
    }
}

// MARK: - 条件修饰符扩展

extension View {
    /// 条件成立时应用修饰符
    @ViewBuilder
    func `if`<内容: View>(_ 条件: Bool, 应用: (Self) -> 内容) -> some View {
        if 条件 {
            应用(self)
        } else {
            self
        }
    }
}

// MARK: - 状态栏预览

#Preview("断开状态") {
    全局状态栏()
        .environmentObject(AppState.共享)
}

#Preview("运行状态") {
    全局状态栏()
        .environmentObject(AppState.共享)
}
