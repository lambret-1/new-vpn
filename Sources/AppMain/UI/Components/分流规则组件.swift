//
//  分流规则组件.swift
//  NewVPN
//
//  分流规则相关 UI 组件
//  规则列表、规则编辑、规则测试、预设规则
//

import SwiftUI

// MARK: - 分流规则主页面

/// 分流规则主页面（底部弹窗使用）
struct 分流规则页面: View {
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @State private var 显示添加规则 = false
    @State private var 显示预设规则 = false
    @State private var 显示规则测试 = false
    @State private var 搜索关键词 = ""

    var body: some View {
        VStack(spacing: 0) {
            // 顶部统计栏
            分流统计栏()
                .padding(.horizontal, 15)
                .padding(.top, 10)

            // 操作栏
            HStack(spacing: 8) {
                AppSearchBar(搜索文字: $搜索关键词, 占位文字: "搜索规则")
                    .frame(maxWidth: .infinity)

                Button {
                    显示规则测试 = true
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.主题色)
                }

                Button {
                    显示预设规则 = true
                } label: {
                    Image(systemName: "square.stack.3d.down.forward")
                        .font(.system(size: 20))
                        .foregroundColor(.主题色)
                }

                Button {
                    显示添加规则 = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.主题色)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)

            // 分组和规则列表
            if 分流管理.配置.分组列表.isEmpty {
                EmptyStateView(
                    图标: "list.bullet",
                    标题: "暂无分流规则",
                    说明: "点击右上角添加规则，或导入预设规则集",
                    按钮文字: "导入预设"
                ) {
                    显示预设规则 = true
                }
            } else {
                List {
                    ForEach($分流管理.配置.分组列表) { $分组 in
                        分分组视图(分组: $分组)
                            .listRowInsets(EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 15))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.页面背景)
        .sheet(isPresented: $显示添加规则) {
            规则编辑页面(规则: nil)
                .environmentObject(分流管理)
        }
        .sheet(isPresented: $显示预设规则) {
            预设规则页面()
                .environmentObject(分流管理)
        }
        .sheet(isPresented: $显示规则测试) {
            规则测试页面()
                .environmentObject(分流管理)
        }
    }
}

// MARK: - 分流统计栏

/// 分流统计栏
private struct 分流统计栏: View {
    @EnvironmentObject private var 分流管理: 分流规则管理器

    var body: some View {
        let 统计 = 分流管理.统计

        HStack(spacing: 8) {
            统计项(数值: 统计.分组数, 标签: "分组", 颜色: .主题色)
            统计项(数值: 统计.总规则数, 标签: "总规则", 颜色: .成功色)
            统计项(数值: 统计.启用规则数, 标签: "已启用", 颜色: .警告色)
            统计项(数值: 统计.总命中数, 标签: "总命中", 颜色: .危险色)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    private struct 统计项: View {
        let 数值: Int
        let 标签: String
        let 颜色: Color

        var body: some View {
            VStack(spacing: 4) {
                Text("\(数值)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(颜色)
                Text(标签)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 分组视图

/// 分流规则分组视图
private struct 分分组视图: View {
    @Binding var 分组: 分流规则分组
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @State private var 显示添加规则 = false
    @State private var 编辑的规则: 分流规则项?

    var body: some View {
        VStack(spacing: 0) {
            // 分组标题行
            HStack(spacing: 10) {
                // 展开箭头
                Button {
                    分流管理.切换分组展开(分组)
                } label: {
                    Image(systemName: 分组.是否展开 ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(PlainButtonStyle())

                // 分组图标
                Image(systemName: 分组.图标)
                    .font(.system(size: 16))
                    .foregroundColor(.主题色)

                // 分组名称
                Text(分组.名称)
                    .font(.system(size: 15, weight: .medium))

                Spacer()

                // 规则数量
                Text("\(分组.启用规则数)/\(分组.规则列表.count)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                // 启用开关
                Toggle("", isOn: Binding(
                    get: { 分组.启用 },
                    set: { _ in 分流管理.切换分组启用(分组) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .主题色))
                .frame(width: 45)

                // 添加规则按钮
                Button {
                    显示添加规则 = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.主题色)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.卡片背景)
            .cornerRadius(10)

            // 展开的规则列表
            if 分组.是否展开 {
                VStack(spacing: 6) {
                    if 分组.规则列表.isEmpty {
                        Text("该分组暂无规则")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.卡片背景.opacity(0.5))
                            .cornerRadius(8)
                    } else {
                        ForEach($分组.规则列表) { $规则 in
                            规则行视图(规则: $规则)
                                .onTapGesture {
                                    编辑的规则 = 规则
                                }
                        }
                        .onDelete { 索引集 in
                            索引集.forEach { 索引 in
                                分流管理.删除规则(分组.规则列表[索引])
                            }
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 20)
            }
        }
        .sheet(isPresented: $显示添加规则) {
            规则编辑页面(规则: nil, 分组: 分组)
                .environmentObject(分流管理)
        }
        .sheet(item: $编辑的规则) { 规则 in
            规则编辑页面(规则: 规则, 分组: 分组)
                .environmentObject(分流管理)
        }
    }
}

// MARK: - 规则行视图

/// 单条分流规则行
struct 规则行视图: View {
    @Binding var 规则: 分流规则项
    @EnvironmentObject private var 分流管理: 分流规则管理器

    var body: some View {
        HStack(spacing: 10) {
            // 规则类型图标
            ZStack {
                Circle()
                    .fill(动作颜色(规则.动作).opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: 规则.类型.图标)
                    .font(.system(size: 14))
                    .foregroundColor(动作颜色(规则.动作))
            }

            // 规则信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(规则.名称)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text(规则.动作.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(动作颜色(规则.动作))
                        .cornerRadius(3)
                }
                Text(规则.描述)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 命中次数
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(规则.命中次数)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.主题色)
                Text("命中")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)

            // 启用开关
            Toggle("", isOn: Binding(
                get: { 规则.启用 },
                set: { _ in 分流管理.切换规则启用(规则) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .主题色))
            .frame(width: 45)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.卡片背景)
        .cornerRadius(8)
        .opacity(规则.启用 ? 1.0 : 0.5)
    }

    /// 动作颜色
    private func 动作颜色(_ 动作: 分流动作) -> Color {
        switch 动作 {
        case .直连: return .成功色
        case .代理: return .主题色
        case .拦截, .拒绝: return .危险色
        case .全局代理: return .警告色
        case .放行: return .次要文字
        }
    }
}

// MARK: - 规则编辑页面

/// 规则编辑/添加页面
struct 规则编辑页面: View {
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @Environment(\.dismiss) private var 关闭

    /// 编辑的规则（nil表示新增）
    let 规则: 分流规则项?
    /// 目标分组
    let 分组: 分流规则分组?

    @State private var 名称 = ""
    @State private var 类型: 分流规则类型 = .域名后缀
    @State private var 匹配值 = ""
    @State private var 动作: 分流动作 = .代理
    @State private var 启用 = true
    @State private var 优先级 = 100
    @State private var 备注 = ""

    init(规则: 分流规则项?, 分组: 分流规则分组? = nil) {
        self.规则 = 规则
        self.分组 = 分组
        if let 规则 = 规则 {
            _名称 = State(initialValue: 规则.名称)
            _类型 = State(initialValue: 规则.类型)
            _匹配值 = State(initialValue: 规则.匹配值)
            _动作 = State(initialValue: 规则.动作)
            _启用 = State(initialValue: 规则.启用)
            _优先级 = State(initialValue: 规则.优先级)
            _备注 = State(initialValue: 规则.备注 ?? "")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    AppFormRow(标签: "名称") {
                        TextField("规则名称", text: $名称)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("规则类型", selection: $类型) {
                        ForEach(分流规则类型.allCases, id: \.self) { 类型 in
                            Label(类型.rawValue, systemImage: 类型.图标).tag(类型)
                        }
                    }

                    AppFormRow(标签: "匹配值") {
                        TextField(匹配值占位, text: $匹配值)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .keyboardType(类型 == .IP地址 || 类型 == .IP段 || 类型 == .端口 ? .numbersAndPunctuation : .URL)
                    }

                    Picker("分流动作", selection: $动作) {
                        ForEach(分流动作.allCases, id: \.self) { 动作 in
                            Label(动作.rawValue, systemImage: 动作.图标).tag(动作)
                        }
                    }
                }

                Section("高级设置") {
                    Toggle("启用规则", isOn: $启用)
                        .tint(.主题色)

                    AppFormRow(标签: "优先级") {
                        TextField("100", value: $优先级, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }

                    AppFormRow(标签: "备注") {
                        TextField("可选", text: $备注)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if 规则 != nil {
                    Section {
                        Button(role: .destructive) {
                            删除规则()
                        } label: {
                            HStack {
                                Text("删除规则")
                                    .foregroundColor(.危险色)
                                Spacer()
                                Image(systemName: "trash")
                                    .foregroundColor(.危险色)
                            }
                        }
                    }
                }
            }
            .navigationTitle(规则 == nil ? "添加规则" : "编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 关闭() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        保存规则()
                    }
                    .disabled(名称.isEmpty || 匹配值.isEmpty)
                }
            }
        }
    }

    /// 匹配值占位文字
    private var 匹配值占位: String {
        switch 类型 {
        case .域名精确: return "example.com"
        case .域名后缀: return "example.com"
        case .域名关键词: return "google"
        case .正则表达式: return "^.*\\.example\\.com$"
        case .IP地址: return "1.1.1.1"
        case .IP段: return "10.0.0.0/8"
        case .端口: return "443"
        case .端口范围: return "1000-2000"
        case .协议: return "TCP"
        case .进程名称: return "Safari"
        case .用户代理: return "Mozilla"
        case .地理区域: return "CN"
        case .全部: return "*"
        }
    }

    /// 保存规则
    private func 保存规则() {
        let 新规则 = 分流规则项(
            id: 规则?.id ?? UUID(),
            名称: 名称,
            类型: 类型,
            匹配值: 匹配值,
            动作: 动作,
            启用: 启用,
            优先级: 优先级,
            备注: 备注.isEmpty ? nil : 备注,
            命中次数: 规则?.命中次数 ?? 0,
            最后命中时间: 规则?.最后命中时间,
            创建时间: 规则?.创建时间 ?? Date()
        )

        if 规则 != nil {
            分流管理.更新规则(新规则)
        } else if let 分组 = 分组 {
            分流管理.添加规则(新规则, 到分组: 分组)
        } else if let 第一个分组 = 分流管理.配置.分组列表.first {
            分流管理.添加规则(新规则, 到分组: 第一个分组)
        }

        关闭()
    }

    /// 删除规则
    private func 删除规则() {
        if let 规则 = 规则 {
            分流管理.删除规则(规则)
        }
        关闭()
    }
}

// MARK: - 预设规则页面

/// 预设规则集页面
struct 预设规则页面: View {
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 选中的预设: 预设规则集?
    @State private var 显示确认导入 = false

    var body: some View {
        NavigationView {
            List {
                ForEach(预设规则集.所有预设) { 预设 in
                    Button {
                        选中的预设 = 预设
                        显示确认导入 = true
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
                                Text(预设.描述)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                Text("\(预设.规则列表.count) 条规则")
                                    .font(.system(size: 11))
                                    .foregroundColor(.主题色)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("预设规则集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { 关闭() }
                }
            }
            .alert("导入预设规则", isPresented: $显示确认导入) {
                Button("创建新分组") {
                    if let 预设 = 选中的预设 {
                        分流管理.应用预设规则集(预设)
                        关闭()
                    }
                }
                Button("追加到默认分组") {
                    if let 预设 = 选中的预设,
                       let 第一个分组 = 分流管理.配置.分组列表.first {
                        分流管理.导入预设规则(预设, 追加到分组: 第一个分组)
                        关闭()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let 预设 = 选中的预设 {
                    Text("将导入「\(预设.名称)」的 \(预设.规则列表.count) 条规则")
                }
            }
        }
    }
}

// MARK: - 规则测试页面

/// 规则匹配测试页面
struct 规则测试页面: View {
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @Environment(\.dismiss) private var 关闭

    @State private var 测试值 = ""
    @State private var 测试结果: 分流测试结果?
    @State private var 正在测试 = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 测试输入区
                VStack(spacing: 12) {
                    Text("输入域名或 IP 地址，测试匹配哪条分流规则")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        TextField("example.com 或 1.1.1.1", text: $测试值)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.URL)

                        Button {
                            执行测试()
                        } label: {
                            if 正在测试 {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("测试")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.主题色)
                        .disabled(测试值.isEmpty || 正在测试)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(Color.卡片背景)

                // 测试结果
                if let 结果 = 测试结果 {
                    List {
                        Section("测试结果") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("测试值:")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    Text(结果.测试值)
                                        .font(.system(size: 13, weight: .medium))
                                }

                                HStack {
                                    Text("最终动作:")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    Text(结果.最终动作.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(动作颜色(结果.最终动作))
                                }

                                Text(结果.结果描述)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        Section("匹配过程") {
                            ForEach(Array(结果.匹配过程.enumerated()), id: \.offset) { 索引, 过程 in
                                HStack {
                                    Image(systemName: 过程.匹配 ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundColor(过程.匹配 ? .成功色 : .secondary)
                                    Text(过程.规则名称)
                                        .font(.system(size: 13))
                                        .foregroundColor(过程.匹配 ? .primary : .secondary)
                                    Spacer()
                                    if 过程.匹配 && 索引 == 结果.匹配过程.firstIndex(where: { $0.匹配 }) {
                                        Text("命中")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.成功色)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    Spacer()
                    EmptyStateView(
                        图标: "magnifyingglass",
                        标题: "等待测试",
                        说明: "输入域名或 IP 地址后点击测试按钮"
                    )
                    Spacer()
                }
            }
            .background(Color.页面背景)
            .navigationTitle("规则测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { 关闭() }
                }
            }
        }
    }

    /// 执行测试
    private func 执行测试() {
        正在测试 = true

        DispatchQueue.global(qos: .userInitiated).async {
            let 结果 = 分流管理.测试规则(测试值: 测试值)

            DispatchQueue.main.async {
                测试结果 = 结果
                正在测试 = false
            }
        }
    }

    /// 动作颜色
    private func 动作颜色(_ 动作: 分流动作) -> Color {
        switch 动作 {
        case .直连: return .成功色
        case .代理: return .主题色
        case .拦截, .拒绝: return .危险色
        case .全局代理: return .警告色
        case .放行: return .次要文字
        }
    }
}

// MARK: - 预览

#Preview("分流规则页面") {
    分流规则页面()
        .environmentObject(分流规则管理器.共享)
        .background(Color.页面背景)
}
