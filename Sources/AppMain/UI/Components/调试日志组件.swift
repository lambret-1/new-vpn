//
//  调试日志组件.swift
//  NewVPN
//
//  调试日志相关 UI 组件
//  日志列表、搜索、过滤、复制、导出
//

import SwiftUI

// MARK: - 调试日志内容区

/// 调试日志内容区
struct 调试日志内容区: View {
    @EnvironmentObject private var 日志管理: 调试日志管理器
    /// 是否显示导出分享面板
    @State private var 显示分享面板 = false
    /// 导出文件 URL
    @State private var 导出文件URL: URL?
    /// 是否显示复制成功提示
    @State private var 显示复制成功 = false
    /// 当前选中的级别过滤（nil表示全部）
    @State private var 选中级别: 日志级别?

    var body: some View {
        VStack(spacing: 0) {
            // 统计栏（可点击过滤）
            统计栏
                .padding(.horizontal, 15)
                .padding(.vertical, 8)

            // 搜索和过滤栏
            搜索过滤栏
                .padding(.horizontal, 15)
                .padding(.bottom, 8)

            // 日志输出窗口（使用 frame 确保占据剩余空间）
            日志输出窗口
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 复制成功提示
            if 显示复制成功 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.成功色)
                    Text("已复制到剪贴板")
                        .font(.system(size: 12))
                        .foregroundColor(.成功色)
                }
                .padding(.vertical, 6)
                .transition(.opacity)
            }
        }
        .background(Color.页面背景)
        .sheet(isPresented: $显示分享面板) {
            if let url = 导出文件URL {
                分享视图(分享内容: [url])
            }
        }
    }

    // MARK: - 统计栏（可点击过滤）

    private var 统计栏: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                统计项(
                    标题: "全部",
                    值: "\(日志管理.日志列表.count)",
                    颜色: .主题色,
                    选中: 选中级别 == nil
                ) {
                    选中级别 = nil
                    日志管理.过滤级别 = nil
                }

                ForEach(日志级别.allCases, id: \.self) { 级别 in
                    统计项(
                        标题: 级别.rawValue,
                        值: "\(日志管理.级别统计[级别] ?? 0)",
                        颜色: 级别颜色(级别),
                        选中: 选中级别 == 级别
                    ) {
                        if 选中级别 == 级别 {
                            选中级别 = nil
                            日志管理.过滤级别 = nil
                        } else {
                            选中级别 = 级别
                            日志管理.过滤级别 = 级别
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private struct 统计项: View {
        let 标题: String
        let 值: String
        let 颜色: Color
        let 选中: Bool
        let 点击: () -> Void

        var body: some View {
            Button(action: 点击) {
                VStack(spacing: 2) {
                    Text(值)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(选中 ? .white : 颜色)
                        .monospacedDigit()
                    Text(标题)
                        .font(.system(size: 10))
                        .foregroundColor(选中 ? .white.opacity(0.8) : .secondary)
                }
                .frame(width: 52)
                .padding(.vertical, 8)
                .background(选中 ? 颜色 : Color.卡片背景)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(选中 ? 颜色 : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - 搜索过滤栏

    private var 搜索过滤栏: some View {
        HStack(spacing: 8) {
            AppSearchBar(搜索文字: $日志管理.搜索关键词, 占位文字: "搜索日志")
                .frame(maxWidth: .infinity)

            // 模块过滤
            Menu {
                Button("全部模块") { 日志管理.过滤模块 = nil }
                ForEach(日志管理.所有模块列表, id: \.self) { 模块 in
                    Button(模块) { 日志管理.过滤模块 = 模块 }
                }
            } label: {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 20))
                    .foregroundColor(日志管理.过滤模块 != nil ? .主题色 : .secondary)
            }

            // 复制全部按钮
            Button {
                复制全部日志()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 20))
                    .foregroundColor(.主题色)
            }

            // 导出按钮
            Button {
                导出日志()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                    .foregroundColor(.主题色)
            }

            // 清除按钮
            Button {
                日志管理.清除日志()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 20))
                    .foregroundColor(.危险色)
            }
        }
    }

    // MARK: - 日志输出窗口

    private var 日志输出窗口: some View {
        Group {
            if 日志管理.是否加载中 {
                VStack {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                }
            } else if 日志管理.筛选后的日志列表.isEmpty {
                VStack {
                    Spacer()
                    EmptyStateView(
                        图标: "ant.fill",
                        标题: "暂无调试日志",
                        说明: "应用运行时产生的调试日志会显示在这里"
                    )
                    Spacer()
                }
            } else {
                日志列表
            }
        }
    }

    private var 日志列表: some View {
        ScrollViewReader { 代理 in
            List {
                ForEach(日志管理.筛选后的日志列表) { 日志 in
                    日志行(日志: 日志) {
                        复制单条日志(日志)
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 15, bottom: 2, trailing: 15))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .id(日志.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: 日志管理.日志列表.count) { _ in
                if 日志管理.自动滚动, let 最后一条 = 日志管理.筛选后的日志列表.last {
                    withAnimation {
                        代理.scrollTo(最后一条.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 单条日志行

    private struct 日志行: View {
        let 日志: 日志模型
        let 复制回调: () -> Void

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                // 级别标识
                Text(日志.级别.rawValue.prefix(1))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(级别颜色)
                    .cornerRadius(4)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    // 时间和模块
                    HStack(spacing: 8) {
                        Text(格式化时间(日志.时间))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        Text(日志.模块)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.主题色)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.主题色.opacity(0.1))
                            .cornerRadius(4)
                    }

                    // 日志内容
                    Text(日志.内容)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // 复制按钮
                Button(action: 复制回调) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.卡片背景)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture {
                // 点击整行也复制
                复制回调()
            }
        }

        /// 级别颜色
        private var 级别颜色: Color {
            switch 日志.级别 {
            case .致命: return .紫色
            case .错误: return .危险色
            case .警告: return .警告色
            case .信息: return .成功色
            case .调试: return .secondary
            case .追踪: return .secondary
            }
        }

        /// 格式化时间
        private func 格式化时间(_ 日期: Date) -> String {
            let 格式化 = DateFormatter()
            格式化.dateFormat = "HH:mm:ss.SSS"
            return 格式化.string(from: 日期)
        }
    }

    // MARK: - 复制功能

    /// 复制全部日志到剪贴板
    private func 复制全部日志() {
        let 日期格式化 = DateFormatter()
        日期格式化.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var 文本 = ""
        for 日志 in 日志管理.筛选后的日志列表 {
            let 时间 = 日期格式化.string(from: 日志.时间)
            文本 += "[\(时间)] [\(日志.级别.rawValue)] [\(日志.模块)] \(日志.内容)\n"
        }

        UIPasteboard.general.string = 文本
        显示复制成功提示()
    }

    /// 复制单条日志到剪贴板
    private func 复制单条日志(_ 日志: 日志模型) {
        let 日期格式化 = DateFormatter()
        日期格式化.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let 时间 = 日期格式化.string(from: 日志.时间)
        let 文本 = "[\(时间)] [\(日志.级别.rawValue)] [\(日志.模块)] \(日志.内容)"
        UIPasteboard.general.string = 文本
        显示复制成功提示()
    }

    /// 显示复制成功提示
    private func 显示复制成功提示() {
        withAnimation {
            显示复制成功 = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                显示复制成功 = false
            }
        }
    }

    // MARK: - 导出日志

    private func 导出日志() {
        if let 文件URL = 日志管理.导出日志为文本() {
            导出文件URL = 文件URL
            显示分享面板 = true
        }
    }

    // MARK: - 工具方法

    /// 级别对应颜色
    private func 级别颜色(_ 级别: 日志级别) -> Color {
        switch 级别 {
        case .致命: return .紫色
        case .错误: return .危险色
        case .警告: return .警告色
        case .信息: return .成功色
        case .调试: return .secondary
        case .追踪: return .secondary
        }
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

#Preview("调试日志内容区") {
    调试日志内容区()
        .environmentObject(调试日志管理器.共享)
        .background(Color.页面背景)
}
