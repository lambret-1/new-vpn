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

    var body: some View {
        Button(action: 点击) {
            ZStack(alignment: .topTrailing) {
                // 卡片主体
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Image(systemName: 类型.图标)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    Text(类型.标题)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
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
