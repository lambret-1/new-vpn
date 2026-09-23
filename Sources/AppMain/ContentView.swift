//
//  ContentView.swift
//  NewVPN
//
//  主界面：NavigationSplitView 三栏布局（侧边导航 + 内容列表 + 详情面板）
//  一期实现完整导航框架，各页面内容在后续步骤填充
//

import SwiftUI

/// 主界面视图
struct ContentView: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        NavigationSplitView {
            侧边导航栏()
        } content: {
            内容列表栏()
        } detail: {
            详情面板栏()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - 第一栏：侧边导航

/// 侧边导航栏
private struct 侧边导航栏: View {
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        List(页面类型.allCases, selection: Binding(
            get: { 状态.当前页面 },
            set: { if let 新页面 = $0 { 状态.当前页面 = 新页面 } }
        )) { 页面 in
            NavigationLink(value: 页面) {
                Label(页面.标题, systemImage: 页面.图标)
                    .font(字体层级.正文)
            }
        }
        .navigationTitle("new VPN")
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }
}

// MARK: - 第二栏：内容列表

/// 内容列表栏
private struct 内容列表栏: View {
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        Group {
            switch 状态.当前页面 {
            case .首页:
                通用占位(图标: "house", 标题: "主控首页")
            case .节点:
                节点列表视图()
            case .订阅:
                订阅列表视图()
            case .测速:
                通用占位(图标: "gauge", 标题: "测速中心")
            case .分流:
                通用占位(图标: "arrow.triangle.branch", 标题: "分流路由")
            case .MITM重写:
                通用占位(图标: "pencil.and.outline", 标题: "MITM 重写")
            case .抓包:
                通用占位(图标: "doc.text.magnifyingglass", 标题: "HTTP 抓包")
            case .网络活动:
                通用占位(图标: "antenna.radiowaves.left.and.right", 标题: "网络活动")
            case .脚本:
                通用占位(图标: "curlybraces", 标题: "JS 脚本")
            case .日志:
                通用占位(图标: "ladybug", 标题: "调试日志")
            case .设置:
                通用占位(图标: "gearshape", 标题: "系统设置")
            case .关于:
                通用占位(图标: "info.circle", 标题: "关于本软件")
            }
        }
        .navigationTitle(状态.当前页面.标题)
        .navigationBarTitleDisplayMode(.large)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
    }

    /// 节点列表视图
    @ViewBuilder
    private func 节点列表视图() -> some View {
        List(状态.节点列表) { 节点 in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(节点.名称).font(字体层级.正文)
                    Text(节点.地址).font(字体层级.辅助说明).foregroundColor(.secondary)
                }
                Spacer()
                StateBadge(文字: 节点.延迟显示,
                          类型: (节点.测速数据?.成功 ?? false) ? .成功 : .信息,
                          带圆点: false)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                状态.当前节点ID = 节点.id
            }
        }
    }

    /// 订阅列表视图
    @ViewBuilder
    private func 订阅列表视图() -> some View {
        List(状态.订阅列表) { 订阅 in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(订阅.名称).font(字体层级.正文)
                    Spacer()
                    StateBadge(文字: 订阅.状态显示,
                              类型: 订阅.更新状态 == "成功" ? .成功 : .错误,
                              带圆点: false)
                }
                Text("\(订阅.节点数量) 个节点")
                    .font(字体层级.辅助说明)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 第三栏：详情面板

/// 详情面板栏
private struct 详情面板栏: View {
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 间距常量.标准) {
                全局状态栏()

                详情内容()
                    .padding(.horizontal, 间距常量.标准)
                    .padding(.bottom, 间距常量.标准)
            }
        }
        .background(Color.页面背景)
    }

    /// 根据当前页面返回详情内容
    @ViewBuilder
    private func 详情内容() -> some View {
        switch 状态.当前页面 {
        case .首页:
            首页详情()
        case .节点:
            节点详情()
        case .订阅:
            订阅详情()
        default:
            通用详情()
        }
    }

    /// 首页详情
    private func 首页详情() -> some View {
        VStack(spacing: 间距常量.标准) {
            AppCard(标题: "隧道状态") {
                HStack {
                    Text("当前状态").font(字体层级.正文)
                    Spacer()
                    StateBadge(文字: 状态.隧道状态.显示文字,
                              类型: 状态.隧道状态 == .运行中 ? .成功 : .信息,
                              带圆点: true)
                }
            }

            AppCard(标题: "实时流量") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("累计上行").font(字体层级.辅助说明)
                        Text(格式化字节(状态.累计上行)).font(字体层级.数据指标)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("累计下行").font(字体层级.辅助说明)
                        Text(格式化字节(状态.累计下行)).font(字体层级.数据指标)
                    }
                }
            }

            AppCard(标题: "运行信息") {
                VStack(spacing: 间距常量.中等) {
                    详情行(标签: "运行时长", 值: 格式化时长(状态.运行时长秒))
                    详情行(标签: "当前节点",
                          值: 状态.当前节点?.名称 ?? "未选择")
                }
            }
        }
    }

    /// 节点详情
    private func 节点详情() -> some View {
        AppCard(标题: "节点信息") {
            if let 节点 = 状态.当前节点 ?? 状态.节点列表.first {
                VStack(spacing: 间距常量.中等) {
                    详情行(标签: "名称", 值: 节点.名称)
                    详情行(标签: "协议", 值: 节点.协议显示)
                    详情行(标签: "地址", 值: "\(节点.地址):\(节点.端口)")
                    详情行(标签: "传输方式", 值: 节点.传输类型.rawValue)
                    详情行(标签: "TLS", 值: 节点.启用TLS ? "启用" : "未启用")
                    详情行(标签: "分组", 值: 节点.分组)
                    详情行(标签: "延迟", 值: 节点.延迟显示)
                    if let 备注 = 节点.备注 {
                        详情行(标签: "备注", 值: 备注)
                    }
                }
            } else {
                EmptyStateView(图标: "server.rack", 标题: "暂无节点",
                              按钮文字: "新增节点") {}
            }
        }
    }

    /// 订阅详情
    private func 订阅详情() -> some View {
        AppCard(标题: "订阅信息") {
            if let 订阅 = 状态.订阅列表.first {
                VStack(spacing: 间距常量.中等) {
                    详情行(标签: "名称", 值: 订阅.名称)
                    详情行(标签: "状态", 值: 订阅.状态显示)
                    详情行(标签: "节点数量", 值: "\(订阅.节点数量)")
                    详情行(标签: "自动更新",
                          值: 订阅.自动更新 ? "启用" : "禁用")
                    if let 流量 = 订阅.流量信息 {
                        if let 总 = 流量.总流量, let 用 = 流量.已用流量 {
                            详情行(标签: "已用流量",
                                  值: "\(格式化字节(用)) / \(格式化字节(总))")
                        }
                        if let 到期 = 流量.到期时间 {
                            详情行(标签: "到期时间",
                                  值: 格式化日期(到期))
                        }
                    }
                }
            } else {
                EmptyStateView(图标: "arrow.down.circle", 标题: "暂无订阅")
            }
        }
    }

    /// 通用详情占位
    private func 通用详情() -> some View {
        AppCard(标题: 状态.当前页面.标题) {
            EmptyStateView(图标: 状态.当前页面.图标,
                          标题: "\(状态.当前页面.标题)模块",
                          说明: "功能将在后续版本实现")
        }
    }

    /// 详情行
    private func 详情行(标签: String, 值: String) -> some View {
        HStack {
            Text(标签).font(字体层级.正文).foregroundColor(.secondary)
            Spacer()
            Text(值).font(字体层级.正文)
        }
    }

    /// 格式化字节
    private func 格式化字节(_ 字节: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: 字节, countStyle: .binary)
    }

    /// 格式化时长
    private func 格式化时长(_ 秒: Int) -> String {
        let 小时 = 秒 / 3600
        let 分钟 = (秒 % 3600) / 60
        let 剩余秒 = 秒 % 60
        return String(format: "%02d:%02d:%02d", 小时, 分钟, 剩余秒)
    }

    /// 格式化日期
    private func 格式化日期(_ 日期: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: 日期)
    }
}

// MARK: - 通用占位视图

/// 通用列表占位
private struct 通用占位: View {
    let 图标: String
    let 标题: String

    var body: some View {
        EmptyStateView(图标: 图标, 标题: 标题,
                      说明: "功能将在后续版本实现")
    }
}

// MARK: - 预览

#Preview("主界面") {
    ContentView()
        .environmentObject(AppState.共享)
}
