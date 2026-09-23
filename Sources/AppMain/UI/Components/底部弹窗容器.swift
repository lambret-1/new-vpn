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
    /// 是否显示证书与描述文件页面
    @State private var 显示证书页面 = false

    var body: some View {
        List {
            Section("通用") {
                Label("外观主题", systemImage: "paintpalette")
                Label("语言", systemImage: "globe")
                Label("启动时自动连接", systemImage: "power")
            }
            Section("网络") {
                Label("DNS 设置", systemImage: "network")
                Label("代理模式", systemImage: "arrow.left.arrow.right")
                Label("分流规则", systemImage: "arrow.triangle.branch")
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
                Label("开源许可", systemImage: "scroll")
            }
        }
        .listStyle(.insetGrouped)
        .fullScreenCover(isPresented: $显示证书页面) {
            证书与描述文件页面()
                .environmentObject(证书管理)
        }
    }
}

// MARK: - 扩展

extension View {
    /// 添加底部弹窗容器
    func 底部弹窗(弹窗类型: Binding<底部弹窗类型?>) -> some View {
        modifier(底部弹窗容器(弹窗类型: 弹窗类型))
    }
}
