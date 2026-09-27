//
//  规则与日志内容区.swift
//  NewVPN
//
//  重写规则、分流规则、日志三个内容区视图
//

import SwiftUI

// MARK: - 重写规则内容区

/// 重写规则内容区视图
struct 重写规则内容区: View {
    @EnvironmentObject private var 重写管理: 重写规则管理器
    @State private var 搜索关键词 = ""
    @State private var 展开的分组ID: UUID?
    @State private var 显示添加规则 = false
    @State private var 显示添加分组 = false
    @State private var 显示预设规则 = false
    @State private var 重命名的分组: 重写规则分组?
    @State private var 重命名名称 = ""
    @State private var 编辑的规则: 重写规则项?
    @State private var 编辑规则所在分组: 重写规则分组?

    /// 统计数据
    private var 统计: (分组数: Int, 总规则数: Int, 启用规则数: Int) {
        let 所有规则 = 重写管理.配置.分组列表.flatMap { $0.规则列表 }
        let 启用规则 = 所有规则.filter { $0.启用 }
        return (重写管理.配置.分组列表.count, 所有规则.count, 启用规则.count)
    }

    /// 过滤后的分组列表（搜索过滤）
    private var 过滤后的分组: [重写规则分组] {
        guard !搜索关键词.isEmpty else { return 重写管理.配置.分组列表 }
        return 重写管理.配置.分组列表.map { 分组 in
            let 过滤规则 = 分组.规则列表.filter { 规则 in
                规则.名称.localizedCaseInsensitiveContains(搜索关键词) ||
                规则.匹配正则.localizedCaseInsensitiveContains(搜索关键词) ||
                规则.替换内容.localizedCaseInsensitiveContains(搜索关键词)
            }
            return 重写规则分组(id: 分组.id, 名称: 分组.名称, 图标: 分组.图标, 描述: 分组.描述, 启用: 分组.启用, 规则列表: 过滤规则)
        }.filter { !$0.规则列表.isEmpty }
    }

    var body: some View {
        LazyVStack(spacing: 12) {
            // 统计栏
            统计栏
            // 操作栏
            操作栏
            // 搜索栏
            搜索栏
            // 分组列表
            if 过滤后的分组.isEmpty {
                空状态视图
            } else {
                ForEach(过滤后的分组) { 分组 in
                    分组视图(分组: 分组)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 20)
        .sheet(isPresented: $显示添加规则) {
            重写规则编辑页面(规则: nil, 分组: 重写管理.配置.分组列表.first)
                .environmentObject(重写管理)
        }
        .sheet(isPresented: $显示添加分组) {
            添加分组页面()
                .environmentObject(重写管理)
        }
        .sheet(isPresented: $显示预设规则) {
            预设重写规则页面()
                .environmentObject(重写管理)
        }
        .sheet(item: $编辑的规则) { 规则 in
            重写规则编辑页面(规则: 规则, 分组: 编辑规则所在分组)
                .environmentObject(重写管理)
        }
    }

    // MARK: - 统计栏

    private var 统计栏: some View {
        HStack(spacing: 8) {
            重写统计项(标题: "分组", 数值: "\(统计.分组数)", 颜色: .主题色)
            重写统计项(标题: "总规则", 数值: "\(统计.总规则数)", 颜色: Color(red: 0.20, green: 0.55, blue: 0.91))
            重写统计项(标题: "已启用", 数值: "\(统计.启用规则数)", 颜色: .成功色)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    private func 重写统计项(标题: String, 数值: String, 颜色: Color) -> some View {
        VStack(spacing: 2) {
            Text(数值)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(颜色)
            Text(标题)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 操作栏

    private var 操作栏: some View {
        HStack(spacing: 8) {
            操作按钮(标题: "添加规则", 图标: "plus.circle.fill", 颜色: .主题色) {
                显示添加规则 = true
            }
            操作按钮(标题: "添加分组", 图标: "folder.badge.plus", 颜色: Color(red: 0.95, green: 0.55, blue: 0.20)) {
                显示添加分组 = true
            }
            操作按钮(标题: "预设导入", 图标: "square.and.arrow.down", 颜色: .成功色) {
                显示预设规则 = true
            }
        }
    }

    private func 操作按钮(标题: String, 图标: String, 颜色: Color, 动作: @escaping () -> Void) -> some View {
        Button(action: 动作) {
            HStack(spacing: 4) {
                Image(systemName: 图标)
                    .font(.system(size: 13))
                Text(标题)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(颜色)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(颜色.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 搜索栏

    private var 搜索栏: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            TextField("搜索规则名称、匹配表达式", text: $搜索关键词)
                .font(.system(size: 13))
                .textFieldStyle(PlainTextFieldStyle())
            if !搜索关键词.isEmpty {
                Button {
                    搜索关键词 = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(10)
    }

    // MARK: - 空状态

    private var 空状态视图: some View {
        VStack(spacing: 12) {
            Image(systemName: "pencil.line")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无重写规则")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text("点击上方按钮添加规则或导入预设")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    // MARK: - 分组视图

    private func 分组视图(分组: 重写规则分组) -> some View {
        let 已展开 = 展开的分组ID == 分组.id
        return VStack(spacing: 0) {
            // 分组标题栏
            Button {
                withAnimation {
                    展开的分组ID = 已展开 ? nil : 分组.id
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: 分组.图标)
                        .font(.system(size: 14))
                        .foregroundColor(.主题色)
                    Text(分组.名称)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text("\(分组.规则列表.count) 条")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.主题色.opacity(0.1))
                        .cornerRadius(4)
                    Spacer()
                    // 分组启用开关
                    Toggle("", isOn: Binding(
                        get: { 分组.启用 },
                        set: { 新值 in
                            重写管理.切换分组启用(分组)
                        }
                    ))
                    .labelsHidden()
                    .scaleEffect(0.8)
                    Image(systemName: 已展开 ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.卡片背景)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .contextMenu {
                Button {
                    重命名的分组 = 分组
                    重命名名称 = 分组.名称
                } label: {
                    Label("重命名", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    重写管理.删除分组(分组)
                } label: {
                    Label("删除分组", systemImage: "trash")
                }
            }

            // 分组规则列表
            if 已展开 {
                VStack(spacing: 0) {
                    ForEach(Array(分组.规则列表.enumerated()), id: \.element.id) { 索引, 规则 in
                        规则行(规则: 规则, 分组: 分组)
                        if 索引 < 分组.规则列表.count - 1 {
                            Divider()
                                .padding(.leading, 15)
                        }
                    }
                }
                .background(Color.卡片背景)
                .cornerRadius(12)
            }
        }
        .alert("重命名分组", isPresented: .constant(重命名的分组 != nil)) {
            TextField("分组名称", text: $重命名名称)
            Button("取消", role: .cancel) { 重命名的分组 = nil }
            Button("确定") {
                if let 分组 = 重命名的分组, !重命名名称.isEmpty {
                    重写管理.重命名分组(分组, 新名称: 重命名名称)
                }
                重命名的分组 = nil
            }
        }
    }

    // MARK: - 规则行

    private func 规则行(规则: 重写规则项, 分组: 重写规则分组) -> some View {
        Button {
            编辑的规则 = 规则
            编辑规则所在分组 = 分组
        } label: {
            HStack(spacing: 10) {
                // 类型标签
                Text(规则.类型.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(规则类型颜色(规则.类型))
                    .cornerRadius(4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(规则.名称)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(规则.匹配正则)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // 启用开关
                Toggle("", isOn: Binding(
                    get: { 规则.启用 },
                    set: { _ in
                        重写管理.切换规则启用(规则)
                    }
                ))
                .labelsHidden()
                .scaleEffect(0.8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button {
                编辑的规则 = 规则
                编辑规则所在分组 = 分组
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                重写管理.删除规则(规则)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func 规则类型颜色(_ 类型: 重写规则类型) -> Color {
        switch 类型 {
        case .URL重写: return Color(red: 0.20, green: 0.55, blue: 0.91)
        case .请求头: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .响应头: return Color(red: 0.56, green: 0.38, blue: 0.95)
        case .请求阻断: return .危险色
        }
    }
}

// MARK: - 添加分组页面

private struct 添加分组页面: View {
    @EnvironmentObject private var 重写管理: 重写规则管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 分组名称 = ""
    @State private var 分组描述 = ""

    var body: some View {
        NavigationView {
            Form {
                Section("分组信息") {
                    TextField("分组名称", text: $分组名称)
                    TextField("分组描述（可选）", text: $分组描述)
                }
            }
            .navigationTitle("添加分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 关闭() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !分组名称.isEmpty else { return }
                        let 新分组 = 重写规则分组(名称: 分组名称, 描述: 分组描述)
                        重写管理.添加分组(新分组)
                        关闭()
                    }
                    .disabled(分组名称.isEmpty)
                }
            }
        }
    }
}

// MARK: - 分流规则内容区

/// 分流规则内容区视图
struct 分流规则内容区: View {
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @State private var 搜索关键词 = ""
    @State private var 展开的分组ID: UUID?
    @State private var 显示添加规则 = false
    @State private var 显示预设规则 = false
    @State private var 显示规则测试 = false
    @State private var 显示添加分组 = false
    @State private var 重命名的分组: 分流规则分组?
    @State private var 重命名名称 = ""
    @State private var 预设导入目标分组: 分流规则分组?
    @State private var 显示预设到分组 = false

    /// 统计数据
    private var 统计: (分组数: Int, 总规则数: Int, 启用规则数: Int, 总命中数: Int) {
        let 所有规则 = 分流管理.配置.分组列表.flatMap { $0.规则列表 }
        let 启用规则 = 所有规则.filter { $0.启用 }
        let 总命中 = 所有规则.reduce(0) { $0 + $1.命中次数 }
        return (分流管理.配置.分组列表.count, 所有规则.count, 启用规则.count, 总命中)
    }

    var body: some View {
        VStack(spacing: 12) {
            // 顶部统计栏
            HStack(spacing: 0) {
                统计项(数值: 统计.分组数, 标签: "分组", 颜色: .主题色)
                分割线()
                统计项(数值: 统计.总规则数, 标签: "总规则", 颜色: .成功色)
                分割线()
                统计项(数值: 统计.启用规则数, 标签: "已启用", 颜色: .警告色)
                分割线()
                统计项(数值: 统计.总命中数, 标签: "总命中", 颜色: .危险色)
            }
            .padding(.vertical, 14)
            .background(Color.卡片背景)
            .cornerRadius(12)

            // 操作栏：搜索 + 测试 + 预设 + 添加
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    TextField("搜索规则", text: $搜索关键词)
                        .font(.system(size: 14))
                    if !搜索关键词.isEmpty {
                        Button {
                            搜索关键词 = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.卡片背景)
                .cornerRadius(8)

                Button {
                    显示规则测试 = true
                } label: {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(.主题色)
                        .frame(width: 36, height: 36)
                        .background(Color.卡片背景)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    显示预设规则 = true
                } label: {
                    Image(systemName: "square.stack.3d.down.forward")
                        .font(.system(size: 18))
                        .foregroundColor(.主题色)
                        .frame(width: 36, height: 36)
                        .background(Color.卡片背景)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    显示添加分组 = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.主题色)
                        .frame(width: 36, height: 36)
                        .background(Color.卡片背景)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    显示添加规则 = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.主题色)
                        .frame(width: 36, height: 36)
                        .background(Color.卡片背景)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // 分组列表
            if 分流管理.配置.分组列表.isEmpty {
                空状态视图()
            } else {
                VStack(spacing: 10) {
                    ForEach($分流管理.配置.分组列表) { $分组 in
                        分组卡片(
                            分组: $分组,
                            已展开: 展开的分组ID == 分组.id,
                            搜索关键词: 搜索关键词,
                            切换展开: {
                                if 展开的分组ID == 分组.id {
                                    展开的分组ID = nil
                                } else {
                                    展开的分组ID = 分组.id
                                }
                            },
                            重命名分组: {
                                重命名的分组 = 分组
                                重命名名称 = 分组.名称
                            },
                            删除分组: {
                                分流管理.删除分组(分组)
                            },
                            导入预设到分组: {
                                预设导入目标分组 = 分组
                                显示预设到分组 = true
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .sheet(isPresented: $显示添加规则) {
            规则编辑页面(规则: nil)
                .environmentObject(分流管理)
        }
        .sheet(isPresented: $显示预设规则) {
            NavigationStack {
                预设规则页面()
                    .environmentObject(分流管理)
                    .navigationTitle("预设规则集")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $显示规则测试) {
            NavigationStack {
                规则测试页面()
                    .environmentObject(分流管理)
                    .navigationTitle("规则测试")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $显示添加分组) {
            分组名称输入页面(标题: "添加分组", 初始名称: "") { 名称 in
                let 新分组 = 分流规则分组(名称: 名称, 图标: "folder", 规则列表: [])
                分流管理.添加分组(新分组)
            }
            .environmentObject(分流管理)
        }
        .alert("重命名分组", isPresented: Binding(
            get: { 重命名的分组 != nil },
            set: { if !$0 { 重命名的分组 = nil } }
        )) {
            TextField("分组名称", text: $重命名名称)
            Button("取消", role: .cancel) {}
            Button("确定") {
                if let 分组 = 重命名的分组, !重命名名称.isEmpty {
                    分流管理.重命名分组(分组, 新名称: 重命名名称)
                }
                重命名的分组 = nil
            }
        } message: {
            Text("请输入新的分组名称")
        }
        .sheet(isPresented: $显示预设到分组) {
            if let 目标分组 = 预设导入目标分组 {
                预设规则选择页面(目标分组: 目标分组)
                    .environmentObject(分流管理)
            }
        }
        .onAppear {
            // 页面出现时立即同步一次连接记录
            分流管理.同步连接记录并更新命中()
            // 启动定时器，每5秒同步一次连接记录（用于规则命中统计）
            命中同步定时器 = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                分流管理.同步连接记录并更新命中()
            }
        }
        .onDisappear {
            命中同步定时器?.invalidate()
            命中同步定时器 = nil
        }
    }

    /// 命中统计同步定时器
    @State private var 命中同步定时器: Timer?

    /// 统计项
    private func 统计项(数值: Int, 标签: String, 颜色: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(数值)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(颜色)
            Text(标签)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 分割线
    private func 分割线() -> some View {
        Rectangle()
            .fill(Color.分割线)
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    /// 空状态视图
    private func 空状态视图() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无分流规则")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text("点击右上角 + 添加规则，或导入预设规则集")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 分组卡片

/// 分流规则分组卡片
private struct 分组卡片: View {
    @Binding var 分组: 分流规则分组
    let 已展开: Bool
    let 搜索关键词: String
    let 切换展开: () -> Void
    let 重命名分组: () -> Void
    let 删除分组: () -> Void
    let 导入预设到分组: () -> Void
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @State private var 当前显示数量 = 30
    private let 每页规则数 = 30

    /// 过滤后的规则列表
    private var 过滤后的规则: [分流规则项] {
        if 搜索关键词.isEmpty {
            return 分组.规则列表
        }
        let 关键词 = 搜索关键词.lowercased()
        return 分组.规则列表.filter { 规则 in
            规则.名称.lowercased().contains(关键词) ||
            规则.匹配值.lowercased().contains(关键词)
        }
    }

    /// 当前显示的规则
    private var 显示的规则: [分流规则项] {
        Array(过滤后的规则.prefix(当前显示数量))
    }

    /// 是否还有更多规则
    private var 有更多: Bool {
        过滤后的规则.count > 当前显示数量
    }

    var body: some View {
        VStack(spacing: 0) {
            // 分组标题行（点击展开/折叠）
            Button(action: 切换展开) {
                HStack(spacing: 10) {
                    Image(systemName: 分组.图标)
                        .font(.system(size: 16))
                        .foregroundColor(.主题色)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(分组.名称)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Text("\(分组.启用规则数)/\(分组.规则列表.count) 条规则")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: 已展开 ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.卡片背景)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            // 启用开关（独立于展开点击）
            .overlay(alignment: .trailing) {
                Toggle("", isOn: Binding(
                    get: { 分组.启用 },
                    set: { _ in 分流管理.切换分组启用(分组) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .主题色))
                .frame(width: 45)
                .padding(.trailing, 40)
            }
            // 长按菜单：重命名、导入预设、删除
            .contextMenu {
                Button {
                    重命名分组()
                } label: {
                    Label("重命名分组", systemImage: "pencil")
                }
                Button {
                    导入预设到分组()
                } label: {
                    Label("导入预设规则集", systemImage: "square.stack.3d.down.forward")
                }
                Button(role: .destructive) {
                    删除分组()
                } label: {
                    Label("删除分组", systemImage: "trash")
                }
            }

            // 展开的规则列表（无动画，避免重影）
            if 已展开 {
                VStack(spacing: 8) {
                    if 过滤后的规则.isEmpty {
                        Text(搜索关键词.isEmpty ? "该分组暂无规则" : "未找到匹配的规则")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(显示的规则) { 规则 in
                            规则简要行(规则: 规则)
                        }
                        if 有更多 {
                            Button {
                                当前显示数量 += 每页规则数
                            } label: {
                                Text("加载更多（还有 \(过滤后的规则.count - 当前显示数量) 条）")
                                    .font(.system(size: 13))
                                    .foregroundColor(.主题色)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.卡片背景.opacity(0.5))
                .cornerRadius(12)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - 规则简要行

/// 规则简要行（内容区使用，轻量级）
private struct 规则简要行: View {
    let 规则: 分流规则项

    var body: some View {
        HStack(spacing: 10) {
            // 启用状态圆点
            Circle()
                .fill(规则.启用 ? Color.成功色 : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(规则.名称)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(规则.类型.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(类型颜色)
                        .cornerRadius(3)
                    Text(规则.匹配值)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            // 动作标签
            Text(规则.动作.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(动作颜色)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(动作颜色.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.页面背景)
        .cornerRadius(8)
    }

    /// 类型颜色
    private var 类型颜色: Color {
        switch 规则.类型 {
        case .域名精确: return Color(red: 0.20, green: 0.55, blue: 0.91)
        case .域名后缀: return Color(red: 0.91, green: 0.36, blue: 0.20)
        case .域名关键词: return Color(red: 0.56, green: 0.38, blue: 0.95)
        case .正则表达式: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .IP地址: return Color(red: 0.20, green: 0.70, blue: 0.50)
        case .IP段: return Color(red: 0.30, green: 0.60, blue: 0.70)
        case .端口: return Color(red: 0.70, green: 0.50, blue: 0.20)
        case .端口范围: return Color(red: 0.60, green: 0.40, blue: 0.30)
        case .协议: return Color(red: 0.40, green: 0.50, blue: 0.60)
        case .进程名称: return Color(red: 0.50, green: 0.40, blue: 0.50)
        case .用户代理: return Color(red: 0.45, green: 0.55, blue: 0.45)
        case .地理区域: return Color(red: 0.30, green: 0.40, blue: 0.50)
        case .全部: return Color(red: 0.50, green: 0.50, blue: 0.50)
        }
    }

    /// 动作颜色
    private var 动作颜色: Color {
        switch 规则.动作 {
        case .代理, .全局代理: return .主题色
        case .直连: return .成功色
        case .拦截, .拒绝: return .危险色
        case .放行: return .警告色
        }
    }
}

// MARK: - 日志内容区

/// 日志内容区视图
struct 日志内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(状态.日志列表) { 日志 in
                日志行(日志: 日志)
                if 日志.id != 状态.日志列表.last?.id {
                    Divider()
                        .padding(.leading, 15)
                }
            }
        }
        .background(Color.卡片背景)
        .cornerRadius(12)
        .padding(.horizontal, 15)
    }
}

/// 单个日志行
private struct 日志行: View {
    let 日志: 日志模型

    /// 时间格式化器
    private let 时间格式: DateFormatter = {
        let 格式 = DateFormatter()
        格式.dateFormat = "HH:mm:ss"
        return 格式
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 级别圆点
            Circle()
                .fill(级别颜色(日志.级别))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(日志.模块)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(时间格式.string(from: 日志.时间))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Text(日志.内容)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }

    private func 级别颜色(_ 级别: 日志级别) -> Color {
        switch 级别 {
        case .致命: return Color(red: 0.56, green: 0.38, blue: 0.95)
        case .错误: return .危险色
        case .警告: return .警告色
        case .信息: return .主题色
        case .调试: return .secondary
        case .追踪: return .secondary
        }
    }
}

// MARK: - 分组名称输入页面

/// 分组名称输入页面（用于添加分组）
private struct 分组名称输入页面: View {
    @Environment(\.dismiss) private var 关闭
    @State private var 分组名称 = ""
    let 标题: String
    let 初始名称: String
    let 完成: (String) -> Void

    init(标题: String, 初始名称: String, 完成: @escaping (String) -> Void) {
        self.标题 = 标题
        self.初始名称 = 初始名称
        self.完成 = 完成
        _分组名称 = State(initialValue: 初始名称)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("分组信息") {
                    TextField("请输入分组名称", text: $分组名称)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle(标题)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 关闭() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if !分组名称.isEmpty {
                            完成(分组名称)
                            关闭()
                        }
                    }
                    .disabled(分组名称.isEmpty)
                }
            }
        }
    }
}

// MARK: - 预设规则选择页面（导入到指定分组）

/// 预设规则选择页面（用于分组长按菜单导入预设到指定分组）
private struct 预设规则选择页面: View {
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @Environment(\.dismiss) private var 关闭
    let 目标分组: 分流规则分组

    var body: some View {
        NavigationStack {
            List {
                ForEach(预设规则集.所有预设) { 预设 in
                    Button {
                        分流管理.导入预设规则(预设, 追加到分组: 目标分组)
                        关闭()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.主题色.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: 预设.图标)
                                    .font(.system(size: 18))
                                    .foregroundColor(.主题色)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(预设.名称)
                                    .font(.system(size: 15, weight: .medium))
                                Text("\(预设.规则列表.count) 条规则")
                                    .font(.system(size: 11))
                                    .foregroundColor(.主题色)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.主题色)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("导入到「\(目标分组.名称)」")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 关闭() }
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        重写规则内容区()
            .environmentObject(AppState.共享)
    }
    .background(Color.页面背景)
}
