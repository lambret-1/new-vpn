//
//  EmptyStateView.swift
//  NewVPN
//
//  空状态占位组件：图标 + 提示文字 + 可选操作按钮
//

import SwiftUI

/// 空状态占位视图：所有列表无数据时统一使用
struct EmptyStateView: View {
    /// SF Symbol 图标名称
    let 图标: String
    /// 提示标题
    let 标题: String
    /// 详细说明文字
    let 说明: String?
    /// 操作按钮文字（传 nil 不显示按钮）
    let 按钮文字: String?
    /// 按钮点击回调
    private let 按钮动作: (() -> Void)?

    /// 初始化空状态视图
    /// - Parameters:
    ///   - 图标: SF Symbol 图标名称
    ///   - 标题: 主要提示文字
    ///   - 说明: 补充说明文字
    ///   - 按钮文字: 操作按钮文字
    ///   - 按钮动作: 按钮点击执行闭包
    init(图标: String,
         标题: String,
         说明: String? = nil,
         按钮文字: String? = nil,
         按钮动作: (() -> Void)? = nil) {
        self.图标 = 图标
        self.标题 = 标题
        self.说明 = 说明
        self.按钮文字 = 按钮文字
        self.按钮动作 = 按钮动作
    }

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            Image(systemName: 图标)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text(标题)
                .font(字体层级.卡片标题)
                .foregroundColor(.secondary)

            if let 说明文字 = 说明 {
                Text(说明文字)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            if let 文字 = 按钮文字, let 动作 = 按钮动作 {
                AppButton(文字, 样式: .次要, 全宽: false, 动作: 动作)
                    .padding(.top, 间距常量.紧凑)
            }
        }
        .padding(间距常量.宽松)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 空状态预览

#Preview("无节点空状态") {
    EmptyStateView(
        图标: "server.rack",
        标题: "暂无节点",
        说明: "点击下方按钮手动添加节点，或前往订阅管理导入订阅",
        按钮文字: "新增节点"
    ) {}
    .background(Color.页面背景)
}

#Preview("无数据空状态") {
    EmptyStateView(
        图标: "tray",
        标题: "暂无抓包记录",
        说明: "启动隧道后即可捕获 HTTP 流量"
    )
    .background(Color.页面背景)
}
