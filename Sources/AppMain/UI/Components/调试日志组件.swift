//
//  调试日志组件.swift
//  NewVPN
//
//  调试日志相关 UI 组件
//  日志列表、搜索、过滤、复制、导出、设置
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
    /// 是否显示设置面板
    @State private var 显示设置 = false
    /// 日志输出窗口的 ScrollView 代理
    @State private var 滚动代理: ScrollViewProxy?

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
        .sheet(isPresented: $显示设置) {
            日志设置面板()
                .environmentObject(日志管理)
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

            // 设置按钮
            Button {
                显示设置 = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
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
        ZStack {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.页面背景)
    }

    private var 日志列表: some View {
        ScrollViewReader { 代理 in
            ScrollView {
                LazyVStack(spacing: 8, pinnedViews: []) {
                    // 错误/警告/调试分组（可折叠）
                    ForEach(日志管理.分组后的日志列表) { 分组 in
                        日志分组视图(
                            分组: 分组,
                            简洁模式: 日志管理.简洁模式,
                            复制回调: { 日志 in 复制单条日志(日志) }
                        )
                    }

                    // 信息平铺显示（无分组）
                    if !日志管理.未分组日志列表.isEmpty {
                        LazyVStack(spacing: 日志管理.简洁模式 ? 2 : 4) {
                            ForEach(日志管理.未分组日志列表) { 日志 in
                                日志行(
                                    日志: 日志,
                                    简洁模式: 日志管理.简洁模式,
                                    复制回调: { 复制单条日志(日志) }
                                )
                                .id(日志.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
            }
            .onAppear {
                滚动代理 = 代理
            }
            .onChange(of: 日志管理.日志列表.count) { _ in
                if 日志管理.配置.自动滚动, let 最后一条 = 日志管理.筛选后的日志列表.last {
                    withAnimation {
                        代理.scrollTo(最后一条.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 日志分组视图

    private struct 日志分组视图: View {
        let 分组: 调试日志管理器.日志分组
        let 简洁模式: Bool
        let 复制回调: (日志模型) -> Void

        /// 分组对应颜色
        private var 分组颜色: Color {
            switch 分组.分组名 {
            case "错误日志": return .危险色
            case "警告日志": return .警告色
            case "debug": return Color(red: 0.56, green: 0.38, blue: 0.95) // 紫色
            case "调试日志": return .主题色
            case "追踪日志": return .secondary
            default: return .secondary
            }
        }

        var body: some View {
            VStack(spacing: 4) {
                // 分组标题栏（不可折叠，直接显示）
                HStack(spacing: 8) {
                    Circle()
                        .fill(分组颜色)
                        .frame(width: 8, height: 8)

                    Text(分组.分组名)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    Text("\(分组.日志.count) 条")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(分组颜色.opacity(0.1))
                        .cornerRadius(4)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.卡片背景)
                .cornerRadius(8)

                // 分组内容（直接展开显示，无折叠）
                LazyVStack(spacing: 简洁模式 ? 2 : 4) {
                    ForEach(分组.日志) { 日志 in
                        日志行(
                            日志: 日志,
                            简洁模式: 简洁模式,
                            复制回调: { 复制回调(日志) }
                        )
                        .id(日志.id)
                    }
                }
            }
        }
    }

    // MARK: - 单条日志行

    private struct 日志行: View {
        let 日志: 日志模型
        let 简洁模式: Bool
        let 复制回调: () -> Void
        @State private var 显示详情 = false

        var body: some View {
            VStack(spacing: 0) {
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

                            // 有附加信息时显示展开按钮
                            if 日志.堆栈 != nil || 日志.附加字段 != nil {
                                Button {
                                    withAnimation { 显示详情.toggle() }
                                } label: {
                                    Image(systemName: 显示详情 ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        // 日志内容
                        Text(日志.内容)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    // 复制按钮（简洁模式下隐藏）
                    if !简洁模式 {
                        Button(action: 复制回调) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 简洁模式 ? 4 : 12)
                .padding(.vertical, 简洁模式 ? 4 : 8)
                .background(简洁模式 ? Color.clear : Color.卡片背景)
                .cornerRadius(简洁模式 ? 0 : 8)

                // 详情展开区域
                if 显示详情 {
                    VStack(alignment: .leading, spacing: 6) {
                        if let 堆栈 = 日志.堆栈 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("堆栈")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.危险色)
                                Text(堆栈)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let 附加 = 日志.附加字段, !附加.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("附加字段")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.主题色)
                                ForEach(Array(附加.keys.sorted()), id: \.self) { 键 in
                                    HStack(alignment: .top) {
                                        Text(键)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .leading)
                                        Text(附加[键] ?? "")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .background(Color.卡片背景.opacity(0.5))
                }
            }
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
            case .致命: return Color(red: 0.56, green: 0.38, blue: 0.95)
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
            if let 堆栈 = 日志.堆栈 {
                文本 += "堆栈：\(堆栈)\n"
            }
        }

        UIPasteboard.general.string = 文本
        显示复制成功提示()
    }

    /// 复制单条日志到剪贴板
    private func 复制单条日志(_ 日志: 日志模型) {
        let 日期格式化 = DateFormatter()
        日期格式化.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let 时间 = 日期格式化.string(from: 日志.时间)
        var 文本 = "[\(时间)] [\(日志.级别.rawValue)] [\(日志.模块)] \(日志.内容)"
        if let 堆栈 = 日志.堆栈 {
            文本 += "\n堆栈：\(堆栈)"
        }
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
        case .致命: return Color(red: 0.56, green: 0.38, blue: 0.95)
        case .错误: return .危险色
        case .警告: return .警告色
        case .信息: return .成功色
        case .调试: return .secondary
        case .追踪: return .secondary
        }
    }
}

// MARK: - 日志设置面板

/// 日志设置面板
private struct 日志设置面板: View {
    @EnvironmentObject private var 日志管理: 调试日志管理器
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationView {
            List {
                Section("输出设置") {
                    // 最低输出级别
                    HStack {
                        Text("最低输出级别")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { 日志管理.配置.最低输出级别 },
                            set: { 日志管理.配置.最低输出级别 = $0 }
                        )) {
                            ForEach(日志级别.allCases, id: \.self) { 级别 in
                                Text(级别.rawValue).tag(级别)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // 自动滚动
                    Toggle("自动滚动到最新", isOn: Binding(
                        get: { 日志管理.配置.自动滚动 },
                        set: { 日志管理.配置.自动滚动 = $0 }
                    ))

                    // 敏感信息脱敏
                    Toggle("敏感信息脱敏", isOn: Binding(
                        get: { 日志管理.配置.启用脱敏 },
                        set: { 日志管理.配置.启用脱敏 = $0 }
                    ))
                }

                Section("缓冲区设置") {
                    // 缓冲区大小
                    HStack {
                        Text("内存缓冲区")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { 日志管理.配置.最大日志条数 },
                            set: { 日志管理.配置.最大日志条数 = $0 }
                        )) {
                            Text("500 条").tag(500)
                            Text("1000 条").tag(1000)
                            Text("2000 条").tag(2000)
                            Text("5000 条").tag(5000)
                        }
                        .pickerStyle(.menu)
                    }

                    // 单条最大字符数
                    HStack {
                        Text("单条最大字符")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { 日志管理.配置.单条最大字符数 },
                            set: { 日志管理.配置.单条最大字符数 = $0 }
                        )) {
                            Text("1024").tag(1024)
                            Text("2048").tag(2048)
                            Text("4096").tag(4096)
                            Text("8192").tag(8192)
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("文件日志") {
                    // 启用文件日志
                    Toggle("启用文件日志", isOn: Binding(
                        get: { 日志管理.配置.启用文件日志 },
                        set: { 日志管理.配置.启用文件日志 = $0 }
                    ))

                    // 单文件最大大小
                    HStack {
                        Text("单文件最大")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { 日志管理.配置.单文件最大MB },
                            set: { 日志管理.配置.单文件最大MB = $0 }
                        )) {
                            Text("1 MB").tag(1)
                            Text("5 MB").tag(5)
                            Text("10 MB").tag(10)
                            Text("20 MB").tag(20)
                        }
                        .pickerStyle(.menu)
                    }

                    // 文件数量上限
                    HStack {
                        Text("文件数量上限")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { 日志管理.配置.文件数量上限 },
                            set: { 日志管理.配置.文件数量上限 = $0 }
                        )) {
                            Text("5 个").tag(5)
                            Text("10 个").tag(10)
                            Text("20 个").tag(20)
                        }
                        .pickerStyle(.menu)
                    }

                    // 日志文件列表
                    if !日志管理.获取日志文件列表().isEmpty {
                        NavigationLink {
                            日志文件列表()
                        } label: {
                            HStack {
                                Text("日志文件")
                                Spacer()
                                Text("\(日志管理.获取日志文件列表().count) 个文件")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("统计") {
                    HStack {
                        Text("总日志数")
                        Spacer()
                        Text("\(日志管理.日志列表.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("今日日志")
                        Spacer()
                        Text("\(日志管理.今日日志数量)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("日志设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { 关闭() }
                }
            }
        }
    }
}

// MARK: - 日志文件列表

/// 日志文件列表
private struct 日志文件列表: View {
    @EnvironmentObject private var 日志管理: 调试日志管理器
    @State private var 文件列表: [URL] = []

    var body: some View {
        List {
            ForEach(文件列表, id: \.self) { 文件 in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(文件.lastPathComponent)
                            .font(.system(size: 14))
                        if let 大小 = 文件大小(文件) {
                            Text(大小)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    // 分享按钮
                    Button {
                        分享文件(文件)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.主题色)
                    }
                }
            }
            .onDelete(perform: 删除文件)
        }
        .navigationTitle("日志文件")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            文件列表 = 日志管理.获取日志文件列表()
        }
    }

    /// 获取文件大小字符串
    private func 文件大小(_ 文件: URL) -> String? {
        guard let 属性 = try? 文件.resourceValues(forKeys: [.fileSizeKey]),
              let 字节数 = 属性.fileSize else { return nil }
        let 格式化 = ByteCountFormatter()
        格式化.allowedUnits = [.useKB, .useMB]
        return 格式化.string(fromByteCount: Int64(字节数))
    }

    /// 分享文件
    private func 分享文件(_ 文件: URL) {
        let 活动控制器 = UIActivityViewController(activityItems: [文件], applicationActivities: nil)
        if let 窗口 = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first(where: { $0.isKeyWindow }) {
            窗口.rootViewController?.present(活动控制器, animated: true)
        }
    }

    /// 删除文件
    private func 删除文件(at 偏移: IndexSet) {
        for 索引 in 偏移 {
            let 文件 = 文件列表[索引]
            try? FileManager.default.removeItem(at: 文件)
        }
        文件列表 = 日志管理.获取日志文件列表()
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
