//
//  底部工具栏.swift
//  NewVPN
//
//  底部固定工具栏，5个功能入口
//  点击图标从底部弹出90%高度弹窗
//

import SwiftUI

/// 底部固定工具栏
struct 底部工具栏: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    /// 工具栏高度
    private let 工具栏高度: CGFloat = 56
    /// 图标大小
    private let 图标大小: CGFloat = 22
    /// 左右边距
    private let 左右边距: CGFloat = 20

    var body: some View {
        HStack(spacing: 0) {
            ForEach(底部弹窗类型.allCases) { 弹窗类型 in
                Spacer()
                Button {
                    状态.当前底部弹窗 = 弹窗类型
                } label: {
                    Image(systemName: 弹窗类型.图标)
                        .font(.system(size: 图标大小, weight: .regular))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
            }
        }
        .padding(.horizontal, 左右边距)
        .frame(height: 工具栏高度)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            // 顶部分割线
            Rectangle()
                .fill(Color.分割线)
                .frame(height: 0.5)
        }
    }
}

// MARK: - 预览

#Preview {
    VStack {
        Spacer()
        底部工具栏()
            .environmentObject(AppState.共享)
    }
    .background(Color.页面背景)
}
