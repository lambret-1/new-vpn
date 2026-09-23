//
//  SingBox组件.swift
//  NewVPN
//
//  sing-box 内核相关 UI 组件
//  内核状态、日志查看、配置预览
//

import SwiftUI

// MARK: - sing-box 内核状态卡片

/// sing-box 内核状态卡片
struct SingBox内核状态卡片: View {
    @EnvironmentObject private var 内核管理: SingBox内核管理器

    var body: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 14))
                    .foregroundColor(.主题色)
                Text("sing-box 内核")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                // 状态标签
                HStack(spacing: 4) {
                    Circle()
                        .fill(状态颜色)
                        .frame(width: 8, height: 8)
                    Text(内核管理.内核状态.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(状态颜色)
                }
            }

            // 信息行
            HStack(spacing: 16) {
                // 版本
                VStack(alignment: .leading, spacing: 2) {
                    Text("版本")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(内核管理.内核版本)
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                }

                // 运行时长
                VStack(alignment: .leading, spacing: 2) {
                    Text("运行时长")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(内核管理.运行时长显示)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.主题色)
                        .monospacedDigit()
                }

                Spacer()

                // 配置信息
                VStack(alignment: .trailing, spacing: 2) {
                    Text("出站")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(内核管理.当前配置?.outbounds?.count ?? 0) 个")
                        .font(.system(size: 14, weight: .medium))
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("规则")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(内核管理.当前配置?.route?.rules?.count ?? 0) 条")
                        .font(.system(size: 14, weight: .medium))
                }
            }

            // 错误提示
            if let 错误 = 内核管理.最近错误 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundColor(.危险色)
                    Text(错误)
                        .font(.system(size: 12))
                        .foregroundColor(.危险色)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.危险色.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    /// 状态颜色
    private var 状态颜色: Color {
        switch 内核管理.内核状态 {
        case .运行中: return .成功色
        case .正在启动: return .警告色
        case .未启动, .已停止: return .secondary
        case .正在停止: return .警告色
        case .启动失败, .配置错误: return .危险色
        }
    }
}

// MARK: - sing-box 内核日志视图

/// sing-box 内核日志列表视图
struct SingBox内核日志视图: View {
    @EnvironmentObject private var 内核管理: SingBox内核管理器
    @State private var 搜索关键词 = ""
    @State private var 筛选级别: String?

    private let 级别列表 = ["trace", "debug", "info", "warn", "error", "fatal"]

    var body: some View {
        VStack(spacing: 0) {
            // 搜索和筛选
            HStack(spacing: 8) {
                AppSearchBar(搜索文字: $搜索关键词, 占位文字: "搜索日志")
                    .frame(maxWidth: .infinity)

                Menu {
                    Button("全部") { 筛选级别 = nil }
                    ForEach(级别列表, id: \.self) { 级别 in
                        Button(级别.uppercased()) { 筛选级别 = 级别 }
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
                    标题: "暂无内核日志",
                    说明: "sing-box 内核运行日志会显示在这里"
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
                    内核管理.清除日志()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.危险色)
                }
            }
        }
    }

    /// 筛选后的日志
    private var 筛选后的日志: [SingBox内核日志] {
        内核管理.日志列表.filter { 日志 in
            // 搜索筛选
            if !搜索关键词.isEmpty {
                if !日志.内容.lowercased().contains(搜索关键词.lowercased()) {
                    return false
                }
            }
            // 级别筛选
            if let 级别 = 筛选级别, 日志.级别.lowercased() != 级别.lowercased() {
                return false
            }
            return true
        }
    }

    /// 单条日志行
    private struct 日志行: View {
        let 日志: SingBox内核日志

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                // 级别标识
                Text(日志.级别.prefix(1).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(级别颜色)
                    .cornerRadius(4)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(日志.时间显示)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    Text(日志.内容)
                        .font(.system(size: 13, design: .monospaced))
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
            switch 日志.级别.lowercased() {
            case "trace", "debug": return .secondary
            case "info": return .主题色
            case "warn": return .警告色
            case "error", "fatal", "panic": return .危险色
            default: return .secondary
            }
        }
    }
}

// MARK: - sing-box 配置预览页面

/// sing-box 配置预览页面
struct SingBox配置预览页面: View {
    @EnvironmentObject private var 内核管理: SingBox内核管理器
    @State private var 显示复制提示 = false

    var body: some View {
        VStack(spacing: 0) {
            // 操作栏
            HStack {
                if let 配置 = 内核管理.当前配置 {
                    Text("入站：\(配置.inbounds?.count ?? 0) 出站：\(配置.outbounds?.count ?? 0) 规则：\(配置.route?.rules?.count ?? 0)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    复制配置()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundColor(.主题色)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(Color.卡片背景)

            // 配置内容
            if let JSON = 内核管理.当前配置JSON {
                ScrollView {
                    Text(JSON)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                }
            } else {
                EmptyStateView(
                    图标: "doc.text",
                    标题: "暂无配置",
                    说明: "生成配置后会在这里显示"
                )
            }

            // 复制提示
            if 显示复制提示 {
                Text("配置已复制到剪贴板")
                    .font(.system(size: 12))
                    .foregroundColor(.成功色)
                    .padding(.vertical, 8)
            }
        }
        .background(Color.页面背景)
        .navigationTitle("sing-box 配置")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 复制配置到剪贴板
    private func 复制配置() {
        guard let JSON = 内核管理.当前配置JSON else { return }
        UIPasteboard.general.string = JSON
        显示复制提示 = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            显示复制提示 = false
        }
    }
}

// MARK: - sing-box 内核设置页面

/// sing-box 内核设置页面
struct SingBox内核设置页面: View {
    @EnvironmentObject private var 内核管理: SingBox内核管理器
    @EnvironmentObject private var 状态: AppState
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        Form {
            Section("内核信息") {
                AppFormRow(标签: "内核版本") {
                    Text(内核管理.内核版本)
                        .foregroundColor(.secondary)
                }
                AppFormRow(标签: "运行状态") {
                    Text(内核管理.内核状态.rawValue)
                        .foregroundColor(状态颜色)
                }
                if 内核管理.内核状态 == .运行中 {
                    AppFormRow(标签: "运行时长") {
                        Text(内核管理.运行时长显示)
                            .foregroundColor(.主题色)
                            .monospacedDigit()
                    }
                }
            }

            Section("配置生成") {
                Button {
                    生成配置()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.2")
                            .foregroundColor(.主题色)
                        Text("生成当前配置")
                            .foregroundColor(.主题色)
                        Spacer()
                        if 内核管理.是否加载中 {
                            ProgressView()
                        }
                    }
                }

                NavigationLink {
                    SingBox配置预览页面()
                        .environmentObject(内核管理)
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.主题色)
                        Text("查看配置")
                        Spacer()
                        if 内核管理.当前配置 != nil {
                            Text("已生成")
                                .font(.system(size: 12))
                                .foregroundColor(.成功色)
                        } else {
                            Text("未生成")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("日志") {
                NavigationLink {
                    SingBox内核日志视图()
                        .environmentObject(内核管理)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.主题色)
                        Text("内核日志")
                        Spacer()
                        Text("\(内核管理.日志列表.count) 条")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    内核管理.清除日志()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.危险色)
                        Text("清除日志")
                            .foregroundColor(.危险色)
                        Spacer()
                    }
                }
            }

            Section("内核控制") {
                if 内核管理.内核状态.是否活动 {
                    Button {
                        内核管理.停止内核()
                    } label: {
                        HStack {
                            Spacer()
                            Text("停止内核")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.危险色)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.危险色.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Button {
                        内核管理.重启内核()
                    } label: {
                        HStack {
                            Spacer()
                            Text("重启内核")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.警告色)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.警告色.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } else {
                    Button {
                        启动内核()
                    } label: {
                        HStack {
                            Spacer()
                            if 内核管理.是否加载中 {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("启动内核")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.成功色)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .disabled(内核管理.当前配置 == nil || 内核管理.是否加载中)
                }
            }
        }
        .navigationTitle("sing-box 内核")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 状态颜色
    private var 状态颜色: Color {
        switch 内核管理.内核状态 {
        case .运行中: return .成功色
        case .正在启动: return .警告色
        case .未启动, .已停止: return .secondary
        case .正在停止: return .警告色
        case .启动失败, .配置错误: return .危险色
        }
    }

    /// 生成配置
    private func 生成配置() {
        // 获取当前选中的节点
        let 当前节点 = 状态.节点分组列表
            .flatMap { $0.节点列表 }
            .first(where: { $0.id == 状态.当前选中节点ID })

        // 获取所有节点
        let 所有节点 = 状态.节点分组列表.flatMap { $0.节点列表 }

        _ = 内核管理.生成并保存配置(
            节点: 当前节点,
            节点列表: 所有节点,
            分流规则: [],
            DNS配置: nil
        )
    }

    /// 启动内核
    private func 启动内核() {
        guard let 配置 = 内核管理.当前配置 else {
            生成配置()
            return
        }
        内核管理.启动内核(配置: 配置)
    }
}

// MARK: - 预览

#Preview("内核状态卡片") {
    SingBox内核状态卡片()
        .environmentObject(SingBox内核管理器.共享)
        .padding()
        .background(Color.页面背景)
}
