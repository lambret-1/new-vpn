//
//  MITM设置页面.swift
//  NewVPN
//
//  MITM（HTTPS 中间人解密）设置页面
//

import SwiftUI

// MARK: - MITM 设置页面

/// MITM 设置页面
struct MITM设置页面: View {
    @EnvironmentObject private var mitm管理: MITM管理器
    @Environment(\.dismiss) private var 关闭

    @State private var 显示导出证书 = false
    @State private var 显示确认清除 = false

    var body: some View {
        NavigationStack {
            Form {
                // 功能开关
                Section {
                    Toggle("启用 MITM 解密", isOn: $mitm管理.启用)
                        .tint(.主题色)

                    if mitm管理.启用 && !mitm管理.证书已生成 {
                        Text("请先生成 CA 证书")
                            .font(.system(size: 13))
                            .foregroundColor(.危险色)
                    }
                } header: {
                    Text("功能开关")
                } footer: {
                    Text("启用后，HTTP/HTTPS 流量将被解密并记录。需要安装 CA 证书到系统并信任。")
                }

                // CA 证书管理
                Section {
                    if mitm管理.证书已生成 {
                        // 证书状态
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.成功色)
                            Text("CA 证书已生成")
                                .foregroundColor(.成功色)
                            Spacer()
                        }

                        // 导出/分享证书
                        Button {
                            显示导出证书 = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.主题色)
                                Text("导出/分享 CA 证书")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 重新生成证书
                        Button {
                            mitm管理.生成CA证书()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.警告色)
                                Text("重新生成 CA 证书")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }

                        // 清除证书
                        Button(role: .destructive) {
                            显示确认清除 = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("清除 CA 证书")
                                Spacer()
                            }
                        }
                    } else {
                        // 生成证书
                        Button {
                            mitm管理.生成CA证书()
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.主题色)
                                Text("生成 CA 证书")
                                    .foregroundColor(.主题色)
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("CA 证书管理")
                } footer: {
                    Text("CA 证书用于解密 HTTPS 流量。生成后需要导出并安装到系统，在「设置 > 通用 > 关于 > 证书信任设置」中信任。")
                }

                // 使用说明
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        说明行(序号: 1, 内容: "生成 CA 证书")
                        说明行(序号: 2, 内容: "导出并安装 CA 证书到系统")
                        说明行(序号: 3, 内容: "在系统设置中信任 CA 证书")
                        说明行(序号: 4, 内容: "启用 MITM 解密功能")
                        说明行(序号: 5, 内容: "连接 VPN 后即可解密 HTTPS 流量")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("使用步骤")
                }

                // 注意事项
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("⚠️ 注意事项")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.警告色)
                        Text("• MITM 解密仅用于合法的网络调试和分析")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("• 部分应用使用证书锁定(Certificate Pinning)，无法解密")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("• 银行、支付等敏感应用建议加入白名单不解密")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("• 请妥善保管 CA 私钥，泄露可能导致安全风险")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("安全提示")
                }
            }
            .navigationTitle("MITM 解密")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { 关闭() }
                }
            }
            .sheet(isPresented: $显示导出证书) {
                if let 证书数据 = mitm管理.导出证书数据() {
                    证书导出视图(证书数据: 证书数据)
                }
            }
            .alert("确认清除", isPresented: $显示确认清除) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    mitm管理.清除证书()
                }
            } message: {
                Text("清除后需要重新生成 CA 证书并安装，确定要清除吗？")
            }
        }
    }
}

// MARK: - 说明行

private extension MITM设置页面 {
    func 说明行(序号: Int, 内容: String) -> some View {
        HStack(spacing: 10) {
            Text("\(序号)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.主题色))
            Text(内容)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

// MARK: - 证书导出视图

/// 证书导出视图（用于分享/保存 CA 证书）
private struct 证书导出视图: View {
    let 证书数据: Data
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.主题色)
                    .padding(.top, 40)

                Text("CA 证书")
                    .font(.system(size: 20, weight: .medium))

                Text("大小：\(证书数据.count) 字节")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                // 分享按钮
                ShareLink(item: 证书数据, preview: SharePreview("CA证书.crt", image: Image(systemName: "doc.text.fill"))) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享证书")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.主题色)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 30)

                // 保存到文件按钮
                Button {
                    保存到文件()
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("保存到文件")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.主题色)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.主题色.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 30)

                Spacer()
            }
            .navigationTitle("导出证书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { 关闭() }
                }
            }
        }
    }

    /// 保存到文件（临时目录）
    private func 保存到文件() {
        let 临时路径 = FileManager.default.temporaryDirectory.appendingPathComponent("CA证书.crt")
        do {
            try 证书数据.write(to: 临时路径)
            // 这里可以调用文档选择器保存，简化处理
            NSLog("[MITM] 证书已保存到临时目录: \(临时路径.path)")
        } catch {
            NSLog("[MITM] 保存证书失败: \(error)")
        }
    }
}
