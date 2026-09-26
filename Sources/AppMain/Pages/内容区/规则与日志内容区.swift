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
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(状态.重写规则列表) { 规则 in
                重写规则行(规则: 规则)
            }
        }
        .padding(.horizontal, 15)
    }
}

/// 单个重写规则行
private struct 重写规则行: View {
    let 规则: 重写规则模型

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(规则.名称)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Toggle("", isOn: .constant(规则.启用))
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            HStack(spacing: 6) {
                Text(规则.重写类型)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.99, green: 0.33, blue: 0.63))
                    .cornerRadius(4)
                Text(规则.域名后缀)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Text(规则.匹配表达式)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 分流规则内容区

/// 分流规则内容区视图
struct 分流规则内容区: View {
    @EnvironmentObject private var 分流管理: 分流规则管理器
    @State private var 搜索关键词 = ""
    @State private var 展开的分组ID: UUID?

    var body: some View {
        VStack(spacing: 12) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                TextField("搜索规则名称或匹配值", text: $搜索关键词)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.卡片背景)
            .cornerRadius(10)

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
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 15)
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
            Text("在设置中添加分流规则分组")
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

// MARK: - 预览

#Preview {
    ScrollView {
        重写规则内容区()
            .environmentObject(AppState.共享)
    }
    .background(Color.页面背景)
}
