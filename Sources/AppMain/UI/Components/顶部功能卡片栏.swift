//
//  顶部功能卡片栏.swift
//  NewVPN
//
//  顶部横向滑动功能卡片导航栏
//  精确尺寸：卡片宽102pt × 高74pt，间距16pt，左边距12pt
//

import SwiftUI

/// 顶部横向滑动功能卡片栏
struct 顶部功能卡片栏: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    /// 卡片宽度（精确测量值）
    private let 卡片宽度: CGFloat = 102
    /// 卡片高度（精确测量值）
    private let 卡片高度: CGFloat = 74
    /// 卡片间距（精确测量值）
    private let 卡片间距: CGFloat = 16
    /// 左边距（精确测量值）
    private let 左边距: CGFloat = 12
    /// 卡片圆角
    private let 卡片圆角: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 卡片间距) {
                ForEach(顶部卡片类型.allCases) { 卡片类型 in
                    功能卡片(
                        类型: 卡片类型,
                        选中: 状态.当前顶部卡片 == 卡片类型,
                        宽度: 卡片宽度,
                        高度: 卡片高度,
                        圆角: 卡片圆角
                    ) {
                        状态.当前顶部卡片 = 卡片类型
                    }
                }
            }
            .padding(.horizontal, 左边距)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 单个功能卡片

/// 单个功能卡片组件
private struct 功能卡片: View {
    /// 卡片类型
    let 类型: 顶部卡片类型
    /// 是否选中
    let 选中: Bool
    /// 卡片宽度
    let 宽度: CGFloat
    /// 卡片高度
    let 高度: CGFloat
    /// 卡片圆角
    let 圆角: CGFloat
    /// 点击回调
    let 点击: () -> Void

    /// 全局应用状态（用于策略组卡片显示实时状态）
    @EnvironmentObject private var 状态: AppState

    /// 策略组当前选中节点（取第一个策略组）
    private var 策略组当前节点: String? {
        guard 类型 == .策略组,
              let 第一个组 = 状态.策略组列表.first,
              !第一个组.当前选中.isEmpty else { return nil }
        return 第一个组.当前选中
    }

    /// 策略组当前节点延迟
    private var 策略组延迟: String? {
        guard 类型 == .策略组,
              let 第一个组 = 状态.策略组列表.first,
              !第一个组.当前选中.isEmpty else { return nil }
        return 第一个组.延迟文本(第一个组.当前选中)
    }

    var body: some View {
        Button(action: 点击) {
            ZStack(alignment: .topTrailing) {
                // 卡片主体
                VStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Image(systemName: 类型.图标)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text(类型.标题)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    // 策略组卡片显示当前节点和延迟
                    if let 节点 = 策略组当前节点 {
                        HStack(spacing: 3) {
                            Text(节点)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                            if let 延迟 = 策略组延迟 {
                                Text(延迟)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 宽度, height: 高度)
                .background(类型.背景色)
                .cornerRadius(圆角)
                .overlay(
                    RoundedRectangle(cornerRadius: 圆角)
                        .stroke(选中 ? Color.white.opacity(0.8) : Color.clear, lineWidth: 2)
                )
                .shadow(color: 类型.背景色.opacity(选中 ? 0.4 : 0.2), radius: 选中 ? 8 : 4, y: 2)

                // 右上角状态圆点
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .padding(10)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(选中 ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: 选中)
    }
}

// MARK: - 预览

#Preview {
    顶部功能卡片栏()
        .environmentObject(AppState.共享)
        .background(Color.页面背景)
}
