//
//  AppFormRow.swift
//  NewVPN
//
//  表单行组件：左侧标签，右侧控件，统一行高与对齐方式
//

import SwiftUI

/// 表单行：左侧标签 + 右侧控件，所有设置/编辑表单统一使用
struct AppFormRow<控件: View>: View {
    /// 左侧标签文字
    let 标签: String
    /// 辅助说明文字（标签下方小字）
    let 说明: String?
    /// 右侧控件
    private let 控件: () -> 控件

    /// 初始化表单行
    /// - Parameters:
    ///   - 标签: 左侧标签
    ///   - 说明: 标签下方辅助说明，传 nil 不显示
    ///   - 控件: 右侧控件（输入框、开关、选择器等）
    init(标签: String, 说明: String? = nil, @ViewBuilder 控件: @escaping () -> 控件) {
        self.标签 = 标签
        self.说明 = 说明
        self.控件 = 控件
    }

    var body: some View {
        HStack(alignment: .center, spacing: 间距常量.中等) {
            VStack(alignment: .leading, spacing: 2) {
                Text(标签)
                    .font(字体层级.正文)
                    .foregroundColor(.primary)

                if let 说明文字 = 说明 {
                    Text(说明文字)
                        .font(字体层级.辅助说明)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 间距常量.紧凑)

            控件()
        }
        .frame(minHeight: 间距常量.表单行高)
        .padding(.vertical, 间距常量.紧凑 / 2)
    }
}

// MARK: - 表单行预览

#Preview("输入框表单行") {
    VStack(spacing: 0) {
        AppFormRow(标签: "服务器地址", 说明: "节点的域名或 IP") {
            TextField("example.com", text: .constant(""))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
        }
        Divider().background(Color.分割线)
        AppFormRow(标签: "端口") {
            TextField("443", text: .constant(""))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)
        }
        Divider().background(Color.分割线)
        AppFormRow(标签: "自动重连") {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
    }
    .padding()
    .background(Color.卡片背景)
}
