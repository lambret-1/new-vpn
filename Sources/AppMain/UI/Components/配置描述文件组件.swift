//
//  配置描述文件组件.swift
//  NewVPN
//
//  配置描述文件相关 UI 组件
//  配置列表、编辑、导入、详情、版本历史
//

import SwiftUI

// MARK: - 配置描述文件列表页面

/// 配置描述文件列表页面
struct 配置描述文件列表页面: View {
    @EnvironmentObject private var 配置管理: 配置描述文件管理器
    @State private var 显示导入弹窗 = false
    @State private var 显示新建弹窗 = false
    @State private var 选中配置: 配置描述文件?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                AppSearchBar(搜索文字: $配置管理.搜索关键词, 占位文字: "搜索配置")
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)

                // 统计栏
                统计栏
                    .padding(.horizontal, 15)
                    .padding(.bottom, 8)

                if 配置管理.是否加载中 {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else if 配置管理.筛选后的配置列表.isEmpty {
                    EmptyStateView(
                        图标: "doc.text",
                        标题: "暂无配置文件",
                        说明: "点击右上角导入或新建配置"
                    )
                } else {
                    List {
                        ForEach(配置管理.筛选后的配置列表) { 配置 in
                            配置行(配置: 配置, 选中: $选中配置)
                                .listRowInsets(EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 15))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.页面背景)
            .navigationTitle("配置文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            显示新建弹窗 = true
                        } label: {
                            Label("新建配置", systemImage: "plus")
                        }
                        Button {
                            显示导入弹窗 = true
                        } label: {
                            Label("导入配置", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.主题色)
                    }
                }
            }
            .sheet(isPresented: $显示导入弹窗) {
                配置导入页面()
                    .environmentObject(配置管理)
            }
            .sheet(isPresented: $显示新建弹窗) {
                新建配置页面()
                    .environmentObject(配置管理)
            }
            .sheet(item: $选中配置) { 配置 in
                配置详情页面(配置: 配置)
                    .environmentObject(配置管理)
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 统计栏
    private var 统计栏: some View {
        HStack(spacing: 12) {
            统计项(标题: "配置总数", 值: "\(配置管理.配置总数)")
            统计项(标题: "订阅配置", 值: "\(配置管理.订阅配置数)")
            统计项(标题: "总节点数", 值: "\(配置管理.总节点数)")
        }
    }

    /// 统计项
    private func 统计项(标题: String, 值: String) -> some View {
        VStack(spacing: 2) {
            Text(值)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.主题色)
                .monospacedDigit()
            Text(标题)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.卡片背景)
        .cornerRadius(10)
    }
}

// MARK: - 配置行

/// 配置行
private struct 配置行: View {
    let 配置: 配置描述文件
    @Binding var 选中: 配置描述文件?
    @EnvironmentObject private var 配置管理: 配置描述文件管理器
    @State private var 显示操作菜单 = false

    var body: some View {
        HStack(spacing: 12) {
            // 配置图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(配置.是否激活 ? Color.主题色.opacity(0.15) : Color.次要背景)
                    .frame(width: 44, height: 44)
                Image(systemName: 配置图标)
                    .font(.system(size: 20))
                    .foregroundColor(配置.是否激活 ? .主题色 : .secondary)
            }

            // 配置信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(配置.名称)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    if 配置.是否激活 {
                        Text("使用中")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.主题色)
                            .cornerRadius(4)
                    }
                    if 配置.是否默认 {
                        Text("默认")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.次要背景)
                            .cornerRadius(4)
                    }
                }

                Text(配置.描述 ?? 配置.类型.显示名称)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(配置.统计.节点数量) 节点", systemImage: "server.rack")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Label(配置.文件大小显示, systemImage: "doc")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Label(配置.最后修改时间显示, systemImage: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 操作按钮
            Button {
                显示操作菜单 = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .confirmationDialog("配置操作", isPresented: $显示操作菜单) {
                if !配置.是否激活 {
                    Button("激活此配置") {
                        配置管理.激活配置(配置)
                    }
                }
                Button("查看详情") {
                    选中 = 配置
                }
                Button("复制配置") {
                    _ = 配置管理.复制配置(配置, 新名称: "\(配置.名称) 副本")
                }
                Button("导出配置") {
                    // 导出操作
                }
                if !配置.是否默认 {
                    Button("删除配置", role: .destructive) {
                        配置管理.删除配置(配置)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(配置.是否激活 ? Color.主题色.opacity(0.08) : Color.卡片背景)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(配置.是否激活 ? Color.主题色.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            选中 = 配置
        }
    }

    /// 配置图标
    private var 配置图标: String {
        switch 配置.类型 {
        case .singbox: return "cube.box"
        case .clash: return "flag"
        case .v2ray: return "paperplane"
        case .manual: return "pencil"
        }
    }
}

// MARK: - 配置详情页面

/// 配置详情页面
struct 配置详情页面: View {
    let 配置: 配置描述文件
    @EnvironmentObject private var 配置管理: 配置描述文件管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 显示编辑页面 = false
    @State private var 显示版本历史 = false

    var body: some View {
        NavigationView {
            List {
                Section("基本信息") {
                    AppFormRow(标签: "名称") {
                        Text(配置.名称)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "类型") {
                        Text(配置.类型.显示名称)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "状态") {
                        Text(配置.状态.rawValue)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "版本") {
                        Text(配置.版本)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    if let 描述 = 配置.描述 {
                        AppFormRow(标签: "描述") {
                            Text(描述)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("时间信息") {
                    AppFormRow(标签: "创建时间") {
                        Text(配置.创建时间显示)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "最后修改") {
                        Text(配置.最后修改时间显示)
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "使用情况") {
                        Text(配置.使用频率描述)
                            .foregroundColor(.secondary)
                    }
                }

                Section("配置统计") {
                    AppFormRow(标签: "节点数量") {
                        Text("\(配置.统计.节点数量)")
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "出站数量") {
                        Text("\(配置.统计.出站数量)")
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "入站数量") {
                        Text("\(配置.统计.入站数量)")
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "路由规则") {
                        Text("\(配置.统计.路由规则数量)")
                            .foregroundColor(.secondary)
                    }
                    AppFormRow(标签: "文件大小") {
                        Text(配置.文件大小显示)
                            .foregroundColor(.secondary)
                    }
                }

                Section("关联信息") {
                    if let 订阅名称 = 配置.关联订阅名称 {
                        AppFormRow(标签: "关联订阅") {
                            Text(订阅名称)
                                .foregroundColor(.secondary)
                        }
                    }
                    AppFormRow(标签: "自动更新") {
                        Toggle("", isOn: Binding(
                            get: { 配置.自动更新 },
                            set: { 配置管理.切换自动更新(配置, 启用: $0) }
                        ))
                        .labelsHidden()
                    }
                    if 配置.自动更新 {
                        AppFormRow(标签: "更新间隔") {
                            Text("\(配置.更新间隔分钟) 分钟")
                                .foregroundColor(.secondary)
                        }
                        if let 上次更新 = 配置.上次更新时间 {
                            AppFormRow(标签: "上次更新") {
                                Text(格式化时间(上次更新))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("操作") {
                    Button {
                        显示版本历史 = true
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.主题色)
                            Text("版本历史")
                            Spacer()
                            Text("\(配置管理.加载版本列表(配置).count) 个版本")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !配置.是否激活 {
                        Button {
                            配置管理.激活配置(配置)
                            关闭()
                        } label: {
                            HStack {
                                Spacer()
                                Text("激活此配置")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.主题色)
                                Spacer()
                            }
                        }
                    }

                    Button {
                        显示编辑页面 = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("编辑配置内容")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.主题色)
                            Spacer()
                        }
                    }

                    if !配置.是否默认 {
                        Button(role: .destructive) {
                            配置管理.删除配置(配置)
                            关闭()
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除配置")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.危险色)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("配置详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        关闭()
                    }
                }
            }
            .sheet(isPresented: $显示编辑页面) {
                配置编辑页面(配置: 配置)
                    .environmentObject(配置管理)
            }
            .sheet(isPresented: $显示版本历史) {
                版本历史页面(配置: 配置)
                    .environmentObject(配置管理)
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 格式化时间
    private func 格式化时间(_ 日期: Date) -> String {
        let 格式化 = DateFormatter()
        格式化.dateFormat = "yyyy-MM-dd HH:mm"
        return 格式化.string(from: 日期)
    }
}

// MARK: - 配置编辑页面

/// 配置编辑页面
struct 配置编辑页面: View {
    let 配置: 配置描述文件
    @EnvironmentObject private var 配置管理: 配置描述文件管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 配置内容: String = ""
    @State private var 验证结果: (有效: Bool, 错误: String?, 警告: [String])?
    @State private var 显示保存成功 = false
    @State private var 键盘高度: CGFloat = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 验证结果栏
                if let 结果 = 验证结果 {
                    if !结果.有效, let 错误 = 结果.错误 {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.危险色)
                            Text(错误)
                                .font(.system(size: 12))
                                .foregroundColor(.危险色)
                            Spacer()
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Color.危险色.opacity(0.1))
                    } else if !结果.警告.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.警告色)
                            Text("\(结果.警告.count) 个警告")
                                .font(.system(size: 12))
                                .foregroundColor(.警告色)
                            Spacer()
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Color.警告色.opacity(0.1))
                    }
                }

                // 编辑器
                TextEditor(text: $配置内容)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.页面背景)
                    .onChange(of: 配置内容) { _ in
                        验证结果 = nil
                    }
            }
            .background(Color.页面背景)
            .navigationTitle(配置.名称)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        关闭()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button("验证") {
                            验证配置()
                        }
                        .foregroundColor(.主题色)

                        Button("保存") {
                            保存配置()
                        }
                        .foregroundColor(.主题色)
                        .bold()
                    }
                }
            }
            .alert("保存成功", isPresented: $显示保存成功) {
                Button("确定") {
                    关闭()
                }
            } message: {
                Text("配置已保存，版本号已更新")
            }
            .onAppear {
                配置内容 = 配置管理.加载配置内容(配置) ?? ""
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 验证配置
    private func 验证配置() {
        验证结果 = 配置管理.验证配置内容(配置内容, 类型: 配置.类型)
    }

    /// 保存配置
    private func 保存配置() {
        // 先验证
        let 结果 = 配置管理.验证配置内容(配置内容, 类型: 配置.类型)
        验证结果 = 结果

        guard 结果.有效 else { return }

        if 配置管理.保存配置内容(配置, 内容: 配置内容, 修改说明: "手动编辑") {
            显示保存成功 = true
        }
    }
}

// MARK: - 配置导入页面

/// 配置导入页面
struct 配置导入页面: View {
    @EnvironmentObject private var 配置管理: 配置描述文件管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 导入方式 = 0
    @State private var 配置名称 = ""
    @State private var 配置内容 = ""
    @State private var 配置类型: 配置文件类型 = .singbox
    @State private var 导入中 = false
    @State private var 导入结果: 配置文件导入结果?

    var body: some View {
        NavigationView {
            Form {
                Section("导入方式") {
                    Picker("方式", selection: $导入方式) {
                        Text("粘贴文本").tag(0)
                        Text("从文件导入").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                if 导入方式 == 0 {
                    Section("配置信息") {
                        AppFormRow(标签: "名称") {
                            TextField("配置名称", text: $配置名称)
                                .multilineTextAlignment(.trailing)
                        }
                        AppFormRow(标签: "类型") {
                            Picker("", selection: $配置类型) {
                                ForEach(配置文件类型.allCases, id: \.self) { 类型 in
                                    Text(类型.显示名称).tag(类型)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    Section("配置内容") {
                        TextEditor(text: $配置内容)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 200)
                    }
                } else {
                    Section("文件导入") {
                        // 文件导入占位，实际需要使用文件选择器
                        VStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("选择配置文件")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                            Text("支持 .json / .yaml 格式")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }

                if let 结果 = 导入结果 {
                    Section("导入结果") {
                        if 结果.成功 {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.成功色)
                                Text("导入成功")
                                    .foregroundColor(.成功色)
                                Spacer()
                            }
                            if !结果.警告.isEmpty {
                                ForEach(结果.警告, id: \.self) { 警告 in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.警告色)
                                        Text(警告)
                                            .font(.system(size: 12))
                                            .foregroundColor(.警告色)
                                        Spacer()
                                    }
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.危险色)
                                Text(结果.错误信息 ?? "导入失败")
                                    .foregroundColor(.危险色)
                                Spacer()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        导入配置()
                    } label: {
                        HStack {
                            Spacer()
                            if 导入中 {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("导入配置")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.主题色)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .disabled(导入中 || (导入方式 == 0 && (配置名称.isEmpty || 配置内容.isEmpty)))
                }
            }
            .navigationTitle("导入配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        关闭()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 导入配置
    private func 导入配置() {
        导入中 = true
        导入结果 = nil

        配置管理.从字符串导入配置(内容: 配置内容, 名称: 配置名称, 类型: 配置类型) { 结果 in
            导入中 = false
            导入结果 = 结果
            if 结果.成功 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    关闭()
                }
            }
        }
    }
}

// MARK: - 新建配置页面

/// 新建配置页面
struct 新建配置页面: View {
    @EnvironmentObject private var 配置管理: 配置描述文件管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 配置名称 = ""
    @State private var 配置描述 = ""
    @State private var 配置类型: 配置文件类型 = .singbox

    var body: some View {
        NavigationView {
            Form {
                Section("配置信息") {
                    AppFormRow(标签: "名称") {
                        TextField("配置名称", text: $配置名称)
                            .multilineTextAlignment(.trailing)
                    }
                    AppFormRow(标签: "描述") {
                        TextField("可选", text: $配置描述)
                            .multilineTextAlignment(.trailing)
                    }
                    AppFormRow(标签: "类型") {
                        Picker("", selection: $配置类型) {
                            ForEach(配置文件类型.allCases, id: \.self) { 类型 in
                                Text(类型.显示名称).tag(类型)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section {
                    Button {
                        创建配置()
                    } label: {
                        HStack {
                            Spacer()
                            Text("创建配置")
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
                    .disabled(配置名称.isEmpty)
                }
            }
            .navigationTitle("新建配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        关闭()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 创建配置
    private func 创建配置() {
        let 新配置 = 配置描述文件(
            id: UUID(),
            名称: 配置名称,
            描述: 配置描述.isEmpty ? nil : 配置描述,
            类型: 配置类型,
            状态: .正常,
            版本: "1.0.0",
            版本号: 1,
            创建时间: Date(),
            最后修改时间: Date(),
            最后使用时间: nil,
            是否激活: false,
            是否默认: false,
            关联订阅ID: nil,
            关联订阅名称: nil,
            文件路径: "configs/\(UUID().uuidString).\(配置类型.文件扩展名)",
            统计: .默认,
            标签: ["新建"],
            备注: nil,
            自动更新: false,
            更新间隔分钟: 360,
            上次更新时间: nil,
            更新错误: nil
        )

        // 保存空配置内容
        let 空内容 = 配置类型 == .singbox ? "{\n  \n}" : ""
        _ = 配置管理.保存配置内容(新配置, 内容: 空内容)
        配置管理.添加配置(新配置)
        关闭()
    }
}

// MARK: - 版本历史页面

/// 版本历史页面
struct 版本历史页面: View {
    let 配置: 配置描述文件
    @EnvironmentObject private var 配置管理: 配置描述文件管理器
    @Environment(\.dismiss) private var 关闭
    @State private var 版本列表: [配置文件版本记录] = []
    @State private var 显示恢复确认 = false
    @State private var 选中版本: 配置文件版本记录?

    var body: some View {
        NavigationView {
            List {
                if 版本列表.isEmpty {
                    EmptyStateView(
                        图标: "clock.arrow.circlepath",
                        标题: "暂无版本记录",
                        说明: "每次保存配置时会自动创建版本备份"
                    )
                } else {
                    ForEach(版本列表) { 版本 in
                        版本行(版本: 版本) {
                            选中版本 = 版本
                            显示恢复确认 = true
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 15))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.页面背景)
            .navigationTitle("版本历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        关闭()
                    }
                }
            }
            .alert("恢复版本", isPresented: $显示恢复确认) {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) {
                    if let 版本 = 选中版本 {
                        _ = 配置管理.恢复版本(版本, 到配置: 配置)
                        关闭()
                    }
                }
            } message: {
                if let 版本 = 选中版本 {
                    Text("确定要恢复到 \(版本.版本名称)（\(版本.创建时间显示)）吗？当前配置将被覆盖，但会先创建新版本备份。")
                }
            }
            .onAppear {
                版本列表 = 配置管理.加载版本列表(配置)
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 版本行
    private func 版本行(版本: 配置文件版本记录, 恢复: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            // 版本图标
            ZStack {
                Circle()
                    .fill(Color.主题色.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("v\(版本.版本号)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.主题色)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(版本.版本名称)
                    .font(.system(size: 14, weight: .medium))
                Text(版本.创建时间显示)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if let 说明 = 版本.修改说明 {
                    Text(说明)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(格式化文件大小(版本.文件大小))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Button("恢复") {
                恢复()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.主题色)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(10)
    }

    /// 格式化文件大小
    private func 格式化文件大小(_ 字节数: Int64) -> String {
        let 大小 = Double(字节数)
        if 大小 < 1024 {
            return "\(Int(大小)) B"
        } else if 大小 < 1024 * 1024 {
            return String(format: "%.1f KB", 大小 / 1024)
        } else {
            return String(format: "%.2f MB", 大小 / (1024 * 1024))
        }
    }
}

// MARK: - 预览

#Preview("配置列表") {
    配置描述文件列表页面()
        .environmentObject(配置描述文件管理器.共享)
}
