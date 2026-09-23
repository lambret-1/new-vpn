//
//  AppCard.swift
//  NewVPN
//
//  卡片容器组件：统一卡片背景、圆角、标题栏、折叠功能
//

import SwiftUI

/// 卡片容器：所有页面内容区块统一使用本组件
struct AppCard<内容类型: View>: View {
    /// 卡片标题
    let 标题: String?
    /// 是否可折叠
    let 可折叠: Bool
    /// 卡片内容
    private let 内容闭包: () -> 内容类型

    /// 折叠状态
    @State private var 已折叠: Bool = false

    /// 初始化卡片
    /// - Parameters:
    ///   - 标题: 卡片标题，传 nil 不显示标题栏
    ///   - 可折叠: 是否允许点击标题栏折叠内容
    ///   - 内容: 卡片主体内容
    init(标题: String? = nil,
         可折叠: Bool = false,
         @ViewBuilder 内容: @escaping () -> 内容类型) {
        self.标题 = 标题
        self.可折叠 = 可折叠
        self.内容闭包 = 内容
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let 标题文字 = 标题 {
                标题栏(标题文字: 标题文字)
            }

            if !可折叠 || !已折叠 {
                内容闭包()
                    .padding(间距常量.标准)
            }
        }
        .background(Color.卡片背景)
        .clipShape(RoundedRectangle(cornerRadius: 圆角常量.标准))
        .overlay(
            RoundedRectangle(cornerRadius: 圆角常量.标准)
                .stroke(Color.分割线, lineWidth: 0.5)
        )
    }

    /// 卡片标题栏
    @ViewBuilder
    private func 标题栏(标题文字: String) -> some View {
        HStack {
            Text(标题文字)
                .font(字体层级.卡片标题)
                .foregroundColor(.primary)

            Spacer()

            if 可折叠 {
                Image(systemName: 已折叠 ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 间距常量.紧凑)
            }
        }
        .padding(.horizontal, 间距常量.标准)
        .padding(.vertical, 间距常量.中等)
        .contentShape(Rectangle())
        .onTapGesture {
            guard 可折叠 else { return }
            withAnimation(.easeInOut(duration: 动画常量.快速)) {
                已折叠.toggle()
            }
        }

        if !可折叠 || !已折叠 {
            Divider().background(Color.分割线)
        }
    }
}

// MARK: - 卡片预览

#Preview("普通卡片") {
    AppCard(标题: "代理状态") {
        Text("隧道运行中")
            .font(字体层级.正文)
    }
    .padding()
    .background(Color.页面背景)
}

#Preview("可折叠卡片") {
    AppCard(标题: "高级设置", 可折叠: true) {
        Text("这里是高级配置内容")
            .font(字体层级.正文)
    }
    .padding()
    .background(Color.页面背景)
}
