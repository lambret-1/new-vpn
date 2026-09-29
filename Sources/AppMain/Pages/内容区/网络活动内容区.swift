//
//  网络活动内容区.swift
//  NewVPN
//
//  网络活动卡片对应的内容区
//  TCP/UDP 统计 + 连接记录列表
//

import SwiftUI

/// 网络活动内容区视图
struct 网络活动内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 隧道管理器（获取真实流量统计）
    @EnvironmentObject private var 隧道管理: 隧道管理器
    /// CPU 占用监控器
    @StateObject private var CPU监控 = CPU占用监控器.共享
    /// 内存占用监控器
    @StateObject private var 内存监控 = 内存占用监控器.共享
    /// VPN 扩展内存监控器
    @StateObject private var 扩展内存监控 = VPN扩展内存监控器.共享
    /// 当前选中的连接（用于显示详情）
    @State private var 选中连接: 网络连接模型?

    var body: some View {
        VStack(spacing: 16) {
            // TCP/扩展内存/CPU/内存 统计区
            流量统计区(
                tcp数量: tcp数量,
                CPU使用率: CPU监控.当前使用率,
                CPU等级: CPU监控.等级,
                内存占用: 内存监控.当前占用百分比,
                内存等级: 内存监控.等级,
                内存显示: 内存监控.占用显示,
                扩展内存: 扩展内存监控.当前占用字节,
                扩展内存等级: 扩展内存监控.等级,
                扩展内存显示: 扩展内存监控.占用显示,
                扩展内存百分比: 扩展内存监控.占用百分比,
                总下行: 隧道管理.流量统计.下行字节,
                总上行: 隧道管理.流量统计.上行字节
            )

            // 连接记录列表
            if 状态.网络连接列表.isEmpty {
                空状态视图()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(状态.网络连接列表) { 连接 in
                        连接记录行(连接: 连接)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                选中连接 = 连接
                            }
                        if 连接.id != 状态.网络连接列表.last?.id {
                            Divider()
                                .padding(.leading, 15)
                        }
                    }
                }
                .background(Color.卡片背景)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 15)
        .onAppear {
            CPU监控.开始监控(间隔: 2.0)
            内存监控.开始监控(间隔: 2.0)
            扩展内存监控.开始监控(间隔: 2.0)
            // VPN未连接时扩展内存显示0
            if 隧道管理.当前状态 != .已连接 {
                扩展内存监控.重置为零()
            }
        }
        .onDisappear {
            CPU监控.停止监控()
            内存监控.停止监控()
            扩展内存监控.停止监控()
        }
        .onChange(of: 隧道管理.当前状态) { 新状态 in
            // VPN断开时重置扩展内存为0
            if 新状态 != .已连接 {
                扩展内存监控.重置为零()
            }
        }
        .sheet(item: $选中连接) { 连接 in
            连接详情页面(连接: 连接)
                .presentationDetents([.fraction(0.95)])
                .presentationDragIndicator(.visible)
        }
    }

    /// TCP 连接数
    private var tcp数量: Int {
        状态.网络连接列表.filter { $0.协议 == "TCP" }.count
    }
}

// MARK: - 流量统计区

/// 流量统计区（四宫格：TCP / MITM开关 / CPU占用 / HTTP抓包开关）
private struct 流量统计区: View {
    let tcp数量: Int
    let CPU使用率: Double
    let CPU等级: CPU占用监控器.CPU等级
    let 内存占用: Double
    let 内存等级: 内存占用监控器.内存等级
    let 内存显示: String
    let 扩展内存: UInt64
    let 扩展内存等级: VPN扩展内存监控器.扩展内存等级
    let 扩展内存显示: String
    let 扩展内存百分比: Double
    let 总下行: UInt64
    let 总上行: UInt64

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // TCP 连接数
            统计卡片(
                图标: "rectangle.connected.to.line.below",
                图标颜色: Color(red: 0.91, green: 0.36, blue: 0.20),
                标题: "TCP",
                数值: "\(tcp数量)",
                单位: "连接"
            )

            // VPN 扩展内存可视化
            VPN扩展内存卡片(
                占用: 扩展内存百分比,
                等级: 扩展内存等级,
                显示: 扩展内存显示,
                立即采样回调: { 扩展内存监控.立即采样() },
                清理内存回调: { 扩展内存监控.清理扩展内存() }
            )

            // CPU 占用可视化
            CPU占用卡片(使用率: CPU使用率, 等级: CPU等级)

            // 内存占用可视化
            内存占用卡片(占用: 内存占用, 等级: 内存等级, 显示: 内存显示)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    /// 单个统计卡片（高度与CPU/内存卡片对齐）
    private func 统计卡片(图标: String, 图标颜色: Color, 标题: String, 数值: String, 单位: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: 图标)
                    .font(.system(size: 14))
                    .foregroundColor(图标颜色)
                Text(标题)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(数值)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            // 占位进度条（透明，保持高度一致）
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.clear)
                .frame(height: 6)
            Text(单位)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.页面背景)
        .cornerRadius(10)
    }

    /// CPU 占用可视化卡片（带进度条）
    private func CPU占用卡片(使用率: Double, 等级: CPU占用监控器.CPU等级) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 14))
                    .foregroundColor(等级.颜色)
                Text("CPU")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(等级.文字)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(等级.颜色)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(等级.颜色.opacity(0.15))
                    .cornerRadius(4)
            }

            // 数值
            Text(String(format: "%.1f%%", 使用率))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            // 进度条
            GeometryReader { 几何 in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // 进度填充
                    RoundedRectangle(cornerRadius: 3)
                        .fill(等级.颜色)
                        .frame(width: 几何.size.width * CGFloat(min(使用率 / 100, 1.0)), height: 6)
                }
            }
            .frame(height: 6)

            // 底部说明
            Text("APP+扩展")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.页面背景)
        .cornerRadius(10)
    }

    /// 内存占用可视化卡片（带进度条，样式与CPU卡片一致）
    private func 内存占用卡片(占用: Double, 等级: 内存占用监控器.内存等级, 显示: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 14))
                    .foregroundColor(等级.颜色)
                Text("内存")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(等级.文字)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(等级.颜色)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(等级.颜色.opacity(0.15))
                    .cornerRadius(4)
            }

            // 数值
            Text(显示)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            // 进度条
            GeometryReader { 几何 in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // 进度填充
                    RoundedRectangle(cornerRadius: 3)
                        .fill(等级.颜色)
                        .frame(width: 几何.size.width * CGFloat(min(占用 / 100, 1.0)), height: 6)
                }
            }
            .frame(height: 6)

            // 底部说明
            Text(String(format: "%.1f%%", 占用))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.页面背景)
        .cornerRadius(10)
    }

    /// VPN 扩展内存可视化卡片（带进度条，样式与CPU/内存卡片一致）
    private func VPN扩展内存卡片(占用: Double, 等级: VPN扩展内存监控器.扩展内存等级, 显示: String, 立即采样回调: @escaping () -> Void, 清理内存回调: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 14))
                    .foregroundColor(等级.颜色)
                Text("扩展")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(等级.文字)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(等级.颜色)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(等级.颜色.opacity(0.15))
                    .cornerRadius(4)
            }

            // 数值
            Text(显示)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            // 进度条
            GeometryReader { 几何 in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // 进度填充
                    RoundedRectangle(cornerRadius: 3)
                        .fill(等级.颜色)
                        .frame(width: 几何.size.width * CGFloat(min(占用 / 100, 1.0)), height: 6)
                }
            }
            .frame(height: 6)

            // 底部说明
            Text("VPN隧道进程")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.页面背景)
        .cornerRadius(10)
        .contentShape(Rectangle())
        .contextMenu {
            // 立即采样
            Button {
                立即采样回调()
            } label: {
                Label("立即采样", systemImage: "arrow.clockwise")
            }
            // 一键清理扩展内存
            Button {
                清理内存回调()
            } label: {
                Label("一键清理内存", systemImage: "trash")
            }
        }
    }

    /// 格式化字节数
    private func 格式化字节(_ 字节: UInt64) -> String {
        if 字节 < 1024 {
            return "\(字节)B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.1fK", Double(字节) / 1024)
        } else if 字节 < 1024 * 1024 * 1024 {
            return String(format: "%.1fM", Double(字节) / (1024 * 1024))
        } else {
            return String(format: "%.1fG", Double(字节) / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - 空状态视图

/// 空状态视图
private struct 空状态视图: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无网络连接")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text("启动 VPN 后将显示实时连接信息")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 连接记录行

/// 单个网络连接记录行
private struct 连接记录行: View {
    /// 连接数据
    let 连接: 网络连接模型

    /// 时间格式化器
    private let 时间格式: DateFormatter = {
        let 格式 = DateFormatter()
        格式.dateFormat = "MM/dd HH:mm:ss"
        return 格式
    }()

    /// 状态码颜色
    private var 状态码颜色: Color {
        guard let 码 = 连接.状态码 else { return .secondary }
        if 码 >= 200 && 码 < 300 { return .成功色 }
        if 码 >= 300 && 码 < 400 { return .主题色 }
        if 码 >= 400 && 码 < 500 { return .警告色 }
        if 码 >= 500 { return .危险色 }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：时间 + 协议 + 状态 + 状态码
            HStack {
                Text(时间格式.string(from: 连接.开始时间))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(连接.协议)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(连接.协议 == "TCP" ? Color(red: 0.91, green: 0.36, blue: 0.20) : Color(red: 0.20, green: 0.55, blue: 0.91))
                    .cornerRadius(4)
                // 连接状态
                Circle()
                    .fill(连接.已关闭 ? Color.secondary : Color.成功色)
                    .frame(width: 8, height: 8)
                Spacer()
                // 状态码
                if let 码 = 连接.状态码 {
                    Text("\(码)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(状态码颜色)
                }
                Text("#\(连接.序号)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 第二行：域名
            Text("\(连接.域名 ?? 连接.远程地址):\(连接.远程端口)")
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)

            // 第三行：规则标签
            if let 规则 = 连接.匹配规则, !规则.isEmpty {
                Text(规则)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // 第四行：出站策略 + 流量
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: 连接.出站策略 == "direct" ? "arrow.right" : "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(连接.出站策略 == "direct" ? .成功色 : .主题色)
                    Text("\(连接.出站策略) (\(连接.远程地址))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(格式化字节(连接.下行字节))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(格式化字节(连接.上行字节))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }

    /// 格式化字节数
    private func 格式化字节(_ 字节: Int64) -> String {
        if 字节 < 1024 {
            return "\(字节)B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.1fKB", Double(字节) / 1024)
        } else {
            return String(format: "%.1fMB", Double(字节) / (1024 * 1024))
        }
    }
}

// MARK: - MITM 开关卡片

/// MITM 解密快捷开关卡片
private struct MITM开关卡片: View {
    @EnvironmentObject private var 隧道管理: 隧道管理器
    @State private var 启用 = MITM管理器.共享.启用
    @State private var 显示设置 = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.55, green: 0.27, blue: 0.91))
                Text("MITM")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack {
                Text(启用 ? "解密中" : "已关闭")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(启用 ? .成功色 : .secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { 启用 },
                    set: { 新值 in
                        启用 = 新值
                        MITM管理器.共享.启用 = 新值
                        if 隧道管理.当前状态 == .已连接 {
                            隧道管理.重新加载配置()
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .frame(width: 42)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                显示设置 = true
            } label: {
                Label("进入 MITM 设置", systemImage: "gearshape")
            }
            Button {
                启用.toggle()
                MITM管理器.共享.启用 = 启用
                if 隧道管理.当前状态 == .已连接 {
                    隧道管理.重新加载配置()
                }
            } label: {
                Label(启用 ? "关闭解密" : "开启解密", systemImage: 启用 ? "pause.circle" : "play.circle")
            }
        }
        .sheet(isPresented: $显示设置) {
            MITM设置页面()
                .environmentObject(MITM管理器.共享)
        }
    }
}

// MARK: - HTTP 抓包开关卡片

/// HTTP 抓包快捷开关卡片
private struct HTTP抓包开关卡片: View {
    @EnvironmentObject private var 隧道管理: 隧道管理器
    @State private var 启用 = 抓包存储管理器.共享.是否启用
    @State private var 显示设置 = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.20, green: 0.55, blue: 0.91))
                Text("抓包")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack {
                Text(启用 ? "抓包中" : "已关闭")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(启用 ? .成功色 : .secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { 启用 },
                    set: { 新值 in
                        启用 = 新值
                        抓包存储管理器.共享.是否启用 = 新值
                        if 隧道管理.当前状态 == .已连接 {
                            隧道管理.重新加载配置()
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .frame(width: 42)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                显示设置 = true
            } label: {
                Label("进入抓包记录", systemImage: "list.bullet")
            }
            Button {
                启用.toggle()
                抓包存储管理器.共享.是否启用 = 启用
                if 隧道管理.当前状态 == .已连接 {
                    隧道管理.重新加载配置()
                }
            } label: {
                Label(启用 ? "停止抓包" : "开始抓包", systemImage: 启用 ? "pause.circle" : "play.circle")
            }
            Button {
                抓包存储管理器.共享.清空记录()
            } label: {
                Label("清空抓包记录", systemImage: "trash")
            }
        }
        .sheet(isPresented: $显示设置) {
            抓包列表页面()
                .environmentObject(隧道管理)
        }
    }
}

// MARK: - 连接详情页面

/// 连接详情页面：显示单个网络连接的完整信息
struct 连接详情页面: View {
    /// 连接数据
    let 连接: 网络连接模型
    /// 关闭页面回调
    @Environment(\.dismiss) private var 关闭

    /// 时间格式化器
    private let 时间格式: DateFormatter = {
        let 格式 = DateFormatter()
        格式.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return 格式
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 状态概览卡片
                    状态概览卡片(连接: 连接)

                    // 地址信息
                    详情分组(标题: "地址信息") {
                        详情行(标签: "目标地址", 值: 连接.域名 ?? "\(连接.远程地址):\(连接.远程端口)")
                        详情分隔线()
                        详情行(标签: "远程地址", 值: "\(连接.远程地址):\(连接.远程端口)")
                        详情分隔线()
                        详情行(标签: "本地地址", 值: "\(连接.本地地址):\(连接.本地端口)")
                        if let 国家 = 连接.国家地区, !国家.isEmpty {
                            详情分隔线()
                            详情行(标签: "国家/地区", 值: 国家)
                        }
                    }

                    // 连接信息
                    详情分组(标题: "连接信息") {
                        详情行(标签: "连接序号", 值: "#\(连接.序号)")
                        详情分隔线()
                        详情行(标签: "协议", 值: 连接.协议)
                        详情分隔线()
                        详情行(标签: "开始时间", 值: 时间格式.string(from: 连接.开始时间))
                        详情分隔线()
                        详情行(标签: "TLS握手", 值: "未记录")
                        详情分隔线()
                        详情行(标签: "连接状态", 值: 连接.已关闭 ? "已关闭" : "活跃中", 值颜色: 连接.已关闭 ? .secondary : .成功色)
                        if let 状态码 = 连接.状态码 {
                            详情分隔线()
                            详情行(标签: "HTTP状态码", 值: "\(状态码)", 值颜色: 状态码颜色(状态码))
                        }
                    }

                    // 分流与策略
                    详情分组(标题: "分流与策略") {
                        详情行(标签: "匹配规则", 值: 连接.匹配规则 ?? "未匹配")
                        详情分隔线()
                        详情行(标签: "出站策略", 值: 连接.出站策略, 值颜色: 连接.出站策略 == "direct" ? .成功色 : .主题色)
                    }

                    // 流量统计
                    详情分组(标题: "流量统计") {
                        详情行(标签: "上行流量", 值: 格式化字节(连接.上行字节))
                        详情分隔线()
                        详情行(标签: "下行流量", 值: 格式化字节(连接.下行字节))
                        详情分隔线()
                        详情行(标签: "总流量", 值: 格式化字节(连接.上行字节 + 连接.下行字节))
                    }
                }
                .padding(15)
            }
            .background(Color.页面背景)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        关闭()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    /// 状态码颜色
    private func 状态码颜色(_ 码: Int) -> Color {
        if 码 >= 200 && 码 < 300 { return .成功色 }
        if 码 >= 300 && 码 < 400 { return .主题色 }
        if 码 >= 400 && 码 < 500 { return .警告色 }
        if 码 >= 500 { return .危险色 }
        return .secondary
    }

    /// 格式化字节数
    private func 格式化字节(_ 字节: Int64) -> String {
        if 字节 < 1024 {
            return "\(字节) B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.2f KB", Double(字节) / 1024)
        } else if 字节 < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB", Double(字节) / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", Double(字节) / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - 状态概览卡片

private struct 状态概览卡片: View {
    let 连接: 网络连接模型

    var body: some View {
        VStack(spacing: 12) {
            // 域名/地址
            Text(连接.域名 ?? "\(连接.远程地址):\(连接.远程端口)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // 状态标签
            HStack(spacing: 8) {
                // 协议标签
                Text(连接.协议)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(连接.协议 == "TCP" ? Color(red: 0.91, green: 0.36, blue: 0.20) : Color(red: 0.20, green: 0.55, blue: 0.91))
                    .cornerRadius(6)

                // 状态标签
                Text(连接.已关闭 ? "已关闭" : "活跃中")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(连接.已关闭 ? Color.secondary : Color.成功色)
                    .cornerRadius(6)

                // 出站策略标签
                Text(连接.出站策略 == "direct" ? "直连" : "代理")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(连接.出站策略 == "direct" ? Color.成功色 : Color.主题色)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }
}

// MARK: - 详情分组

private struct 详情分组<Content: View>: View {
    let 标题: String
    let 内容构建: () -> Content

    init(标题: String, @ViewBuilder 内容: @escaping () -> Content) {
        self.标题 = 标题
        self.内容构建 = 内容
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(标题)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                内容构建()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 4)
            .background(Color.卡片背景)
            .cornerRadius(12)
        }
    }
}

// MARK: - 详情行

private struct 详情行: View {
    let 标签: String
    let 值: String
    var 值颜色: Color = .primary

    var body: some View {
        HStack {
            Text(标签)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Spacer()
            Text(值)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(值颜色)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 10)
    }
}

/// 详情分隔线
private struct 详情分隔线: View {
    var body: some View {
        Divider()
            .padding(.leading, 100)
    }
}

// MARK: - 预览

#Preview {
    网络活动内容区()
        .environmentObject(AppState.共享)
        .background(Color.页面背景)
}
