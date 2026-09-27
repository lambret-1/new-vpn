//
//  抓包列表页面.swift
//  NewVPN
//
//  HTTP 抓包记录列表页面，展示捕获的 HTTP 请求/响应
//  第二期：完整请求/响应头Body记录、统计栏、大小显示、筛选
//

import SwiftUI

/// HTTP 抓包列表页面
struct 抓包列表页面: View {
    /// 抓包存储管理器
    @StateObject private var 存储 = 抓包存储管理器.共享
    /// 隧道管理器（判断 VPN 连接状态）
    @EnvironmentObject private var 隧道管理: 隧道管理器

    /// 搜索关键词
    @State private var 搜索词 = ""
    /// 筛选条件
    @State private var 筛选 = 抓包筛选条件()
    /// 自动刷新定时器
    @State private var 刷新定时器: Timer?
    /// 当前显示的记录列表
    @State private var 显示列表: [抓包记录] = []
    /// 当前加载页数
    @State private var 当前页数 = 1
    /// 每页记录数
    private let 每页数量 = 50
    /// 是否还有更多记录
    @State private var 还有更多 = true
    /// 是否显示筛选面板
    @State private var 显示筛选 = false
    /// 是否显示分享面板
    @State private var 显示分享 = false
    /// 分享文件 URL
    @State private var 分享文件URL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.页面背景.ignoresSafeArea()

                if 显示列表.isEmpty && !搜索词.isEmpty {
                    搜索无结果视图
                } else if 显示列表.isEmpty {
                    空态视图
                } else {
                    抓包列表内容
                }
            }
            .navigationTitle("HTTP 抓包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        显示筛选.toggle()
                    } label: {
                        Image(systemName: 筛选.是否空 ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(筛选.是否空 ? .primary : .成功色)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            导出HAR()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }
                        .disabled(存储.记录总数 == 0)

                        Button {
                            存储.清空记录()
                            刷新列表()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .disabled(存储.记录总数 == 0)
                    }
                }
            }
            .sheet(isPresented: $显示筛选) {
                筛选面板(筛选: $筛选) {
                    刷新列表()
                }
            }
            .sheet(isPresented: $显示分享) {
                if let 文件URL = 分享文件URL {
                    分享视图(活动项: [文件URL])
                }
            }
            .onAppear {
                启动自动刷新()
                刷新列表()
            }
            .onDisappear {
                停止自动刷新()
            }
        }
    }

    // MARK: - 列表内容

    private var 抓包列表内容: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    // 抓包功能开关
                    抓包开关行
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    // 统计栏
                    统计栏
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    // 记录列表
                    ForEach(Array(显示列表.enumerated()), id: \.element.id) { 索引, 记录 in
                        NavigationLink {
                            抓包详情页面(记录: 记录)
                        } label: {
                            抓包记录卡片(记录: 记录)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .onAppear {
                            // 滑动到倒数第 5 条时加载更多
                            if 索引 == 显示列表.count - 5 {
                                加载更多()
                            }
                        }
                    }

                    // 加载更多提示
                    if 还有更多 {
                        HStack {
                            ProgressView()
                            Text("加载更多...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                    } else if !显示列表.isEmpty {
                        Text("已加载全部 \(显示列表.count) 条记录")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                } header: {
                    // 列表头（固定）
                    HStack {
                        Text("共 \(显示列表.count) 条记录")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("实时刷新中")
                            .font(.system(size: 11))
                            .foregroundColor(.成功色)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.页面背景)
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - 抓包开关行

    private var 抓包开关行: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("启用 HTTP 抓包")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text("开启后需重启 VPN，仅捕获 HTTP(80) 流量")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { 存储.是否启用 },
                set: { 新值 in
                    存储.是否启用 = 新值
                    if 新值 {
                        存储.清空记录()
                    }
                    刷新列表()
                }
            ))
            .labelsHidden()
            .tint(.成功色)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    // MARK: - 统计栏

    private var 统计栏: some View {
        HStack(spacing: 8) {
            统计项(图标: "number", 标题: "总请求", 值: "\(存储.记录总数)")
            统计项(图标: "xmark.circle", 标题: "错误", 值: "\(存储.错误请求数)", 颜色: .red)
            统计项(图标: "lock.fill", 标题: "HTTPS", 值: "\(存储.HTTPS请求数)", 颜色: .green)
        }
    }

    private func 统计项(图标: String, 标题: String, 值: String, 颜色: Color = .primary) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: 图标)
                    .font(.system(size: 11))
                Text(值)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(颜色)
            Text(标题)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(10)
    }

    // MARK: - 空态视图

    private var 空态视图: some View {
        VStack(spacing: 16) {
            Spacer()

            // 抓包开关（空态时也显示）
            抓包开关行
                .padding(.horizontal, 16)

            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

            if !隧道管理.当前状态.是否活动 {
                Text("VPN 未连接")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("请先连接 VPN，然后开启 HTTP 抓包功能")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if !存储.是否启用 {
                Text("抓包未启用")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("请在上方开启抓包开关，然后重启 VPN")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("等待 HTTP 请求...")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("访问网页或使用 App 后，抓包记录将显示在这里")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - 搜索无结果视图

    private var 搜索无结果视图: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("未找到匹配的记录")
                .font(.headline)
                .foregroundColor(.primary)
            Text("尝试修改搜索关键词或筛选条件")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 自动刷新

    private func 启动自动刷新() {
        刷新定时器 = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            刷新列表()
        }
    }

    private func 停止自动刷新() {
        刷新定时器?.invalidate()
        刷新定时器 = nil
    }

    private func 刷新列表() {
        当前页数 = 1
        let 全部 = 存储.获取筛选记录(筛选)
        let 结束索引 = min(每页数量, 全部.count)
        显示列表 = Array(全部.prefix(结束索引))
        还有更多 = 全部.count > 每页数量
    }

    /// 加载更多记录
    private func 加载更多() {
        guard 还有更多 else { return }
        let 全部 = 存储.获取筛选记录(筛选)
        let 结束索引 = min(每页数量 * (当前页数 + 1), 全部.count)
        if 结束索引 > 显示列表.count {
            显示列表 = Array(全部.prefix(结束索引))
            当前页数 += 1
            还有更多 = 结束索引 < 全部.count
        } else {
            还有更多 = false
        }
    }

    // MARK: - HAR 导出

    private func 导出HAR() {
        let 所有记录 = 存储.获取所有记录()
        let har内容 = 抓包记录.导出HAR(所有记录)

        // 写入临时文件
        let 日期格式化器 = DateFormatter()
        日期格式化器.dateFormat = "yyyyMMdd_HHmmss"
        let 文件名 = "newvpn_capture_\(日期格式化器.string(from: Date())).har"
        let 临时目录 = FileManager.default.temporaryDirectory
        let 文件URL = 临时目录.appendingPathComponent(文件名)

        do {
            try har内容.write(to: 文件URL, atomically: true, encoding: .utf8)
            分享文件URL = 文件URL
            显示分享 = true
        } catch {
            NSLog("[抓包] 导出 HAR 失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 分享视图

/// UIActivityViewController 包装
private struct 分享视图: UIViewControllerRepresentable {
    let 活动项: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: 活动项, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 筛选面板

/// 筛选面板
private struct 筛选面板: View {
    @Binding var 筛选: 抓包筛选条件
    var 应用回调: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// 显示保存规则弹窗
    @State private var 显示保存规则弹窗 = false
    /// 规则名称输入
    @State private var 规则名称 = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("请求方法") {
                    ForEach(["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD"], id: \.self) { 方法 in
                        Button {
                            if 筛选.方法筛选.contains(方法) {
                                筛选.方法筛选.remove(方法)
                            } else {
                                筛选.方法筛选.insert(方法)
                            }
                        } label: {
                            HStack {
                                Text(方法)
                                    .foregroundColor(.primary)
                                Spacer()
                                if 筛选.方法筛选.contains(方法) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.成功色)
                                }
                            }
                        }
                    }
                }

                Section("状态") {
                    Toggle("仅显示错误请求", isOn: $筛选.仅显示错误)
                    Toggle("仅显示 HTTPS", isOn: $筛选.仅显示HTTPS)
                    Toggle("仅显示有响应 Body", isOn: $筛选.仅显示有Body)
                }

                Section("状态码范围") {
                    ForEach(["2xx", "3xx", "4xx", "5xx"], id: \.self) { 范围 in
                        Button {
                            if 筛选.状态码筛选.contains(范围) {
                                筛选.状态码筛选.remove(范围)
                            } else {
                                筛选.状态码筛选.insert(范围)
                            }
                        } label: {
                            HStack {
                                Text(范围)
                                    .foregroundColor(.primary)
                                Spacer()
                                if 筛选.状态码筛选.contains(范围) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.成功色)
                                }
                            }
                        }
                    }
                }

                Section("响应大小") {
                    Picker("最小响应大小", selection: $筛选.最小响应大小) {
                        Text("不限制").tag(0)
                        Text("1KB 以上").tag(1024)
                        Text("10KB 以上").tag(10240)
                        Text("100KB 以上").tag(102400)
                        Text("1MB 以上").tag(1048576)
                    }
                }

                Section("已保存规则") {
                    if 过滤规则管理器.共享.规则数量 == 0 {
                        Text("暂无保存的过滤规则")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    } else {
                        ForEach(过滤规则管理器.共享.规则列表) { 规则 in
                            HStack {
                                Button {
                                    筛选 = 规则.筛选条件
                                } label: {
                                    HStack {
                                        Text(规则.名称)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.成功色)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    过滤规则管理器.共享.删除规则(规则.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }

                    Button {
                        显示保存规则弹窗 = true
                    } label: {
                        HStack {
                            Image(systemName: "bookmark")
                            Text("保存当前筛选")
                                .foregroundColor(.blue)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        筛选 = 抓包筛选条件()
                        应用回调()
                        dismiss()
                    } label: {
                        Text("重置筛选")
                            .foregroundColor(.red)
                    }

                    Button {
                        应用回调()
                        dismiss()
                    } label: {
                        Text("应用筛选")
                            .foregroundColor(.成功色)
                            .fontWeight(.medium)
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .alert("保存过滤规则", isPresented: $显示保存规则弹窗) {
                TextField("规则名称", text: $规则名称)
                Button("取消", role: .cancel) {}
                Button("保存") {
                    if !规则名称.isEmpty {
                        过滤规则管理器.共享.保存规则(名称: 规则名称, 筛选条件: 筛选)
                        规则名称 = ""
                    }
                }
            } message: {
                Text("为当前筛选条件命名，方便后续快速应用")
            }
        }
    }
}

// MARK: - 抓包记录卡片

/// 单条抓包记录卡片
private struct 抓包记录卡片: View {
    let 记录: 抓包记录

    var body: some View {
        HStack(spacing: 12) {
            // 方法标签
            方法标签(方法: 记录.请求方法)

            // 主内容
            VStack(alignment: .leading, spacing: 6) {
                // URL 路径
                Text(记录.请求路径)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 域名
                Text(记录.请求主机)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // 底部信息行
                HStack(spacing: 10) {
                    // 状态码
                    if let 状态码 = 记录.响应状态码 {
                        状态码标签(状态码: 状态码)
                    } else if 记录.错误信息 != nil {
                        Text("失败")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text("请求中")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // 耗时
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(记录.耗时显示)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)

                    // 请求大小
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                        Text(记录.请求大小显示)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)

                    // 响应大小
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                        Text(记录.响应大小显示)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    // HTTPS 标识
                    if 记录.是否HTTPS {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 方法标签

/// HTTP 方法标签
private struct 方法标签: View {
    let 方法: String

    var body: some View {
        Text(方法.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 44, height: 22)
            .background(方法颜色)
            .cornerRadius(4)
    }

    private var 方法颜色: Color {
        switch 方法.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        case "PATCH": return .purple
        case "HEAD": return .gray
        case "OPTIONS": return .gray
        default: return .gray
        }
    }
}

// MARK: - 状态码标签

/// HTTP 状态码标签
private struct 状态码标签: View {
    let 状态码: Int

    var body: some View {
        Text("\(状态码)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(状态码颜色)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(状态码颜色.opacity(0.1))
            .cornerRadius(4)
    }

    private var 状态码颜色: Color {
        switch 状态码 {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .gray
        }
    }
}

// MARK: - 预览

#Preview {
    抓包列表页面()
        .environmentObject(隧道管理器.共享)
}
