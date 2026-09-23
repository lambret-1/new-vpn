//
//  隧道组件.swift
//  NewVPN
//
//  隧道相关 UI 组件
//  状态展示、连接按钮、流量统计、隧道日志
//

import SwiftUI

// MARK: - 隧道状态指示器

/// 隧道状态指示器
struct 隧道状态指示器: View {
    /// 隧道状态
    let 状态: 隧道状态

    var body: some View {
        HStack(spacing: 6) {
            // 状态圆点
            ZStack {
                Circle()
                    .fill(状态颜色.opacity(0.2))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(状态颜色)
                    .frame(width: 6, height: 6)
                if 状态 == .正在连接 || 状态 == .重新加载中 {
                    Circle()
                        .stroke(状态颜色, lineWidth: 1.5)
                        .frame(width: 12, height: 12)
                        .scaleEffect(1.5)
                        .opacity(0.0)
                        .animation(Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: UUID())
                }
            }

            // 状态文字
            Text(状态.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(状态颜色)
        }
    }

    /// 状态颜色
    private var 状态颜色: Color {
        switch 状态 {
        case .已连接: return .成功色
        case .正在连接, .重新加载中: return .警告色
        case .已断开: return .secondary
        case .正在断开: return .警告色
        case .连接失败, .配置无效: return .危险色
        }
    }
}

// MARK: - 隧道连接开关

/// 隧道连接开关按钮
struct 隧道连接开关: View {
    @EnvironmentObject private var 隧道管理: 隧道管理器
    /// 节点 ID（可选）
    var 节点ID: UUID? = nil
    /// 节点名称（可选）
    var 节点名称: String? = nil

    var body: some View {
        Button {
            隧道管理.切换连接(节点ID: 节点ID, 节点名称: 节点名称)
        } label: {
            ZStack {
                // 背景圆
                Circle()
                    .fill(背景颜色)
                    .frame(width: 52, height: 52)
                    .shadow(color: 阴影颜色.opacity(0.3), radius: 8, x: 0, y: 4)

                // 图标
                if 隧道管理.当前状态 == .正在连接 || 隧道管理.当前状态 == .重新加载中 {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: 图标名称)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(隧道管理.是否加载中)
    }

    /// 图标名称
    private var 图标名称: String {
        隧道管理.当前状态.是否活动 ? "power" : "power"
    }

    /// 背景颜色
    private var 背景颜色: Color {
        switch 隧道管理.当前状态 {
        case .已连接: return .成功色
        case .正在连接, .重新加载中: return .警告色
        case .已断开, .正在断开: return .主题色
        case .连接失败, .配置无效: return .危险色
        }
    }

    /// 阴影颜色
    private var 阴影颜色: Color {
        背景颜色
    }
}

// MARK: - 隧道流量统计卡片

/// 隧道流量统计卡片
struct 隧道流量统计卡片: View {
    @EnvironmentObject private var 隧道管理: 隧道管理器

    var body: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 14))
                    .foregroundColor(.主题色)
                Text("流量统计")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                if 隧道管理.当前状态.是否活动 {
                    Text(隧道管理.流量统计.连接时长显示)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.主题色)
                        .monospacedDigit()
                }
            }

            // 流量数据
            HStack(spacing: 16) {
                // 上行
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                            .foregroundColor(.主题色)
                        Text("上行")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Text(隧道管理.流量统计.上行显示)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                    if 隧道管理.当前状态.是否活动 {
                        Text(隧道管理.流量统计.上行速度显示)
                            .font(.system(size: 10))
                            .foregroundColor(.主题色)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)

                // 分隔线
                Rectangle()
                    .fill(Color.分割线)
                    .frame(width: 1, height: 40)

                // 下行
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                            .foregroundColor(.成功色)
                        Text("下行")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Text(隧道管理.流量统计.下行显示)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                    if 隧道管理.当前状态.是否活动 {
                        Text(隧道管理.流量统计.下行速度显示)
                            .font(.system(size: 10))
                            .foregroundColor(.成功色)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)

                // 分隔线
                Rectangle()
                    .fill(Color.分割线)
                    .frame(width: 1, height: 40)

                // 总计
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "sum")
                            .font(.system(size: 10))
                            .foregroundColor(.警告色)
                        Text("总计")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Text(隧道管理.流量统计.总流量显示)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                    Text("总流量")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 隧道日志视图

/// 隧道日志列表视图
struct 隧道日志视图: View {
    @EnvironmentObject private var 隧道管理: 隧道管理器
    @State private var 搜索关键词 = ""
    @State private var 筛选级别: 隧道日志级别?

    var body: some View {
        VStack(spacing: 0) {
            // 搜索和筛选
            HStack(spacing: 8) {
                AppSearchBar(搜索文字: $搜索关键词, 占位文字: "搜索日志")
                    .frame(maxWidth: .infinity)

                Menu {
                    Button("全部") { 筛选级别 = nil }
                    ForEach(隧道日志级别.allCases, id: \.self) { 级别 in
                        Button(级别.rawValue) { 筛选级别 = 级别 }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.主题色)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)

            // 日志列表
            if 筛选后的日志.isEmpty {
                EmptyStateView(
                    图标: "doc.text",
                    标题: "暂无日志",
                    说明: "隧道运行日志会显示在这里"
                )
            } else {
                List {
                    ForEach(筛选后的日志) { 日志 in
                        日志行(日志: 日志)
                            .listRowInsets(EdgeInsets(top: 2, leading: 15, bottom: 2, trailing: 15))
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
                    隧道管理.清除日志()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.危险色)
                }
            }
        }
    }

    /// 筛选后的日志
    private var 筛选后的日志: [隧道日志模型] {
        隧道管理.日志列表.filter { 日志 in
            // 搜索筛选
            if !搜索关键词.isEmpty {
                let 关键词 = 搜索关键词.lowercased()
                if !日志.内容.lowercased().contains(关键词) &&
                   !日志.模块.lowercased().contains(关键词) {
                    return false
                }
            }
            // 级别筛选
            if let 级别 = 筛选级别, 日志.级别 != 级别 {
                return false
            }
            return true
        }
    }

    /// 单条日志行
    private struct 日志行: View {
        let 日志: 隧道日志模型

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                // 级别标识
                Circle()
                    .fill(级别颜色)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(日志.模块)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.主题色)
                        Text(日志.时间显示)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Text(日志.内容)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.卡片背景)
            .cornerRadius(8)
        }

        /// 级别颜色
        private var 级别颜色: Color {
            switch 日志.级别 {
            case .调试: return .secondary
            case .信息: return .主题色
            case .警告: return .警告色
            case .错误: return .危险色
            case .关闭: return .secondary
            }
        }
    }
}

// MARK: - 隧道设置页面

/// 隧道设置页面
struct 隧道设置页面: View {
    @EnvironmentObject private var 隧道管理: 隧道管理器
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        Form {
            Section("基本设置") {
                AppFormRow(标签: "隧道名称") {
                    TextField("NewVPN 隧道", text: $隧道管理.配置.隧道名称)
                        .multilineTextAlignment(.trailing)
                }

                AppFormRow(标签: "服务器地址") {
                    TextField("显示用地址", text: $隧道管理.配置.服务器地址)
                        .multilineTextAlignment(.trailing)
                        .autocapitalization(.none)
                }

                AppFormRow(标签: "MTU") {
                    TextField("1500", value: $隧道管理.配置.MTU, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }

            Section("连接设置") {
                Toggle("按需连接", isOn: $隧道管理.配置.按需连接)
                    .tint(.主题色)

                Toggle("蜂窝网络下连接", isOn: $隧道管理.配置.蜂窝网络连接)
                    .tint(.主题色)

                Toggle("WiFi 下连接", isOn: $隧道管理.配置.WiFi连接)
                    .tint(.主题色)

                Toggle("断开时阻止所有流量", isOn: $隧道管理.配置.断开阻止流量)
                    .tint(.主题色)
            }

            Section("DNS 设置") {
                ForEach($隧道管理.配置.DNS服务器, id: \.self) { $服务器 in
                    TextField("DNS 服务器", text: $服务器)
                        .autocapitalization(.none)
                        .keyboardType(.numbersAndPunctuation)
                }
                .onDelete { 索引集 in
                    隧道管理.配置.DNS服务器.remove(atOffsets: 索引集)
                }

                Button {
                    隧道管理.配置.DNS服务器.append("")
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.主题色)
                        Text("添加 DNS 服务器")
                            .foregroundColor(.主题色)
                    }
                }
            }

            Section("日志设置") {
                Picker("日志级别", selection: $隧道管理.配置.日志级别) {
                    ForEach(隧道日志级别.allCases, id: \.self) { 级别 in
                        Text(级别.rawValue).tag(级别)
                    }
                }

                Toggle("启用流量统计", isOn: $隧道管理.配置.启用流量统计)
                    .tint(.主题色)
            }

            Section {
                Button {
                    隧道管理.保存配置()
                    关闭()
                } label: {
                    HStack {
                        Spacer()
                        Text("保存配置")
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
            }
        }
        .navigationTitle("隧道设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 预览

#Preview("隧道状态指示器") {
    VStack(spacing: 20) {
        隧道状态指示器(状态: .已连接)
        隧道状态指示器(状态: .正在连接)
        隧道状态指示器(状态: .已断开)
    }
    .padding()
    .background(Color.页面背景)
}

#Preview("流量统计卡片") {
    隧道流量统计卡片()
        .environmentObject(隧道管理器.共享)
        .padding()
        .background(Color.页面背景)
}
