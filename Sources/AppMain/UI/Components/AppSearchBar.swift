//
//  AppSearchBar.swift
//  NewVPN
//
//  搜索栏组件：放大镜图标 + 输入框 + 清除按钮，所有列表统一复用
//

import SwiftUI

/// 搜索栏组件
struct AppSearchBar: View {
    /// 搜索文字绑定
    @Binding var 搜索文字: String
    /// 占位提示文字
    let 占位文字: String

    /// 是否正在编辑（用于控制取消按钮显示）
    @FocusState private var 输入框聚焦: Bool

    var body: some View {
        HStack(spacing: 间距常量.紧凑) {
            HStack(spacing: 间距常量.紧凑) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                TextField(占位文字, text: $搜索文字)
                    .font(字体层级.正文)
                    .focused($输入框聚焦)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)

                if !搜索文字.isEmpty {
                    Button {
                        搜索文字 = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 间距常量.中等)
            .padding(.vertical, 间距常量.紧凑)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 圆角常量.标准))

            if 输入框聚焦 {
                Button("取消") {
                    搜索文字 = ""
                    输入框聚焦 = false
                }
                .font(字体层级.正文)
                .foregroundColor(.主题色)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 动画常量.快速), value: 输入框聚焦)
        .padding(.horizontal, 间距常量.标准)
        .padding(.vertical, 间距常量.紧凑)
    }
}

// MARK: - 搜索栏预览

#Preview("空搜索栏") {
    AppSearchBar(搜索文字: .constant(""), 占位文字: "搜索节点名称")
        .background(Color.页面背景)
}

#Preview("有内容搜索栏") {
    AppSearchBar(搜索文字: .constant("香港"), 占位文字: "搜索节点名称")
        .background(Color.页面背景)
}
