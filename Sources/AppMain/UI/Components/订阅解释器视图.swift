//
//  订阅解释器视图.swift
//  NewVPN
//
//  订阅解释器测试/预览视图
//  输入订阅内容，自动检测格式并解析，展示解析结果
//

import SwiftUI

/// 订阅解释器视图
struct 订阅解释器视图: View {
    /// 输入的订阅内容
    @State private var 输入内容 = ""
    /// 解析结果
    @State private var 解析结果: 订阅解析结果?
    /// 是否正在解析
    @State private var 解析中 = false
    /// 显示节点详情
    @State private var 选中节点: 解析节点模型?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 输入区域
                VStack(alignment: .leading, spacing: 8) {
                    Text("订阅内容")
                        .font(.system(size: 15, weight: .medium))

                    TextEditor(text: $输入内容)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color.卡片背景)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.分割线, lineWidth: 1)
                        )

                    HStack {
                        Button {
                            解析订阅()
                        } label: {
                            HStack(spacing: 6) {
                                if 解析中 {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text("解析订阅")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.主题色)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(输入内容.isEmpty || 解析中)

                        Button {
                            输入内容 = ""
                            解析结果 = nil
                        } label: {
                            Text("清空")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 15)

                // 解析结果
                if let 结果 = 解析结果 {
                    解析结果视图(结果: 结果, 选中节点: $选中节点)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.页面背景)
        .navigationTitle("订阅解释器")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $选中节点) { 节点 in
            节点详情视图(节点: 节点)
        }
    }

    // MARK: - 解析订阅

    private func 解析订阅() {
        解析中 = true

        DispatchQueue.global(qos: .userInitiated).async {
            let 结果 = 订阅解释器.共享.解析(输入内容)

            DispatchQueue.main.async {
                解析结果 = 结果
                解析中 = false
            }
        }
    }
}

// MARK: - 解析结果视图

/// 解析结果展示视图
private struct 解析结果视图: View {
    let 结果: 订阅解析结果
    @Binding var 选中节点: 解析节点模型?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 格式和统计
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("检测格式")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(结果.格式.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.主题色)
                }

                Spacer()

                // 统计
                HStack(spacing: 16) {
                    统计项(标签: "节点", 值: 结果.统计.总节点数, 颜色: .成功色)
                    统计项(标签: "警告", 值: 结果.统计.警告数, 颜色: .警告色)
                    统计项(标签: "错误", 值: 结果.统计.错误数, 颜色: .危险色)
                }
            }
            .padding(.horizontal, 15)

            // 节点列表
            if !结果.节点列表.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("节点列表（\(结果.节点列表.count)）")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 15)

                    LazyVStack(spacing: 8) {
                        ForEach(结果.节点列表) { 节点 in
                            Button {
                                选中节点 = 节点
                            } label: {
                                节点预览行(节点: 节点)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 15)
                }
            }

            // 错误列表
            if !结果.错误列表.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("解析错误（\(结果.错误列表.count)）")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.危险色)
                        .padding(.horizontal, 15)

                    ForEach(结果.错误列表) { 错误 in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 14))
                                .foregroundColor(.危险色)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(错误.描述)
                                    .font(.system(size: 13))
                                if let 行号 = 错误.行号 {
                                    Text("第\(行号)行")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.危险色.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 15)
                    }
                }
            }
        }
    }
}

// MARK: - 统计项

private struct 统计项: View {
    let 标签: String
    let 值: Int
    let 颜色: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(值)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(颜色)
            Text(标签)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 节点预览行

private struct 节点预览行: View {
    let 节点: 解析节点模型

    var body: some View {
        HStack(spacing: 10) {
            // 协议标签
            Text(节点.协议.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.主题色)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(节点.名称)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text("\(节点.地址):\(节点.端口)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !节点.解析警告.isEmpty {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14))
                    .foregroundColor(.警告色)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 节点详情视图

/// 节点详情弹窗
private struct 节点详情视图: View {
    let 节点: 解析节点模型
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    详情行(标签: "名称", 值: 节点.名称)
                    详情行(标签: "协议", 值: 节点.协议.rawValue)
                    详情行(标签: "地址", 值: 节点.地址)
                    详情行(标签: "端口", 值: "\(节点.端口)")
                    详情行(标签: "传输", 值: 节点.传输类型.rawValue)
                    详情行(标签: "TLS", 值: 节点.启用TLS ? "启用" : "关闭")
                    if let sni = 节点.服务器名称 {
                        详情行(标签: "SNI", 值: sni)
                    }
                    if let uuid = 节点.用户标识 {
                        详情行(标签: "UUID/密码", 值: uuid)
                    }
                }

                Section("分组与标签") {
                    详情行(标签: "分组", 值: 节点.分组)
                    详情行(标签: "标签", 值: 节点.标签.joined(separator: ", "))
                }

                if !节点.解析警告.isEmpty {
                    Section("解析警告") {
                        ForEach(节点.解析警告, id: \.self) { 警告 in
                            Text(警告)
                                .font(.system(size: 13))
                                .foregroundColor(.警告色)
                        }
                    }
                }

                if let 原始 = 节点.原始数据 {
                    Section("原始数据") {
                        Text(原始)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("节点详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        关闭()
                    }
                }
            }
        }
    }
}

/// 详情行
private struct 详情行: View {
    let 标签: String
    let 值: String

    var body: some View {
        HStack {
            Text(标签)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(值)
                .font(.system(size: 14))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        订阅解释器视图()
    }
}
