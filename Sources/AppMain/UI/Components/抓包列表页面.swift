//
//  抓包列表页面.swift
//  NewVPN
//
//  HTTP 抓包记录列表页面，展示捕获的 HTTP 请求/响应
//  第一期：列表展示 + 搜索 + 清空，详情页后续实现
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.页面背景.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 抓包功能开关
                    抓包开关行

                    if 显示列表.isEmpty {
                        空态视图
                    } else {
                        抓包列表视图
                    }
                }
            }
            .navigationTitle("HTTP 抓包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        存储.清空记录()
                        刷新列表()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(显示列表.isEmpty)
                }
            }
            .searchable(text: $搜索词, prompt: "搜索 URL / 域名 / 路径")
            .onChange(of: 搜索词) { _ in
                筛选.关键词 = 搜索词
                刷新列表()
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

    // MARK: - 抓包开关行

    private var 抓包开关行: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("启用 HTTP 抓包")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text("开启后需重启 VPN 生效，仅捕获 HTTP 流量")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - 列表视图

    private var 抓包列表视图: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(显示列表) { 记录 in
                    抓包记录卡片(记录: 记录)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - 空态视图

    private var 空态视图: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if !隧道管理.当前状态.是否活动 {
                Text("VPN 未连接")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("请先连接 VPN，然后开启 HTTP 抓包功能")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if !存储.是否启用 {
                Text("抓包未启用")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("请在设置 → 网络 → HTTP 抓包中开启功能")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("等待 HTTP 请求...")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("访问网页或使用 App 后，抓包记录将显示在这里")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
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

// MARK: - 抓包记录卡片

/// 单条抓包记录卡片
private struct 抓包记录卡片: View {
    let 记录: 抓包记录

    var body: some View {
        HStack(spacing: 12) {
            // 方法标签
            方法标签(方法: 记录.请求方法)

            // 主内容
            VStack(alignment: .leading, spacing: 4) {
                // URL 路径
                Text(记录.请求路径)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 域名 + 状态码 + 耗时
                HStack(spacing: 8) {
                    Text(记录.请求主机)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if let 状态码 = 记录.响应状态码 {
                        状态码标签(状态码: 状态码)
                    } else if 记录.错误信息 != nil {
                        Text("失败")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    } else {
                        Text("...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Text(记录.耗时显示)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }

            // HTTPS 标识
            if 记录.是否HTTPS {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.卡片背景)
        .cornerRadius(10)
    }
}

// MARK: - 方法标签

/// HTTP 方法标签
private struct 方法标签: View {
    let 方法: String

    var body: some View {
        Text(方法.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 48, height: 24)
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
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(状态码颜色)
            .frame(width: 40, alignment: .trailing)
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
