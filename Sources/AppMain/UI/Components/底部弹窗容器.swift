//
//  底部弹窗容器.swift
//  NewVPN
//
//  底部90%高度弹窗容器
//  左上角向下箭头点击关闭，支持下滑手势关闭
//

import SwiftUI

/// 底部弹窗容器修饰符
struct 底部弹窗容器: ViewModifier {
    /// 绑定弹窗类型（nil 表示关闭）
    @Binding var 弹窗类型: 底部弹窗类型?

    func body(content: Content) -> some View {
        content
            .sheet(item: $弹窗类型) { 类型 in
                底部弹窗内容(弹窗类型: 类型) {
                    弹窗类型 = nil
                }
                .presentationDetents([.height(UIScreen.main.bounds.height * 0.95)])
                .presentationDragIndicator(.visible)
            }
    }
}

// MARK: - 弹窗内容

/// 底部弹窗内容视图
private struct 底部弹窗内容: View {
    /// 弹窗类型
    let 弹窗类型: 底部弹窗类型
    /// 关闭回调
    let 关闭: () -> Void
    /// 全局状态
    @EnvironmentObject private var 状态: AppState
    /// 更新管理器
    @EnvironmentObject private var 更新管理器: AppUpdateManager
    /// 下载管理器
    @EnvironmentObject private var 下载管理器: AppDownloadManager

    var body: some View {
        ZStack {
            NavigationStack {
                弹窗内容视图(类型: 弹窗类型)
                    .navigationTitle(弹窗类型.标题)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                关闭()
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
            }

            // 更新弹窗（在 sheet 层级之上显示）
            if 更新管理器.是否显示弹窗 || 下载管理器.下载状态 == .下载中 {
                AppUpdateAlert(
                    更新管理器: 更新管理器,
                    下载管理器: 下载管理器
                ) {
                    更新管理器.关闭弹窗()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: 更新管理器.是否显示弹窗)
    }
}

// MARK: - 各弹窗内容

/// 根据弹窗类型返回对应内容视图
private struct 弹窗内容视图: View {
    let 类型: 底部弹窗类型

    var body: some View {
        switch 类型 {
        case .编辑配置文件:
            编辑配置文件页面()
        case .DNS记录:
            DNS记录页面()
        case .JS脚本记录:
            JS脚本记录视图()
        case .TCPUDP流量:
            TCPUDP流量视图()
        case .设置:
            设置视图()
        }
    }
}

// MARK: - JS 脚本记录

private struct JS脚本记录视图: View {
    var body: some View {
        List {
            Section("已执行脚本") {
                ForEach(["移除网页广告", "请求日志记录", "自动签到", "流量统计"], id: \.self) { 名称 in
                    HStack {
                        Image(systemName: "curlybraces")
                            .foregroundColor(.主题色)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(名称)
                                .font(.system(size: 14))
                            Text("执行成功 · 2秒前")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - TCP/UDP 流量

private struct TCPUDP流量视图: View {
    var body: some View {
        List {
            Section("流量统计") {
                HStack {
                    Text("TCP 连接数")
                    Spacer()
                    Text("360")
                        .foregroundColor(.主题色)
                }
                HStack {
                    Text("UDP 连接数")
                    Spacer()
                    Text("34")
                        .foregroundColor(.主题色)
                }
                HStack {
                    Text("总上行")
                    Spacer()
                    Text("128.5 MB")
                        .foregroundColor(.成功色)
                }
                HStack {
                    Text("总下行")
                    Spacer()
                    Text("1.2 GB")
                        .foregroundColor(.成功色)
                }
            }
            Section("实时速率") {
                HStack {
                    Text("上行速率")
                    Spacer()
                    Text("2.3 MB/s")
                        .foregroundColor(.主题色)
                }
                HStack {
                    Text("下行速率")
                    Spacer()
                    Text("8.7 MB/s")
                        .foregroundColor(.主题色)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 设置

private struct 设置视图: View {
    /// 更新管理器
    @ObservedObject private var 更新管理器 = AppUpdateManager.共享
    /// 证书与描述文件管理器
    @EnvironmentObject private var 证书管理: 证书与描述文件管理器
    /// 隧道管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器
    /// DNS 管理器
    @EnvironmentObject private var DNS管理: DNS管理器
    /// 分流规则管理器
    @EnvironmentObject private var 分流管理: 分流规则管理器
    /// 是否显示证书与描述文件页面
    @State private var 显示证书页面 = false
    /// 是否显示 DNS 设置页面
    @State private var 显示DNS设置 = false
    /// 是否显示分流规则页面
    @State private var 显示分流规则 = false
    /// 是否显示代理模式选择页面
    @State private var 显示代理模式选择 = false
    /// 是否显示 MITM 设置页面
    @State private var 显示MITM设置 = false
    /// 是否显示重写规则设置页面
    @State private var 显示重写规则 = false
    /// 是否显示 HTTP 抓包页面
    @State private var 显示抓包页面 = false
    /// 是否显示崩溃日志报告页面
    @State private var 显示崩溃日志 = false

    var body: some View {
        List {
            Section("通用") {
                Label("外观主题", systemImage: "paintpalette")
                Label("语言", systemImage: "globe")
                Label("启动时自动连接", systemImage: "power")
            }
            Section("网络") {
                // DNS 设置：显示当前策略，点击进入 DNS 设置页面
                Button {
                    显示DNS设置 = true
                } label: {
                    HStack {
                        Label("DNS 设置", systemImage: "network")
                        Spacer()
                        Text(DNS管理.配置.策略.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 代理模式：显示当前运行模式，点击打开选择页面
                Button {
                    显示代理模式选择 = true
                } label: {
                    HStack {
                        Label("代理模式", systemImage: "arrow.left.arrow.right")
                        Spacer()
                        Text(隧道管理.配置.运行模式.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 分流规则：显示启用规则数量，点击进入分流规则页面
                Button {
                    显示分流规则 = true
                } label: {
                    HStack {
                        Label("分流规则", systemImage: "arrow.triangle.branch")
                        Spacer()
                        Text("\(分流管理.配置.所有规则.count) 条启用")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // MITM 解密：右侧快捷开关，点击卡片进入设置页面
                HStack {
                    Button {
                        显示MITM设置 = true
                    } label: {
                        HStack(spacing: 0) {
                            Label("MITM 解密", systemImage: "lock.shield")
                            Spacer()
                            Text(MITM管理器.共享.启用 ? "已启用" : "未启用")
                                .font(.system(size: 12))
                                .foregroundColor(MITM管理器.共享.启用 ? .成功色 : .secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    Toggle("", isOn: Binding(
                        get: { MITM管理器.共享.启用 },
                        set: { 新值 in
                            MITM管理器.共享.启用 = 新值
                            if 隧道管理.当前状态 == .已连接 {
                                隧道管理.重新加载配置()
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .frame(width: 51)
                }

                // 重写规则：右侧快捷开关，点击卡片进入设置页面
                HStack {
                    Button {
                        显示重写规则 = true
                    } label: {
                        HStack(spacing: 0) {
                            Label("重写规则", systemImage: "pencil.line")
                            Spacer()
                            Text(重写规则管理器.共享.配置.启用 ? "已启用" : "未启用")
                                .font(.system(size: 12))
                                .foregroundColor(重写规则管理器.共享.配置.启用 ? .成功色 : .secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    Toggle("", isOn: Binding(
                        get: { 重写规则管理器.共享.配置.启用 },
                        set: { 新值 in
                            重写规则管理器.共享.配置.启用 = 新值
                            重写规则管理器.共享.保存配置()
                            if 隧道管理.当前状态 == .已连接 {
                                隧道管理.重新加载配置()
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .frame(width: 51)
                }

                // HTTP 抓包：右侧快捷开关，点击卡片进入抓包列表页面
                HStack {
                    Button {
                        显示抓包页面 = true
                    } label: {
                        HStack(spacing: 0) {
                            Label("HTTP 抓包", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            Text(抓包存储管理器.共享.是否启用 ? "\(抓包存储管理器.共享.记录总数)条" : "未启用")
                                .font(.system(size: 12))
                                .foregroundColor(抓包存储管理器.共享.是否启用 ? .成功色 : .secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    Toggle("", isOn: Binding(
                        get: { 抓包存储管理器.共享.是否启用 },
                        set: { 新值 in
                            抓包存储管理器.共享.是否启用 = 新值
                            if 隧道管理.当前状态 == .已连接 {
                                隧道管理.重新加载配置()
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .frame(width: 51)
                }
            }
            Section("安全") {
                Button {
                    显示证书页面 = true
                } label: {
                    HStack {
                        Label("CA 证书与描述文件", systemImage: "shield")
                        Spacer()
                        Text("\(证书管理.证书总数) 证书 / \(证书管理.描述文件总数) 描述文件")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            Section("关于") {
                HStack {
                    Label("版本信息", systemImage: "info.circle")
                    Spacer()
                    Text("v\(更新管理器.当前版本号)")
                        .foregroundColor(.secondary)
                }
                Button {
                    更新管理器.开始检测(静默模式: false)
                } label: {
                    HStack {
                        Label("检查更新", systemImage: "arrow.down.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 崩溃日志报告
                Button {
                    显示崩溃日志 = true
                } label: {
                    HStack {
                        Label("崩溃日志报告", systemImage: "exclamationmark.triangle")
                        Spacer()
                        let 崩溃数量 = 崩溃日志收集器.共享.读取所有崩溃日志().count
                        if 崩溃数量 > 0 {
                            Text("\(崩溃数量) 条")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Label("开源许可", systemImage: "scroll")
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $显示证书页面) {
            证书与描述文件页面()
                .environmentObject(证书管理)
        }
        .sheet(isPresented: $显示DNS设置) {
            NavigationStack {
                DNS设置页面()
                    .environmentObject(DNS管理)
                    .navigationTitle("DNS 设置")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $显示分流规则) {
            NavigationStack {
                分流规则设置页面()
                    .environmentObject(分流管理)
                    .navigationTitle("分流规则设置")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $显示代理模式选择) {
            NavigationStack {
                代理模式选择页面(当前模式: 隧道管理.配置.运行模式) { 新模式 in
                    隧道管理.配置.运行模式 = 新模式
                    隧道管理.保存运行模式偏好()
                    if 隧道管理.当前状态 == .已连接 {
                        隧道管理.重新加载配置()
                    }
                    显示代理模式选择 = false
                }
                .environmentObject(隧道管理)
                .navigationTitle("代理模式")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $显示MITM设置) {
            MITM设置页面()
                .environmentObject(MITM管理器.共享)
        }
        .sheet(isPresented: $显示重写规则) {
            重写规则设置页面()
                .environmentObject(重写规则管理器.共享)
        }
        .sheet(isPresented: $显示抓包页面) {
            抓包列表页面()
                .environmentObject(隧道管理)
        }
        .sheet(isPresented: $显示崩溃日志) {
            崩溃日志报告页面()
        }
    }
}

// MARK: - 代理模式选择页面

/// 代理模式选择页面
private struct 代理模式选择页面: View {
    /// 当前选中的模式
    let 当前模式: 隧道运行模式
    /// 选择回调
    let 选择回调: (隧道运行模式) -> Void
    /// 隧道管理器（用于显示模式描述）
    @EnvironmentObject private var 隧道管理: 隧道管理器

    var body: some View {
        List {
            ForEach(隧道运行模式.allCases, id: \.self) { 模式 in
                Button {
                    选择回调(模式)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(模式.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Text(模式.描述)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if 模式 == 当前模式 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.主题色)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 扩展

extension View {
    /// 添加底部弹窗容器
    func 底部弹窗(弹窗类型: Binding<底部弹窗类型?>) -> some View {
        modifier(底部弹窗容器(弹窗类型: 弹窗类型))
    }
}

// MARK: - 崩溃日志报告页面

/// 崩溃日志报告页面
private struct 崩溃日志报告页面: View {
    /// 崩溃日志列表
    @State private var 崩溃日志列表: [崩溃日志模型] = []
    /// 选中的崩溃日志（用于显示详情）
    @State private var 选中日志: 崩溃日志模型?
    /// 显示清除确认弹窗
    @State private var 显示清除确认 = false

    var body: some View {
        NavigationStack {
            Group {
                if 崩溃日志列表.isEmpty {
                    // 空状态
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.成功色)
                        Text("暂无崩溃日志")
                            .font(.system(size: 17, weight: .medium))
                        Text("APP 运行稳定，未检测到崩溃")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(崩溃日志列表) { 日志 in
                            Button {
                                选中日志 = 日志
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red)
                                        Text(日志.名称)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(日志.时间显示)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Text(日志.原因)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    HStack(spacing: 8) {
                                        Label(日志.app版本, systemImage: "app")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Label("iOS \(日志.iOS版本)", systemImage: "iphone")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    崩溃日志收集器.共享.删除崩溃日志(日志.id)
                                    崩溃日志列表 = 崩溃日志收集器.共享.读取所有崩溃日志()
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("崩溃日志报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !崩溃日志列表.isEmpty {
                        Button {
                            显示清除确认 = true
                        } label: {
                            Text("清除")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .onAppear {
                崩溃日志列表 = 崩溃日志收集器.共享.读取所有崩溃日志()
            }
            .alert("确认清除", isPresented: $显示清除确认) {
                Button("取消", role: .cancel) {}
                Button("清除全部", role: .destructive) {
                    崩溃日志收集器.共享.清除所有崩溃日志()
                    崩溃日志列表 = []
                }
            } message: {
                Text("确定要清除所有崩溃日志吗？此操作不可恢复。")
            }
            .sheet(item: $选中日志) { 日志 in
                崩溃日志详情页面(日志: 日志)
            }
        }
    }
}

// MARK: - 崩溃日志详情页面

/// 崩溃日志详情页面
private struct 崩溃日志详情页面: View {
    /// 崩溃日志
    let 日志: 崩溃日志模型
    /// 显示导出成功提示
    @State private var 显示导出成功 = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 基本信息卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                            Text(日志.名称)
                                .font(.system(size: 18, weight: .bold))
                            Spacer()
                        }

                        详情行(标签: "崩溃时间", 值: 日志.时间显示)
                        详情行(标签: "崩溃原因", 值: 日志.原因)
                        详情行(标签: "APP 版本", 值: 日志.app版本)
                        详情行(标签: "iOS 版本", 值: 日志.iOS版本)
                        详情行(标签: "设备型号", 值: 日志.设备信息.型号)
                    }
                    .padding(16)
                    .background(Color.卡片背景)
                    .cornerRadius(12)

                    // 调用栈卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "stack")
                                .font(.system(size: 16))
                                .foregroundColor(.主题色)
                            Text("调用栈信息")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }

                        ForEach(Array(日志.调用栈.enumerated()), id: \.offset) { 索引, 栈帧 in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(索引)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.主题色)
                                    .frame(width: 24, alignment: .center)
                                Text(栈帧)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            if 索引 < 日志.调用栈.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.卡片背景)
                    .cornerRadius(12)

                    // 导出按钮
                    Button {
                        导出崩溃日志()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                            Text("导出崩溃报告")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(Color.主题色)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .background(Color.页面背景.ignoresSafeArea())
            .navigationTitle("崩溃详情")
            .navigationBarTitleDisplayMode(.inline)
            .alert("导出成功", isPresented: $显示导出成功) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("崩溃报告已复制到剪贴板")
            }
        }
    }

    /// 详情行
    private func 详情行(标签: String, 值: String) -> some View {
        HStack(alignment: .top) {
            Text(标签)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(值)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    /// 导出崩溃日志
    private func 导出崩溃日志() {
        let 文本 = 崩溃日志收集器.共享.导出崩溃日志(日志)
        UIPasteboard.general.string = 文本
        显示导出成功 = true
    }
}
