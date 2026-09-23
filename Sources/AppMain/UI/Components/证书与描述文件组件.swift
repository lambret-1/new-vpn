//
//  证书与描述文件组件.swift
//  NewVPN
//
//  CA 证书和 VPN 描述文件相关 UI 组件
//

import SwiftUI
import NetworkExtension

// MARK: - 证书与描述文件主页面

/// 证书与描述文件主页面
struct 证书与描述文件页面: View {
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @State private var 当前分段 = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分段选择器
                Picker("", selection: $当前分段) {
                    Text("CA 证书").tag(0)
                    Text("VPN 描述文件").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // 内容区
                TabView(selection: $当前分段) {
                    CA证书列表页面()
                        .tag(0)
                    VPN描述文件列表页面()
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: 当前分段)
            }
            .background(Color.页面背景)
            .navigationTitle("证书与描述文件")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - CA 证书列表页面

/// CA 证书列表页面
struct CA证书列表页面: View {
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @State private var 显示导入弹窗 = false
    @State private var 选中证书: CA证书模型?

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            AppSearchBar(搜索文字: $管理.搜索关键词, 占位文字: "搜索证书")
                .padding(.horizontal, 15)
                .padding(.vertical, 8)

            // 统计栏
            统计栏
                .padding(.horizontal, 15)
                .padding(.bottom, 8)

            if 管理.是否加载中 {
                Spacer()
                ProgressView("加载中...")
                Spacer()
            } else if 管理.筛选后的证书列表.isEmpty {
                EmptyStateView(
                    图标: "shield",
                    标题: "暂无 CA 证书",
                    说明: "点击右上角导入证书，用于 HTTPS 抓包和 MITM 代理"
                )
            } else {
                List {
                    ForEach(管理.筛选后的证书列表) { 证书 in
                        证书行(证书: 证书, 选中: $选中证书)
                            .listRowInsets(EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 15))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.页面背景)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    显示导入弹窗 = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.主题色)
                }
            }
        }
        .sheet(isPresented: $显示导入弹窗) {
            证书导入页面()
                .environmentObject(管理)
        }
        .sheet(item: $选中证书) { 证书 in
            证书详情页面(证书: 证书)
                .environmentObject(管理)
        }
    }

    /// 统计栏
    private var 统计栏: some View {
        HStack(spacing: 12) {
            统计项(标题: "证书总数", 值: "\(管理.证书总数)")
            统计项(标题: "已安装", 值: "\(管理.已安装证书数)")
            统计项(标题: "即将过期", 值: "\(管理.即将过期证书数)")
        }
    }

    /// 统计项
    private func 统计项(标题: String, 值: String) -> some View {
        VStack(spacing: 2) {
            Text(值)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.主题色)
                .monospacedDigit()
            Text(标题)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.卡片背景)
        .cornerRadius(10)
    }
}

// MARK: - 证书行

/// 证书行
private struct 证书行: View {
    let 证书: CA证书模型
    @Binding var 选中: CA证书模型?
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @State private var 显示操作菜单 = false

    var body: some View {
        HStack(spacing: 12) {
            // 证书图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(证书状态颜色.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: 证书.类型.图标)
                    .font(.system(size: 20))
                    .foregroundColor(证书状态颜色)
            }

            // 证书信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(证书.名称)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    Text(证书.状态.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(证书状态颜色)
                        .cornerRadius(4)
                }

                Text(证书.主题)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(证书.剩余时间显示, systemImage: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(证书.是否即将过期 || 证书.是否已过期 ? .危险色 : .secondary)
                    Label(证书.指纹显示, systemImage: "fingerprint")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 操作按钮
            Button {
                显示操作菜单 = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .confirmationDialog("证书操作", isPresented: $显示操作菜单) {
                Button("查看详情") {
                    选中 = 证书
                }
                Button("导出 PEM") {
                    // 导出操作
                }
                Button("生成描述文件") {
                    // 生成描述文件
                }
                Button("删除证书", role: .destructive) {
                    管理.删除证书(证书)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            选中 = 证书
        }
    }

    /// 证书状态颜色
    private var 证书状态颜色: Color {
        switch 证书.状态 {
        case .已安装, .已信任: return .成功色
        case .未安装: return .secondary
        case .已过期, .已撤销: return .危险色
        }
    }
}

// MARK: - 证书详情页面

/// 证书详情页面
struct 证书详情页面: View {
    let 证书: CA证书模型
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 显示复制提示 = false

    var body: some View {
        NavigationView {
            List {
                Section("基本信息") {
                    AppFormRow(标签: "名称") {
                        Text(证书.名称)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "类型") {
                        Text(证书.类型.rawValue)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "格式") {
                        Text(证书.格式.rawValue)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "状态") {
                        Text(证书.状态.rawValue)
                            .foregroundColor(.secondary)
                    }
                }

                Section("证书信息") {
                    AppFormRow(标签: "主题") {
                        Text(证书.主题)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    AppFormRow(标签: "颁发者") {
                        Text(证书.颁发者)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    AppFormRow(标签: "序列号") {
                        Text(证书.序列号)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    AppFormRow(标签: "有效期") {
                        Text(证书.有效期显示)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "剩余时间") {
                        Text(证书.剩余时间显示)
                            .foregroundColor(证书.是否即将过期 || 证书.是否已过期 ? .危险色 : .secondary)
                    }
                }

                Section("指纹") {
                    AppFormRow(标签: "SHA1") {
                        Text(证书.SHA1指纹)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    AppFormRow(标签: "SHA256") {
                        Text(证书.SHA256指纹)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Section("算法") {
                    AppFormRow(标签: "公钥算法") {
                        Text(证书.公钥算法)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "公钥长度") {
                        Text("\(证书.公钥长度) 位")
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "签名算法") {
                        Text(证书.签名算法)
                            .foregroundColor(.secondary)
                    }
                }

                Section("用途") {
                    AppFormRow(标签: "用于 MITM") {
                        Toggle("", isOn: Binding(
                            get: { 证书.用于MITM },
                            set: { _ in }
                        ))
                        .labelsHidden()
                        .disabled(true)
                    }
                    AppFormRow(标签: "用于 TLS 验证") {
                        Toggle("", isOn: Binding(
                            get: { 证书.用于TLS验证 },
                            set: { _ in }
                        ))
                        .labelsHidden()
                        .disabled(true)
                    }
                }

                Section("操作") {
                    Button {
                        复制SHA256指纹()
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.主题色)
                            Text("复制 SHA256 指纹")
                                .foregroundColor(.主题色)
                            Spacer()
                        }
                    }

                    Button {
                        // 导出 PEM
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.主题色)
                            Text("导出 PEM 证书")
                                .foregroundColor(.主题色)
                            Spacer()
                        }
                    }

                    Button {
                        // 生成描述文件
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.主题色)
                            Text("生成安装描述文件")
                                .foregroundColor(.主题色)
                            Spacer()
                        }
                    }

                    Button(role: .destructive) {
                        管理.删除证书(证书)
                        关闭()
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除证书")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.危险色)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("证书详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        关闭()
                    }
                }
            }
            .alert("已复制", isPresented: $显示复制提示) {
                Button("确定") {}
            } message: {
                Text("SHA256 指纹已复制到剪贴板")
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 复制 SHA256 指纹
    private func 复制SHA256指纹() {
        UIPasteboard.general.string = 证书.SHA256指纹
        显示复制提示 = true
    }
}

// MARK: - 证书导入页面

/// 证书导入页面
struct 证书导入页面: View {
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 导入方式 = 0
    @State private var 证书名称 = ""
    @State private var PEM内容 = ""
    @State private var 导入中 = false
    @State private var 导入结果: 证书导入结果?

    var body: some View {
        NavigationView {
            Form {
                Section("导入方式") {
                    Picker("方式", selection: $导入方式) {
                        Text("粘贴 PEM").tag(0)
                        Text("从文件导入").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                if 导入方式 == 0 {
                    Section("证书信息") {
                        AppFormRow(标签: "名称") {
                            TextField("证书名称（可选）", text: $证书名称)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section("PEM 内容") {
                        TextEditor(text: $PEM内容)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 200)
                    }
                } else {
                    Section("文件导入") {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("选择证书文件")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                            Text("支持 .pem / .cer / .crt / .p12 格式")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }

                if let 结果 = 导入结果 {
                    Section("导入结果") {
                        if 结果.成功 {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.成功色)
                                Text("导入成功")
                                    .foregroundColor(.成功色)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.危险色)
                                Text(结果.错误信息 ?? "导入失败")
                                    .foregroundColor(.危险色)
                                Spacer()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        导入证书()
                    } label: {
                        HStack {
                            Spacer()
                            if 导入中 {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("导入证书")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.主题色)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .disabled(导入中 || (导入方式 == 0 && PEM内容.isEmpty))
                }
            }
            .navigationTitle("导入证书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        关闭()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 导入证书
    private func 导入证书() {
        导入中 = true
        导入结果 = nil

        管理.导入证书(pem字符串: PEM内容, 名称: 证书名称.isEmpty ? nil : 证书名称) { 结果 in
            导入中 = false
            导入结果 = 结果
            if 结果.成功 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    关闭()
                }
            }
        }
    }
}

// MARK: - VPN 描述文件列表页面

/// VPN 描述文件列表页面
struct VPN描述文件列表页面: View {
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @State private var 显示新建弹窗 = false
    @State private var 选中描述文件: VPN描述文件模型?

    var body: some View {
        VStack(spacing: 0) {
            // 统计栏
            HStack(spacing: 12) {
                统计项(标题: "描述文件", 值: "\(管理.描述文件总数)")
                统计项(标题: "已安装", 值: "\(管理.已安装描述文件数)")
                统计项(标题: "连接状态", 值: 连接状态文本)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)

            if 管理.筛选后的描述文件列表.isEmpty {
                EmptyStateView(
                    图标: "gearshape.2",
                    标题: "暂无 VPN 描述文件",
                    说明: "点击右上角创建 VPN 配置描述文件"
                )
            } else {
                List {
                    ForEach(管理.筛选后的描述文件列表) { 描述文件 in
                        描述文件行(描述文件: 描述文件, 选中: $选中描述文件)
                            .listRowInsets(EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 15))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.页面背景)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    显示新建弹窗 = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.主题色)
                }
            }
        }
        .sheet(isPresented: $显示新建弹窗) {
            新建描述文件页面()
                .environmentObject(管理)
        }
        .sheet(item: $选中描述文件) { 描述文件 in
            描述文件详情页面(描述文件: 描述文件)
                .environmentObject(管理)
        }
        .onAppear {
            管理.刷新连接状态()
        }
    }

    /// 连接状态文本
    private var 连接状态文本: String {
        switch 管理.VPN连接状态 {
        case .invalid: return "无效"
        case .disconnected: return "已断开"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .reasserting: return "重连中"
        case .disconnecting: return "断开中"
        @unknown default: return "未知"
        }
    }

    /// 统计项
    private func 统计项(标题: String, 值: String) -> some View {
        VStack(spacing: 2) {
            Text(值)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.主题色)
                .lineLimit(1)
            Text(标题)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.卡片背景)
        .cornerRadius(10)
    }
}

// MARK: - 描述文件行

/// 描述文件行
private struct 描述文件行: View {
    let 描述文件: VPN描述文件模型
    @Binding var 选中: VPN描述文件模型?
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @State private var 显示操作菜单 = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(状态颜色.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: 描述文件.类型.图标)
                    .font(.system(size: 20))
                    .foregroundColor(状态颜色)
            }

            // 信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(描述文件.名称)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    Text(描述文件.状态.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(状态颜色)
                        .cornerRadius(4)
                }

                Text(描述文件.服务器地址)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(描述文件.类型.rawValue, systemImage: "tag")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if let 节点名称 = 描述文件.关联节点名称 {
                        Label(节点名称, systemImage: "server.rack")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // 操作按钮
            Button {
                显示操作菜单 = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .confirmationDialog("描述文件操作", isPresented: $显示操作菜单) {
                Button("查看详情") {
                    选中 = 描述文件
                }
                if 描述文件.状态 == .未安装 || 描述文件.状态 == .已移除 || 描述文件.状态 == .安装失败 {
                    Button("安装配置") {
                        安装配置()
                    }
                }
                if 描述文件.状态 == .已安装 || 描述文件.状态 == .已断开 {
                    Button("连接 VPN") {
                        _ = 管理.连接VPN()
                    }
                }
                if 描述文件.状态 == .已连接 {
                    Button("断开 VPN") {
                        管理.断开VPN()
                    }
                }
                if 描述文件.状态 == .已安装 || 描述文件.状态 == .已连接 || 描述文件.状态 == .已断开 {
                    Button("移除配置", role: .destructive) {
                        管理.移除VPN配置(描述文件) { _, _ in }
                    }
                }
                Button("删除描述文件", role: .destructive) {
                    管理.删除描述文件(描述文件)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            选中 = 描述文件
        }
    }

    /// 状态颜色
    private var 状态颜色: Color {
        switch 描述文件.状态 {
        case .已安装, .已断开: return .成功色
        case .已连接: return .主题色
        case .未安装: return .secondary
        case .安装失败, .已移除: return .危险色
        }
    }

    /// 安装配置
    private func 安装配置() {
        管理.安装VPN配置(描述文件) { 结果 in
            if 结果.成功 {
                // 安装成功后跳转 iOS 设置页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let 设置URL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(设置URL)
                    }
                }
            }
        }
    }
}

// MARK: - 描述文件详情页面

/// 描述文件详情页面
struct 描述文件详情页面: View {
    let 描述文件: VPN描述文件模型
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @Environment(\.dismiss) private var 关闭
    /// 是否正在安装
    @State private var 安装中 = false

    var body: some View {
        NavigationView {
            List {
                Section("基本信息") {
                    AppFormRow(标签: "名称") {
                        Text(描述文件.名称)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "类型") {
                        Text(描述文件.类型.rawValue)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "状态") {
                        Text(描述文件.状态.rawValue)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "服务器") {
                        Text(描述文件.服务器地址)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "扩展 ID") {
                        Text(描述文件.扩展BundleID)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Section("网络配置") {
                    AppFormRow(标签: "包含所有流量") {
                        Text(描述文件.包含所有流量 ? "是" : "否")
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "按需连接") {
                        Text(描述文件.按需连接 ? "启用" : "禁用")
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "断开时保持") {
                        Text(描述文件.断开时保持连接 ? "是" : "否")
                            .foregroundColor(.secondary)
                    }
                    if !描述文件.DNS服务器.isEmpty {
                        AppFormRow(标签: "DNS 服务器") {
                            Text(描述文件.DNS服务器.joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("关联信息") {
                    if let 节点名称 = 描述文件.关联节点名称 {
                        AppFormRow(标签: "关联节点") {
                            Text(节点名称)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let 安装时间 = 描述文件.安装时间 {
                        AppFormRow(标签: "安装时间") {
                            Text(格式化时间(安装时间))
                                .foregroundColor(.secondary)
                        }
                    }
                    if let 最后连接 = 描述文件.最后连接时间 {
                        AppFormRow(标签: "最后连接") {
                            Text(格式化时间(最后连接))
                                .foregroundColor(.secondary)
                        }
                    }
                    AppFormRow(标签: "总连接时长") {
                        Text(描述文件.连接时长显示)
                            .foregroundColor(.secondary)
                    }
                }

                Section("操作") {
                    if 描述文件.状态 == .未安装 || 描述文件.状态 == .已移除 || 描述文件.状态 == .安装失败 {
                        Button {
                            安装配置()
                        } label: {
                            HStack {
                                Spacer()
                                if 安装中 {
                                    ProgressView()
                                        .tint(.主题色)
                                } else {
                                    Text("安装 VPN 配置")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.主题色)
                                }
                                Spacer()
                            }
                        }
                        .disabled(安装中)
                    }

                    if 描述文件.状态 == .已安装 || 描述文件.状态 == .已断开 {
                        Button {
                            _ = 管理.连接VPN()
                        } label: {
                            HStack {
                                Spacer()
                                Text("连接 VPN")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.成功色)
                                Spacer()
                            }
                        }
                    }

                    if 描述文件.状态 == .已连接 {
                        Button {
                            管理.断开VPN()
                        } label: {
                            HStack {
                                Spacer()
                                Text("断开 VPN")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.警告色)
                                Spacer()
                            }
                        }
                    }

                    if 描述文件.状态 == .已安装 || 描述文件.状态 == .已连接 || 描述文件.状态 == .已断开 {
                        Button(role: .destructive) {
                            管理.移除VPN配置(描述文件) { _, _ in }
                        } label: {
                            HStack {
                                Spacer()
                                Text("移除 VPN 配置")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.危险色)
                                Spacer()
                            }
                        }
                    }

                    Button(role: .destructive) {
                        管理.删除描述文件(描述文件)
                        关闭()
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除描述文件")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.危险色)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("描述文件详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        关闭()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        分享描述文件()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.主题色)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 格式化时间
    private func 格式化时间(_ 日期: Date) -> String {
        let 格式化 = DateFormatter()
        格式化.dateFormat = "yyyy-MM-dd HH:mm"
        return 格式化.string(from: 日期)
    }

    /// 安装配置
    private func 安装配置() {
        安装中 = true
        管理.安装VPN配置(描述文件) { 结果 in
            安装中 = false
            if 结果.成功 {
                // 安装成功后跳转 iOS 设置页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let 设置URL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(设置URL)
                    }
                }
            }
        }
    }

    /// 分享描述文件（直接弹出 iOS 系统分享面板）
    private func 分享描述文件() {
        guard let 文件URL = VPN描述文件服务.共享.保存描述文件到临时目录(描述文件) else { return }

        let 活动视图 = UIActivityViewController(activityItems: [文件URL], applicationActivities: nil)

        // iPad 需要设置 popover 来源
        if let 弹出控制器 = 活动视图.popoverPresentationController {
            弹出控制器.sourceView = UIApplication.shared.windows.first?.rootViewController?.view
            弹出控制器.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            弹出控制器.permittedArrowDirections = []
        }

        // 获取当前最顶层的视图控制器来 present
        if let 窗口 = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
           let 根控制器 = 窗口.rootViewController {
            var 最顶层控制器 = 根控制器
            while let  presented = 最顶层控制器.presentedViewController {
                最顶层控制器 =  presented
            }
            最顶层控制器.present(活动视图, animated: true)
        }
    }
}

// MARK: - 新建描述文件页面

/// 新建描述文件页面
struct 新建描述文件页面: View {
    @EnvironmentObject private var 管理: 证书与描述文件管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 名称 = "NewVPN 隧道"
    @State private var 类型: VPN描述文件类型 = .自定义
    @State private var 服务器地址 = "127.0.0.1"
    @State private var 扩展BundleID = "com.newvpn.app.tunnel"
    @State private var 包含所有流量 = true
    @State private var 按需连接 = false

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    AppFormRow(标签: "名称") {
                        TextField("描述文件名称", text: $名称)
                            .multilineTextAlignment(.trailing)
                    }
                    AppFormRow(标签: "类型") {
                        Picker("", selection: $类型) {
                            ForEach(VPN描述文件类型.allCases, id: \.self) { 类型 in
                                Text(类型.rawValue).tag(类型)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section("服务器配置") {
                    AppFormRow(标签: "服务器地址") {
                        TextField("服务器地址", text: $服务器地址)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                    if 类型 == .自定义 {
                        AppFormRow(标签: "扩展 Bundle ID") {
                            TextField("扩展 Bundle ID", text: $扩展BundleID)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }
                    }
                }

                Section("网络选项") {
                    AppFormRow(标签: "包含所有流量") {
                        Toggle("", isOn: $包含所有流量)
                            .labelsHidden()
                    }
                    AppFormRow(标签: "按需连接") {
                        Toggle("", isOn: $按需连接)
                            .labelsHidden()
                    }
                }

                Section {
                    Button {
                        创建描述文件()
                    } label: {
                        HStack {
                            Spacer()
                            Text("创建描述文件")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.主题色)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .disabled(名称.isEmpty || 服务器地址.isEmpty)
                }
            }
            .navigationTitle("新建描述文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        关闭()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 创建描述文件
    private func 创建描述文件() {
        let 新描述文件 = VPN描述文件模型(
            id: UUID(),
            名称: 名称,
            类型: 类型,
            状态: .未安装,
            扩展BundleID: 扩展BundleID,
            服务器地址: 服务器地址,
            用户名: nil,
            密码引用: nil,
            共享密钥: nil,
            远程标识符: nil,
            本地标识符: nil,
            断开时保持连接: false,
            按需连接: 按需连接,
            包含所有流量: 包含所有流量,
            代理配置: nil,
            DNS服务器: ["223.5.5.5", "119.29.29.29"],
            搜索域: [],
            排除域名: [],
            描述文件数据: nil,
            创建时间: Date(),
            安装时间: nil,
            最后连接时间: nil,
            总连接时长: 0,
            关联节点ID: nil,
            关联节点名称: nil,
            备注: nil,
            标签: ["新建"]
        )

        管理.添加描述文件(新描述文件)
        关闭()
    }
}

// MARK: - 分享视图

/// 分享视图（封装 UIActivityViewController）
private struct 分享视图: UIViewControllerRepresentable {
    /// 分享内容数组
    let 分享内容: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let 控制器 = UIActivityViewController(activityItems: 分享内容, applicationActivities: nil)
        return 控制器
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 无需更新
    }
}

// MARK: - 预览

#Preview("证书与描述文件") {
    证书与描述文件页面()
        .environmentObject(证书与描述文件管理器.共享)
}
