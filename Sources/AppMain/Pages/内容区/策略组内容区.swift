//
//  策略组内容区.swift
//  NewVPN
//
//  策略组卡片对应的内容区：展示当前配置文件中定义的出站策略组（selector/urltest），
//  支持手动切换组内节点、查看组类型与延迟
//

import SwiftUI

/// 策略组内容区视图
struct 策略组内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 隧道管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器
    /// 展开的组名集合
    @State private var 展开组集合: Set<String> = []
    /// 搜索关键词
    @State private var 搜索关键词 = ""
    /// 排序方式
    @State private var 排序方式: 策略组排序方式 = .默认
    /// 批量测速中的组名
    @State private var 批量测速中组: String?
    /// 批量测速进度
    @State private var 批量测速进度: (已测: Int, 总数: Int) = (0, 0)

    /// 排序方式枚举
    enum 策略组排序方式: String, CaseIterable {
        case 默认 = "默认"
        case 延迟升序 = "延迟↑"
        case 延迟降序 = "延迟↓"
        case 名称 = "名称"
    }

    /// 过滤后的策略组列表
    private var 过滤后列表: [策略组模型] {
        var 列表 = 状态.策略组列表
        // 搜索过滤
        if !搜索关键词.isEmpty {
            列表 = 列表.filter { 组 in
                组.名称.localizedCaseInsensitiveContains(搜索关键词) ||
                组.当前选中.localizedCaseInsensitiveContains(搜索关键词) ||
                组.节点列表.contains { $0.localizedCaseInsensitiveContains(搜索关键词) }
            }
        }
        return 列表
    }

    var body: some View {
        VStack(spacing: 10) {
            // VPN 未连接提示
            if 隧道管理.当前状态 != .已连接 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("VPN 未连接，策略组数据可能未更新")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.top, 8)
            }

            if 状态.策略组列表.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无策略组")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("策略组由订阅或配置文件自动生成\n订阅节点后将自动出现选择器与自动测速组")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                // 搜索栏 + 工具栏
                VStack(spacing: 8) {
                    // 搜索框
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        TextField("搜索策略组或节点", text: $搜索关键词)
                            .font(.system(size: 14))
                            .textFieldStyle(PlainTextFieldStyle())
                        if !搜索关键词.isEmpty {
                            Button(action: { 搜索关键词 = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.卡片背景)
                    .cornerRadius(10)

                    // 工具栏：排序 + 全部展开/收起
                    HStack(spacing: 12) {
                        // 排序选择
                        Menu {
                            ForEach(排序方式.allCases, id: \.self) { 方式 in
                                Button(action: { 排序方式 = 方式 }) {
                                    HStack {
                                        Text(方式.rawValue)
                                        if 排序方式 == 方式 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 12))
                                Text(排序方式.rawValue)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.卡片背景)
                            .cornerRadius(8)
                        }

                        Spacer()

                        // 全部展开/收起
                        Button(action: 切换全部展开) {
                            HStack(spacing: 4) {
                                Image(systemName: 全部展开 ? "chevron.down" : "chevron.up")
                                    .font(.system(size: 12))
                                Text(全部展开 ? "全部收起" : "全部展开")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.卡片背景)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 8)

                // 策略组列表
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(过滤后列表) { 组 in
                            策略组卡片(
                                组: 排序后节点(组),
                                展开: 展开组集合.contains(组.名称),
                                批量测速中: 批量测速中组 == 组.名称,
                                批量测速进度: 批量测速中组 == 组.名称 ? 批量测速进度 : nil
                            ) {
                                切换展开(组.名称)
                            } 批量测速回调: {
                                批量测速(组)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            策略组管理器.共享.开始轮询()
        }
        .onDisappear {
            策略组管理器.共享.停止轮询()
        }
    }

    /// 是否全部展开
    private var 全部展开: Bool {
        展开组集合.count == 状态.策略组列表.count && !状态.策略组列表.isEmpty
    }

    /// 切换全部展开/收起
    private func 切换全部展开() {
        if 全部展开 {
            展开组集合.removeAll()
        } else {
            展开组集合 = Set(状态.策略组列表.map { $0.名称 })
        }
    }

    /// 切换组展开状态
    private func 切换展开(_ 组名: String) {
        if 展开组集合.contains(组名) {
            展开组集合.remove(组名)
        } else {
            展开组集合.insert(组名)
        }
    }

    /// 排序后节点列表
    private func 排序后节点(_ 组: 策略组模型) -> 策略组模型 {
        var 排序组 = 组
        switch 排序方式 {
        case .默认:
            break
        case .延迟升序:
            排序组.节点列表 = 组.节点列表.sorted { 节点1, 节点2 in
                let 延迟1 = 组.节点延迟[节点1] ?? Int.max
                let 延迟2 = 组.节点延迟[节点2] ?? Int.max
                return 延迟1 < 延迟2
            }
        case .延迟降序:
            排序组.节点列表 = 组.节点列表.sorted { 节点1, 节点2 in
                let 延迟1 = 组.节点延迟[节点1] ?? -1
                let 延迟2 = 组.节点延迟[节点2] ?? -1
                return 延迟1 > 延迟2
            }
        case .名称:
            排序组.节点列表 = 组.节点列表.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return 排序组
    }

    /// 批量测速
    private func 批量测速(_ 组: 策略组模型) {
        guard 批量测速中组 == nil else { return }
        批量测速中组 = 组.名称
        批量测速进度 = (0, 组.节点列表.count)

        let 节点列表 = 组.节点列表
        var 已测数 = 0

        // 串行测速，避免并发过多
        func 测速下一个(_ 索引: Int) {
            guard 索引 < 节点列表.count else {
                批量测速中组 = nil
                策略组管理器.共享.刷新策略组()
                return
            }
            策略组管理器.共享.测速单个节点(节点名: 节点列表[索引]) { _ in
                已测数 += 1
                批量测速进度 = (已测数, 节点列表.count)
                测速下一个(索引 + 1)
            }
        }
        测速下一个(0)
    }
}

// MARK: - 策略组卡片

/// 单个策略组卡片
private struct 策略组卡片: View {
    let 组: 策略组模型
    let 展开: Bool
    let 批量测速中: Bool
    let 批量测速进度: (已测: Int, 总数: Int)?
    let 点击头部: () -> Void
    let 批量测速回调: () -> Void

    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 测速中节点名
    @State private var 测速中节点: String?
    /// 切换中节点名
    @State private var 切换中节点: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部
            Button(action: 点击头部) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        // 组名 + 类型标签
                        HStack(spacing: 8) {
                            Text(组.名称)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(组.类型标题)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(组.类型颜色)
                                .cornerRadius(4)
                        }

                        // 当前选中节点 + 延迟
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.成功色)
                                .font(.system(size: 14))
                            Text(组.当前选中)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            if !组.当前选中.isEmpty {
                                Text(组.延迟文本(组.当前选中))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(组.延迟颜色(组.当前选中))
                            }
                        }
                    }

                    Spacer()

                    // 右侧：批量测速按钮 + 节点数 + 展开箭头
                    VStack(alignment: .trailing, spacing: 6) {
                        // 批量测速按钮
                        Button(action: 批量测速回调) {
                            HStack(spacing: 3) {
                                if 批量测速中, let 进度 = 批量测速进度 {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text("\(进度.已测)/\(进度.总数)")
                                        .font(.system(size: 10, weight: .medium))
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 11))
                                    Text("测速")
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(批量测速中 ? Color.gray : Color(red: 0.98, green: 0.72, blue: 0.20))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(批量测速中)

                        HStack(spacing: 4) {
                            Text("\(组.节点数量)节点")
                                .font(.system(size: 12))
                                .foregroundColor(.次要文字)
                            Image(systemName: 展开 ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // 展开内容：节点列表
            if 展开 {
                Divider()
                    .padding(.horizontal, 14)

                VStack(spacing: 0) {
                    ForEach(Array(组.节点列表.enumerated()), id: \.element) { 索引, 节点名 in
                        节点行(
                            节点名: 节点名,
                            组: 组,
                            索引: 索引,
                            测速中: 测速中节点 == 节点名,
                            切换中: 切换中节点 == 节点名
                        ) {
                            切换节点(节点名)
                        } 测速回调: {
                            测速节点(节点名)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    /// 切换节点
    private func 切换节点(_ 节点名: String) {
        guard 节点名 != 组.当前选中 else { return }
        切换中节点 = 节点名
        策略组管理器.共享.切换节点(组名: 组.名称, 节点名: 节点名) { 成功 in
            切换中节点 = nil
            if !成功 {
                // 切换失败提示
            }
        }
    }

    /// 测速单个节点
    private func 测速节点(_ 节点名: String) {
        测速中节点 = 节点名
        策略组管理器.共享.测速单个节点(节点名: 节点名) { _ in
            测速中节点 = nil
        }
    }
}

// MARK: - 节点行

/// 节点行视图
private struct 节点行: View {
    let 节点名: String
    let 组: 策略组模型
    let 索引: Int
    let 测速中: Bool
    let 切换中: Bool
    let 切换回调: () -> Void
    let 测速回调: () -> Void

    /// 是否为当前选中
    private var 选中: Bool { 组.当前选中 == 节点名 }
    /// 显示复制成功提示
    @State private var 显示复制提示 = false

    var body: some View {
        ZStack {
            Button(action: 切换回调) {
                HStack(spacing: 12) {
                    // 选中指示器
                    Image(systemName: 选中 ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(选中 ? .成功色 : .secondary.opacity(0.4))
                        .font(.system(size: 18))

                    // 节点名称
                    Text(节点名)
                        .font(.system(size: 14))
                        .foregroundColor(选中 ? .primary : .次要文字)
                        .lineLimit(1)

                    Spacer()

                    // 延迟或测速状态
                    if 测速中 {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if 切换中 {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text(组.延迟文本(节点名))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(组.延迟颜色(节点名))
                    }

                    // 测速按钮
                    Button(action: 测速回调) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(测速中)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(选中 ? Color.成功色.opacity(0.08) : Color.clear)
            .contextMenu {
                // 长按菜单：复制节点名称
                Button(action: {
                    UIPasteboard.general.string = 节点名
                    显示复制提示 = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        显示复制提示 = false
                    }
                }) {
                    Label("复制节点名称", systemImage: "doc.on.doc")
                }
                // 测速
                Button(action: 测速回调) {
                    Label("测试延迟", systemImage: "bolt.fill")
                }
                // 设为当前节点（如果未选中）
                if !选中 {
                    Button(action: 切换回调) {
                        Label("切换到此节点", systemImage: "checkmark.circle")
                    }
                }
            }

            // 复制成功提示
            if 显示复制提示 {
                Text("已复制节点名称")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(8)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - 策略组数据模型

/// 策略组模型（从 sing-box 配置或订阅解析得到）
struct 策略组模型: Identifiable {
    let id = UUID()
    /// 组名称（如 "代理"、"自动选择"）
    let 名称: String
    /// 组类型：selector / urltest
    let 类型: String
    /// 当前选中节点
    let 当前选中: String
    /// 组内节点数
    let 节点数量: Int
    /// 组内节点名称列表（var 支持排序修改）
    var 节点列表: [String]
    /// 节点延迟字典（节点名: 延迟毫秒）
    let 节点延迟: [String: Int]
    /// 是否正在测速
    var 测速中: Bool = false

    /// 类型中文标题
    var 类型标题: String {
        switch 类型 {
        case "selector": return "手动选择"
        case "urltest": return "自动测速"
        default: return 类型
        }
    }

    /// 类型标签颜色
    var 类型颜色: Color {
        switch 类型 {
        case "selector": return Color(red: 0.24, green: 0.77, blue: 0.82)
        case "urltest": return Color(red: 0.98, green: 0.72, blue: 0.20)
        default: return .gray
        }
    }

    /// 获取节点延迟显示文本
    func 延迟文本(_ 节点名: String) -> String {
        guard let 延迟 = 节点延迟[节点名] else { return "未测" }
        if 延迟 <= 0 { return "超时" }
        return "\(延迟)ms"
    }

    /// 获取节点延迟颜色
    func 延迟颜色(_ 节点名: String) -> Color {
        guard let 延迟 = 节点延迟[节点名] else { return .secondary }
        if 延迟 <= 0 { return .red }
        if 延迟 < 100 { return Color(red: 0.20, green: 0.80, blue: 0.40) }
        if 延迟 < 300 { return Color(red: 0.95, green: 0.70, blue: 0.20) }
        return .red
    }
}
