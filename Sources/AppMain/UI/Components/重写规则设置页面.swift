//
//  重写规则设置页面.swift
//  NewVPN
//
//  URL 重写规则设置页面
//

import SwiftUI

// MARK: - 重写规则设置页面

/// 重写规则设置页面
struct 重写规则设置页面: View {
    @EnvironmentObject private var 重写管理: 重写规则管理器
    @Environment(\.dismiss) private var 关闭

    @State private var 显示添加规则 = false
    @State private var 显示预设规则 = false
    @State private var 展开的分组ID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                // 功能开关
                Section {
                    Toggle("启用重写功能", isOn: $重写管理.配置.启用)
                        .tint(.主题色)
                } header: {
                    Text("功能开关")
                } footer: {
                    Text("启用后，匹配的 URL 请求将被重写或阻断。URL 重写需要同时启用 MITM 解密才能对 HTTPS 生效。")
                }

                // 统计信息
                Section {
                    HStack {
                        统计项(数值: 重写管理.统计.分组数, 标签: "分组", 颜色: .主题色)
                        分割线()
                        统计项(数值: 重写管理.统计.总规则数, 标签: "总规则", 颜色: .成功色)
                        分割线()
                        统计项(数值: 重写管理.统计.启用规则数, 标签: "已启用", 颜色: .警告色)
                    }
                    .padding(.vertical, 8)
                }

                // 操作按钮
                Section {
                    HStack(spacing: 12) {
                        Button {
                            显示添加规则 = true
                        } label: {
                            Label("添加规则", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.主题色)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.主题色.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button {
                            显示预设规则 = true
                        } label: {
                            Label("预设规则", systemImage: "square.stack.3d.down.forward")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.主题色)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.主题色.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // 分组和规则列表
                ForEach($重写管理.配置.分组列表) { $分组 in
                    Section {
                        // 分组标题
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if 展开的分组ID == 分组.id {
                                    展开的分组ID = nil
                                } else {
                                    展开的分组ID = 分组.id
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: 分组.图标)
                                    .foregroundColor(.主题色)
                                Text(分组.名称)
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Text("\(分组.启用规则数)/\(分组.规则列表.count)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Image(systemName: 展开的分组ID == 分组.id ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // 分组启用开关
                        Toggle("启用分组", isOn: Binding(
                            get: { 分组.启用 },
                            set: { _ in 重写管理.切换分组启用(分组) }
                        ))
                        .tint(.主题色)

                        // 规则列表（展开时显示）
                        if 展开的分组ID == 分组.id {
                            if 分组.规则列表.isEmpty {
                                Text("暂无规则")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(分组.规则列表) { 规则 in
                                    规则行(规则: 规则, 分组: 分组)
                                }
                            }
                        }
                    } header: {
                        Text(分组.名称)
                    }
                }
            }
            .navigationTitle("重写规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { 关闭() }
                }
            }
            .sheet(isPresented: $显示添加规则) {
                重写规则编辑页面(规则: nil, 分组: 重写管理.配置.分组列表.first)
                    .environmentObject(重写管理)
            }
            .sheet(isPresented: $显示预设规则) {
                预设重写规则页面()
                    .environmentObject(重写管理)
            }
        }
    }

    // MARK: - 统计项

    private func 统计项(数值: Int, 标签: String, 颜色: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(数值)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(颜色)
            Text(标签)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func 分割线() -> some View {
        Rectangle()
            .fill(Color.分割线)
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    // MARK: - 规则行

    private func 规则行(规则: 重写规则项, 分组: 重写规则分组) -> some View {
        HStack(spacing: 10) {
            Image(systemName: 规则.类型.图标)
                .font(.system(size: 14))
                .foregroundColor(.主题色)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(规则.名称)
                    .font(.system(size: 14))
                Text(规则.匹配正则)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 类型标签
            Text(规则.类型.rawValue)
                .font(.system(size: 10))
                .foregroundColor(.主题色)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.主题色.opacity(0.1))
                .cornerRadius(4)

            Toggle("", isOn: Binding(
                get: { 规则.启用 },
                set: { _ in 重写管理.切换规则启用(规则) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .主题色))
            .frame(width: 45)
        }
        .padding(.vertical, 4)
        .opacity(规则.启用 ? 1.0 : 0.5)
        .contextMenu {
            Button {
                // 编辑规则
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
}

// MARK: - 重写规则编辑页面

/// 重写规则编辑/添加页面
struct 重写规则编辑页面: View {
    @EnvironmentObject private var 重写管理: 重写规则管理器
    @Environment(\.dismiss) private var 关闭

    let 规则: 重写规则项?
    let 分组: 重写规则分组?

    @State private var 名称 = ""
    @State private var 类型: 重写规则类型 = .URL重写
    @State private var 匹配正则 = ""
    @State private var 替换内容 = ""
    @State private var 启用 = true
    @State private var 优先级 = 100
    @State private var 备注 = ""

    init(规则: 重写规则项?, 分组: 重写规则分组?) {
        self.规则 = 规则
        self.分组 = 分组
        if let 规则 = 规则 {
            _名称 = State(initialValue: 规则.名称)
            _类型 = State(initialValue: 规则.类型)
            _匹配正则 = State(initialValue: 规则.匹配正则)
            _替换内容 = State(initialValue: 规则.替换内容)
            _启用 = State(initialValue: 规则.启用)
            _优先级 = State(initialValue: 规则.优先级)
            _备注 = State(initialValue: 规则.备注 ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $名称)

                    Picker("规则类型", selection: $类型) {
                        ForEach(重写规则类型.allCases) { 类型 in
                            Label(类型.rawValue, systemImage: 类型.图标).tag(类型)
                        }
                    }

                    TextField("匹配正则表达式", text: $匹配正则)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if 类型 != .请求阻断 {
                        TextField("替换内容", text: $替换内容)
                            .autocapitalization(.none)
                    }
                }

                Section("高级设置") {
                    Toggle("启用规则", isOn: $启用)
                        .tint(.主题色)

                    Stepper("优先级：\(优先级)", value: $优先级, in: 1...999)

                    TextField("备注", text: $备注)
                }

                Section("类型说明") {
                    Text(类型.描述)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
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
                        关闭()
                    }
                    .disabled(名称.isEmpty || 匹配正则.isEmpty)
                }
            }
        }
    }

    /// 保存规则
    private func 保存规则() {
        let 新规则 = 重写规则项(
            名称: 名称,
            类型: 类型,
            匹配正则: 匹配正则,
            替换内容: 替换内容,
            优先级: 优先级,
            备注: 备注.isEmpty ? nil : 备注
        )

        if let 目标分组 = 分组 {
            重写管理.添加规则(新规则, 到分组: 目标分组)
        }
    }
}

// MARK: - 预设重写规则页面

/// 预设重写规则页面
struct 预设重写规则页面: View {
    @EnvironmentObject private var 重写管理: 重写规则管理器
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationStack {
            List {
                ForEach(预设重写规则集.所有预设) { 预设 in
                    Button {
                        重写管理.应用预设规则集(预设)
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
                                Text(预设.描述)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
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
            .navigationTitle("预设重写规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 关闭() }
                }
            }
        }
    }
}
