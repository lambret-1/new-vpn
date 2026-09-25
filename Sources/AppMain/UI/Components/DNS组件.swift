//
//  DNS组件.swift
//  NewVPN
//
//  DNS 相关 UI 组件
//  DNS 状态卡片、查询记录列表、服务器管理、配置表单
//

import SwiftUI

// MARK: - DNS 记录页面

/// DNS 记录主页面（底部弹窗使用）
struct DNS记录页面: View {
    /// DNS 管理器
    @EnvironmentObject private var DNS管理: DNS管理器
    /// 搜索关键词
    @State private var 搜索关键词 = ""
    /// 选中的记录类型筛选
    @State private var 筛选类型: DNS记录类型?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部统计栏
            DNS统计栏()
                .padding(.horizontal, 15)
                .padding(.top, 10)

            // 搜索栏
            AppSearchBar(搜索文字: $搜索关键词, 占位文字: "搜索域名或IP")
                .padding(.horizontal, 15)
                .padding(.vertical, 8)

            // 记录类型筛选
            筛选类型选择器()
                .padding(.horizontal, 15)
                .padding(.bottom, 8)

            // 记录列表
            if 筛选后的记录.isEmpty {
                EmptyStateView(
                    图标: "network",
                    标题: "暂无 DNS 查询记录",
                    说明: "VPN 连接后，域名解析记录会实时显示在这里"
                )
            } else {
                List {
                    ForEach(筛选后的记录) { 记录 in
                        DNS记录行(记录: 记录)
                            .listRowInsets(EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 15))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    DNS管理.同步扩展DNS记录()
                }
            }
        }
        .background(Color.页面背景)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        DNS管理.同步扩展DNS记录()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }

                    Button {
                        DNS管理.清除查询记录()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .disabled(DNS管理.查询记录列表.isEmpty)
                }
            }
        }
    }

    /// 筛选后的记录
    private var 筛选后的记录: [DNS记录模型] {
        DNS管理.查询记录列表.filter { 记录 in
            // 搜索筛选
            if !搜索关键词.isEmpty {
                let 关键词 = 搜索关键词.lowercased()
                let 匹配域名 = 记录.域名.lowercased().contains(关键词)
                let 匹配结果 = 记录.解析结果.contains { $0.lowercased().contains(关键词) }
                if !匹配域名 && !匹配结果 { return false }
            }
            // 类型筛选
            if let 类型 = 筛选类型, 记录.记录类型 != 类型 {
                return false
            }
            return true
        }
    }
}

// MARK: - DNS 统计栏

/// DNS 查询统计栏
private struct DNS统计栏: View {
    @EnvironmentObject private var DNS管理: DNS管理器

    var body: some View {
        let 统计 = DNS管理.查询统计

        HStack(spacing: 8) {
            统计项(数值: 统计.今日查询数, 标签: "今日查询", 颜色: .主题色)
            统计项(数值: 统计.总数, 标签: "总记录", 颜色: .成功色)
            统计项(数值: 统计.拦截数, 标签: "已拦截", 颜色: .危险色)
            统计项(数值: 统计.缓存命中数, 标签: "缓存命中", 颜色: .警告色)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    /// 统计项
    private struct 统计项: View {
        let 数值: Int
        let 标签: String
        let 颜色: Color

        var body: some View {
            VStack(spacing: 4) {
                Text("\(数值)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(颜色)
                Text(标签)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 筛选类型选择器

/// 记录类型筛选选择器
private struct 筛选类型选择器: View {
    @State private var 筛选类型: DNS记录类型?

    private let 类型列表: [DNS记录类型?] = [nil, .A, .AAAA, .CNAME, .MX, .TXT]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(类型列表, id: \.?.rawValue) { 类型 in
                    Button {
                        筛选类型 = 类型
                    } label: {
                        Text(类型?.rawValue ?? "全部")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(筛选类型 == 类型 ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(筛选类型 == 类型 ? Color.主题色 : Color.卡片背景)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - DNS 记录行

/// 单条 DNS 查询记录行
struct DNS记录行: View {
    let 记录: DNS记录模型

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：域名 + 类型标签 + 来源
            HStack(spacing: 8) {
                Text(记录.域名)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Text(记录.记录类型.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(记录.记录类型 == .A ? Color.主题色 : Color.警告色)
                    .cornerRadius(4)

                Spacer()

                // 来源标签
                来源标签(来源: 记录.来源)
            }

            // 第二行：解析结果
            if !记录.解析结果.isEmpty {
                Text(记录.结果显示)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("无解析结果")
                    .font(.system(size: 12))
                    .foregroundColor(.危险色)
            }

            // 第三行：时间 + 响应时间 + DNS服务器
            HStack(spacing: 12) {
                Text(记录.时间显示)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if let 响应 = 记录.响应时间 {
                    Text("\(响应)ms")
                        .font(.system(size: 11))
                        .foregroundColor(响应颜色(响应))
                }

                Text(记录.DNS服务器)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let 规则 = 记录.拦截规则 {
                    Text("规则: \(规则)")
                        .font(.system(size: 11))
                        .foregroundColor(.危险色)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(记录.是否被拦截 ? Color.危险色.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    /// 来源标签
    private func 来源标签(来源: DNS来源) -> some View {
        let (文字, 颜色): (String, Color)
        switch 来源 {
        case .缓存: (文字, 颜色) = ("缓存", .警告色)
        case .远程: (文字, 颜色) = ("远程", .主题色)
        case .拦截: (文字, 颜色) = ("拦截", .危险色)
        case .直连: (文字, 颜色) = ("直连", .成功色)
        case .代理: (文字, 颜色) = ("代理", .警告色)
        }

        return Text(文字)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(颜色)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(颜色.opacity(0.1))
            .cornerRadius(4)
    }

    /// 响应时间颜色
    private func 响应颜色(_ 毫秒: Int) -> Color {
        switch 毫秒 {
        case 0..<50: return .成功色
        case 50..<200: return .警告色
        default: return .危险色
        }
    }
}

// MARK: - DNS 服务器管理页面

/// DNS 服务器管理页面
struct DNS服务器管理页面: View {
    @EnvironmentObject private var DNS管理: DNS管理器
    @State private var 显示添加服务器 = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
                Text("DNS 服务器")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button {
                    DNS管理.测速所有服务器()
                } label: {
                    HStack(spacing: 4) {
                        if DNS管理.是否测速中 {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "gauge")
                                .font(.system(size: 14))
                        }
                        Text("全部测速")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.主题色)
                }
                .disabled(DNS管理.是否测速中)

                Button {
                    显示添加服务器 = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.主题色)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)

            // 服务器列表
            List {
                ForEach($DNS管理.配置.服务器列表) { $服务器 in
                    DNS服务器行(服务器: $服务器)
                        .listRowInsets(EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 15))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete { 索引集 in
                    索引集.forEach { 索引 in
                        DNS管理.删除服务器(DNS管理.配置.服务器列表[索引])
                    }
                }
                .onMove { 源, 目标 in
                    DNS管理.移动服务器(从源索引: 源, 到目标索引: 目标)
                }
            }
            .listStyle(.plain)
        }
        .background(Color.页面背景)
        .sheet(isPresented: $显示添加服务器) {
            添加DNS服务器弹窗()
                .environmentObject(DNS管理)
        }
    }
}

// MARK: - DNS 服务器行

/// DNS 服务器行
struct DNS服务器行: View {
    @Binding var 服务器: DNS服务器模型
    @EnvironmentObject private var DNS管理: DNS管理器

    var body: some View {
        HStack(spacing: 12) {
            // 启用开关
            Toggle("", isOn: Binding(
                get: { 服务器.启用 },
                set: { _ in DNS管理.切换服务器启用(服务器) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .主题色))
            .frame(width: 50)

            // 服务器信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(服务器.名称)
                        .font(.system(size: 14, weight: .medium))
                    Text(服务器.类型.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(类型颜色(服务器.类型))
                        .cornerRadius(3)
                }
                Text(服务器.地址显示)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if let 描述 = 服务器.描述 {
                    Text(描述)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()

            // 测速延迟
            VStack(alignment: .trailing, spacing: 2) {
                if let 延迟 = 服务器.测速延迟 {
                    Text("\(延迟)ms")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(延迟颜色(延迟))
                } else {
                    Text("-")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Button {
                    DNS管理.测速服务器(服务器)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.主题色)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(10)
        .opacity(服务器.启用 ? 1.0 : 0.5)
    }

    /// 类型颜色
    private func 类型颜色(_ 类型: DNS服务器类型) -> Color {
        switch 类型 {
        case .udp: return .主题色
        case .tcp: return .警告色
        case .doh: return .成功色
        case .dot: return .警告色
        }
    }

    /// 延迟颜色
    private func 延迟颜色(_ 毫秒: Int) -> Color {
        switch 毫秒 {
        case 0..<50: return .成功色
        case 50..<150: return .警告色
        default: return .危险色
        }
    }
}

// MARK: - 添加 DNS 服务器弹窗

/// 添加 DNS 服务器弹窗
struct 添加DNS服务器弹窗: View {
    @EnvironmentObject private var DNS管理: DNS管理器
    @Environment(\.dismiss) private var 关闭

    @State private var 名称 = ""
    @State private var 地址 = ""
    @State private var 端口 = "53"
    @State private var 类型: DNS服务器类型 = .udp
    @State private var 描述 = ""

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    AppFormRow(标签: "名称") {
                        TextField("例如：我的 DNS", text: $名称)
                            .multilineTextAlignment(.trailing)
                    }
                    AppFormRow(标签: "地址") {
                        TextField("IP 或域名", text: $地址)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                    AppFormRow(标签: "端口") {
                        TextField("53", text: $端口)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }

                Section("协议类型") {
                    Picker("类型", selection: $类型) {
                        ForEach(DNS服务器类型.allCases, id: \.self) { 类型 in
                            Text(类型.rawValue).tag(类型)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: 类型) { 新类型 in
                        端口 = "\(新类型.默认端口)"
                    }
                }

                Section("描述（可选）") {
                    TextField("服务器描述", text: $描述)
                }
            }
            .navigationTitle("添加 DNS 服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 关闭() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        保存服务器()
                    }
                    .disabled(名称.isEmpty || 地址.isEmpty)
                }
            }
        }
    }

    /// 保存服务器
    private func 保存服务器() {
        let 服务器 = DNS服务器模型(
            名称: 名称,
            地址: 地址,
            端口: Int(端口) ?? 类型.默认端口,
            类型: 类型,
            启用: true,
            描述: 描述.isEmpty ? nil : 描述
        )
        DNS管理.添加服务器(服务器)
        关闭()
    }
}

// MARK: - DNS 设置页面

/// DNS 设置页面
struct DNS设置页面: View {
    @EnvironmentObject private var DNS管理: DNS管理器

    var body: some View {
        Form {
            Section("DNS 策略") {
                Picker("解析策略", selection: $DNS管理.配置.策略) {
                    ForEach(DNS策略.allCases, id: \.self) { 策略 in
                        Text(策略.rawValue).tag(策略)
                    }
                }

                Toggle("启用自定义 DNS", isOn: $DNS管理.配置.启用自定义DNS)
                    .tint(.主题色)
                    .onChange(of: DNS管理.配置.启用自定义DNS) { _ in
                        DNS管理.保存配置()
                    }
            }

            Section("缓存设置") {
                Toggle("启用 DNS 缓存", isOn: $DNS管理.配置.启用缓存)
                    .tint(.主题色)
                    .onChange(of: DNS管理.配置.启用缓存) { _ in
                        DNS管理.保存配置()
                    }

                AppFormRow(标签: "缓存 TTL 覆盖") {
                    TextField("0 = 使用服务器 TTL", value: $DNS管理.配置.缓存TTL覆盖, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .onChange(of: DNS管理.配置.缓存TTL覆盖) { _ in
                            DNS管理.保存配置()
                        }
                }

                Button {
                    DNS服务.共享.清除缓存()
                } label: {
                    HStack {
                        Text("清除 DNS 缓存")
                            .foregroundColor(.主题色)
                        Spacer()
                        Image(systemName: "trash")
                            .foregroundColor(.主题色)
                    }
                }
            }

            Section("安全设置") {
                Toggle("启用 DNS 过滤", isOn: $DNS管理.配置.启用过滤)
                    .tint(.主题色)
                    .onChange(of: DNS管理.配置.启用过滤) { _ in
                        DNS管理.保存配置()
                    }

                Toggle("启用 DNS 泄漏保护", isOn: $DNS管理.配置.启用泄漏保护)
                    .tint(.主题色)
                    .onChange(of: DNS管理.配置.启用泄漏保护) { _ in
                        DNS管理.保存配置()
                    }

                Button {
                    DNS管理.执行泄漏检测()
                } label: {
                    HStack {
                        Text("DNS 泄漏检测")
                            .foregroundColor(.主题色)
                        Spacer()
                        if DNS管理.是否泄漏检测中 {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                        } else {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.主题色)
                        }
                    }
                }
                .disabled(DNS管理.是否泄漏检测中)

                if let 结果 = DNS管理.泄漏检测结果 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(结果.说明)
                            .font(.system(size: 13))
                            .foregroundColor(结果.存在泄漏 ? .危险色 : .成功色)
                        Text("检测时间: \(格式化时间(结果.检测时间))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("日志设置") {
                Toggle("记录 DNS 查询日志", isOn: $DNS管理.配置.记录查询日志)
                    .tint(.主题色)
                    .onChange(of: DNS管理.配置.记录查询日志) { _ in
                        DNS管理.保存配置()
                    }

                AppFormRow(标签: "最大日志条数") {
                    Picker("", selection: $DNS管理.配置.最大日志条数) {
                        Text("100").tag(100)
                        Text("500").tag(500)
                        Text("1000").tag(1000)
                        Text("5000").tag(5000)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: DNS管理.配置.最大日志条数) { _ in
                        DNS管理.保存配置()
                    }
                }

                Button {
                    DNS管理.清除查询记录()
                } label: {
                    HStack {
                        Text("清除查询记录")
                            .foregroundColor(.危险色)
                        Spacer()
                        Image(systemName: "trash")
                            .foregroundColor(.危险色)
                    }
                }
            }

            Section {
                Button {
                    DNS管理.重置配置()
                } label: {
                    HStack {
                        Text("重置为默认配置")
                            .foregroundColor(.危险色)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("DNS 设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 格式化时间
    private func 格式化时间(_ 时间: Date) -> String {
        let 格式 = DateFormatter()
        格式.dateFormat = "MM/dd HH:mm:ss"
        return 格式.string(from: 时间)
    }
}

// MARK: - 预览

#Preview("DNS记录页面") {
    DNS记录页面()
        .environmentObject(DNS管理器.共享)
        .background(Color.页面背景)
}

#Preview("DNS服务器管理") {
    NavigationView {
        DNS服务器管理页面()
            .environmentObject(DNS管理器.共享)
    }
}
