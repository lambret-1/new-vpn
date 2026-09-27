//
//  MITM设置页面.swift
//  NewVPN
//
//  MITM（HTTPS 中间人解密）设置页面
//  智能证书状态检测，证书就绪时跳过生成引导
//

import SwiftUI

// MARK: - MITM 设置页面

/// MITM 设置页面
struct MITM设置页面: View {
    @EnvironmentObject private var mitm管理: MITM管理器
    @Environment(\.dismiss) private var 关闭

    @State private var 显示导出证书 = false
    @State private var 显示确认清除 = false
    @State private var 显示证书日志 = false
    @State private var 显示临近过期提示 = false

    var body: some View {
        NavigationStack {
            Form {
                // 功能开关
                Section {
                    Toggle("启用 MITM 解密", isOn: $mitm管理.启用)
                        .tint(.主题色)
                        .disabled(!mitm管理.证书可启用)

                    // 开关置灰时的提示
                    if !mitm管理.证书可启用 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.警告色)
                            Text("证书文件缺失或已过期，无法启用 MITM，请先生成证书")
                                .font(.system(size: 12))
                                .foregroundColor(.警告色)
                        }
                        .padding(.vertical, 2)
                    }

                    // 根据证书状态显示不同提示
                    if mitm管理.启用 {
                        证书状态提示
                    }
                } header: {
                    Text("功能开关")
                } footer: {
                    Text("启用后，HTTP/HTTPS 流量将被解密并记录。需要安装 CA 证书到系统并信任。")
                }

                // 证书状态卡片
                Section {
                    证书状态卡片
                }

                // CA 证书管理
                Section {
                    if mitm管理.证书文件存在 && mitm管理.证书已生成 {
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

                        // 手动兜底确认按钮（仅系统探测失败时显示）
                        if mitm管理.使用手动兜底 {
                            // 标记已安装（仅未安装时显示）
                            if !mitm管理.综合已安装 {
                                Button {
                                    mitm管理.标记已安装()
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.blue)
                                        Text("我已安装描述文件（手动确认）")
                                            .foregroundColor(.blue)
                                        Spacer()
                                    }
                                }
                            }

                            // 标记已信任（仅已安装但未信任时显示）
                            if mitm管理.综合已安装 && !mitm管理.综合已信任 {
                                Button {
                                    mitm管理.标记已信任()
                                } label: {
                                    HStack {
                                        Image(systemName: "hand.thumbsup")
                                            .foregroundColor(.green)
                                        Text("我已在设置中信任证书（手动确认）")
                                            .foregroundColor(.green)
                                        Spacer()
                                    }
                                }
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

                        // 手动重置证书（底部）
                        Button(role: .destructive) {
                            显示确认清除 = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("手动重置证书")
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
                    Text(mitm管理.证书文件存在 ? "证书就绪后无需重复生成。手动重置用于证书损坏或需要更换证书的场景。" : "证书文件缺失，请先生成 CA 证书。")
                }

                // 证书元数据（仅文件存在时显示）
                if mitm管理.证书文件存在, let 元数据 = mitm管理.元数据 {
                    Section {
                        HStack {
                            Text("指纹")
                            Spacer()
                            Text(String(元数据.指纹.prefix(16)) + "...")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        HStack {
                            Text("创建时间")
                            Spacer()
                            Text(格式化日期(元数据.创建时间))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("过期时间")
                            Spacer()
                            Text(格式化日期(元数据.过期时间))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("剩余天数")
                            Spacer()
                            Text("\(元数据.剩余天数) 天")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(元数据.临近过期 ? .警告色 : .secondary)
                        }
                    } header: {
                        Text("证书信息")
                    }
                }

                // 证书日志
                Section {
                    Button {
                        显示证书日志 = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.secondary)
                            Text("查看证书日志")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(mitm管理.获取证书日志().count) 条")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 使用说明
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        说明行(序号: 1, 内容: "生成 CA 证书（仅首次）")
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
                        Text("注意事项")
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
            .sheet(isPresented: $显示证书日志) {
                证书日志页面()
                    .environmentObject(mitm管理)
            }
            .alert("确认重置", isPresented: $显示确认清除) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    mitm管理.清除证书()
                }
            } message: {
                Text("重置后将删除本地证书并需要重新生成安装，确定要重置吗？")
            }
            .alert("证书临近过期", isPresented: $显示临近过期提示) {
                Button("稍后提醒", role: .cancel) {}
                Button("立即更新") {
                    mitm管理.生成CA证书()
                }
            } message: {
                if let 元数据 = mitm管理.元数据 {
                    Text("证书将在 \(元数据.剩余天数) 天后过期，建议提前更新以避免 MITM 解密中断。")
                }
            }
            .onAppear {
                // 进入页面时执行完整检测（记录持久化状态读取结果）
                mitm管理.页面出现时检测()
                // 检查是否临近过期
                if mitm管理.需要提示临近过期() {
                    显示临近过期提示 = true
                }
            }
        }
    }

    // MARK: - 证书状态提示

    private var 证书状态提示: some View {
        HStack(spacing: 8) {
            Image(systemName: 状态图标)
                .foregroundColor(状态颜色)
            Text(mitm管理.当前状态.描述)
                .font(.system(size: 13))
                .foregroundColor(状态颜色)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var 状态图标: String {
        switch mitm管理.当前状态 {
        case .就绪: return "checkmark.seal.fill"
        case .未安装: return "arrow.down.doc"
        case .未信任: return "hand.raised"
        case .文件缺失: return "exclamationmark.triangle"
        case .已过期: return "clock.badge.xmark"
        case .文件损坏: return "xmark.seal"
        case .临近过期: return "clock.badge.exclamationmark"
        }
    }

    private var 状态颜色: Color {
        switch mitm管理.当前状态 {
        case .就绪: return .green
        case .未安装, .未信任: return .blue
        case .文件缺失, .已过期, .文件损坏: return .危险色
        case .临近过期: return .警告色
        }
    }

    // MARK: - 证书状态卡片

    private var 证书状态卡片: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: 状态图标)
                    .font(.system(size: 24))
                    .foregroundColor(状态颜色)
                VStack(alignment: .leading, spacing: 2) {
                    Text("证书状态")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(mitm管理.当前状态.描述)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(状态颜色)
                }
                Spacer()
            }

            // 独立状态标签（替代单选圆圈，避免用户误解）
            HStack(spacing: 8) {
                状态标签(标题: "已生成", 完成: mitm管理.证书文件存在 && mitm管理.证书已生成)
                状态标签(标题: "已安装", 完成: mitm管理.综合已安装)
                状态标签(标题: "已信任", 完成: mitm管理.综合已信任)
            }
        }
        .padding(14)
        .background(卡片背景色)
        .cornerRadius(10)
    }

    /// 独立状态标签（胶囊样式，非单选圆圈）
    private func 状态标签(标题: String, 完成: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: 完成 ? "checkmark" : "minus")
                .font(.system(size: 10, weight: .bold))
            Text(标题)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(完成 ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
        .foregroundColor(完成 ? .green : .secondary)
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }

    /// 卡片背景色：就绪绿色，异常红色/黄色
    private var 卡片背景色: Color {
        switch mitm管理.当前状态 {
        case .就绪:
            return Color.green.opacity(0.08)
        case .未安装, .未信任:
            return Color.blue.opacity(0.06)
        case .文件缺失, .已过期, .文件损坏:
            return Color.危险色.opacity(0.08)
        case .临近过期:
            return Color.警告色.opacity(0.08)
        }
    }

    // MARK: - 辅助方法

    private func 格式化日期(_ 日期: Date) -> String {
        let 格式化器 = DateFormatter()
        格式化器.dateFormat = "yyyy-MM-dd"
        return 格式化器.string(from: 日期)
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

// MARK: - 证书日志页面

/// 证书日志页面
private struct 证书日志页面: View {
    @EnvironmentObject private var mitm管理: MITM管理器
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationStack {
            List {
                if mitm管理.获取证书日志().isEmpty {
                    Section {
                        Text("暂无日志")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    ForEach(mitm管理.获取证书日志()) { 日志 in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: 日志图标(日志.类型))
                                .foregroundColor(日志颜色(日志.类型))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(日志.消息)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                Text(格式化时间(日志.时间))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("证书日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { 关闭() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        mitm管理.清空证书日志()
                    } label: {
                        Text("清空")
                            .foregroundColor(.危险色)
                    }
                }
            }
        }
    }

    private func 日志图标(_ 类型: String) -> String {
        switch 类型 {
        case "success": return "checkmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "error": return "xmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func 日志颜色(_ 类型: String) -> Color {
        switch 类型 {
        case "success": return .green
        case "warning": return .警告色
        case "error": return .危险色
        default: return .blue
        }
    }

    private func 格式化时间(_ 日期: Date) -> String {
        let 格式化器 = DateFormatter()
        格式化器.dateFormat = "MM-dd HH:mm:ss"
        return 格式化器.string(from: 日期)
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
            NSLog("[MITM] 证书已保存到临时目录: \(临时路径.path)")
        } catch {
            NSLog("[MITM] 保存证书失败: \(error)")
        }
    }
}
