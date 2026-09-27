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
    /// 是否显示筛选面板
    @State private var 显示筛选 = false

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
            .searchable(text: $搜索词, prompt: "搜索 URL / 域名 / 路径")
            .onChange(of: 搜索词) { _ in
                筛选.关键词 = 搜索词
                刷新列表()
            }
            .sheet(isPresented: $显示筛选) {
                筛选面板(筛选: $筛选) {
                    刷新列表()
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
                    ForEach(显示列表) { 记录 in
                        NavigationLink {
                            抓包详情页面(记录: 记录)
                        } label: {
                            抓包记录卡片(记录: 记录)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
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
        显示列表 = 存储.获取筛选记录(筛选)
    }
}

// MARK: - 筛选面板

/// 筛选面板
private struct 筛选面板: View {
    @Binding var 筛选: 抓包筛选条件
    var 应用回调: () -> Void
    @Environment(\.dismiss) private var dismiss

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
