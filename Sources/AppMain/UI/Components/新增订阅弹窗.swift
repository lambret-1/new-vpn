//
//  新增订阅弹窗.swift
//  NewVPN
//
//  新增远程订阅表单弹窗
//

import SwiftUI

/// 新增订阅弹窗
struct 新增订阅弹窗: View {
    /// 环境变量用于关闭弹窗
    @Environment(\.dismiss) private var 关闭
    /// 订阅名称
    @State private var 名称 = ""
    /// 订阅地址
    @State private var 地址 = ""
    /// 自定义 User-Agent
    @State private var 自定义UA = ""
    /// 是否显示高级选项
    @State private var 显示高级选项 = false
    /// 保存回调
    let 保存回调: (远程订阅模型) -> Void
    /// 错误提示
    @State private var 错误信息: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    // 订阅名称
                    HStack {
                        Text("名称")
                            .font(.system(size: 15))
                        TextField("请输入订阅名称", text: $名称)
                            .font(.system(size: 15))
                            .multilineTextAlignment(.trailing)
                    }

                    // 订阅地址
                    VStack(alignment: .leading, spacing: 6) {
                        Text("订阅地址")
                            .font(.system(size: 15))
                        TextField("https://example.com/sub", text: $地址)
                            .font(.system(size: 14))
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        if let 错误 = 错误信息 {
                            Text(错误)
                                .font(.system(size: 12))
                                .foregroundColor(.危险色)
                        }
                    }
                }

                Section {
                    // 高级选项开关
                    Button {
                        withAnimation(.easeInOut) {
                            显示高级选项.toggle()
                        }
                    } label: {
                        HStack {
                            Text("高级选项")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: 显示高级选项 ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    if 显示高级选项 {
                        // 自定义 UA
                        HStack {
                            Text("User-Agent")
                                .font(.system(size: 15))
                            TextField("默认 NewVPN/1.0", text: $自定义UA)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        // 提示
                        Text("自定义请求头可在订阅详情中配置")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("新增订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        关闭()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        保存订阅()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .disabled(!表单有效)
                }
            }
        }
    }

    // MARK: - 表单验证

    /// 表单是否有效
    private var 表单有效: Bool {
        !名称.trimmingCharacters(in: .whitespaces).isEmpty &&
        !地址.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 保存订阅
    private func 保存订阅() {
        // 验证 URL 格式
        guard let url = URL(string: 地址.trimmingCharacters(in: .whitespaces)),
              url.scheme == "http" || url.scheme == "https" else {
            错误信息 = "请输入有效的 http/https 地址"
            return
        }

        var 新订阅 = 远程订阅模型(
            名称: 名称.trimmingCharacters(in: .whitespaces),
            地址: 地址.trimmingCharacters(in: .whitespaces)
        )

        if !自定义UA.trimmingCharacters(in: .whitespaces).isEmpty {
            新订阅.自定义UA = 自定义UA.trimmingCharacters(in: .whitespaces)
        }

        保存回调(新订阅)
        关闭()
    }
}

// MARK: - 预览

#Preview {
    新增订阅弹窗 { _ in }
}
