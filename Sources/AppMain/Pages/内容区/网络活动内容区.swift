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

    var body: some View {
        VStack(spacing: 16) {
            // TCP/UDP 统计区
            流量统计区(
                tcp数量: tcp数量,
                udp数量: udp数量,
                活跃数量: 活跃数量,
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
    }

    /// TCP 连接数
    private var tcp数量: Int {
        状态.网络连接列表.filter { $0.协议 == "TCP" }.count
    }

    /// UDP 连接数
    private var udp数量: Int {
        状态.网络连接列表.filter { $0.协议 == "UDP" }.count
    }

    /// 活跃连接数
    private var 活跃数量: Int {
        状态.网络连接列表.filter { !$0.已关闭 }.count
    }
}

// MARK: - 流量统计区

/// TCP/UDP 流量统计区（四宫格整齐布局）
private struct 流量统计区: View {
    let tcp数量: Int
    let udp数量: Int
    let 活跃数量: Int
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

            // UDP 连接数
            统计卡片(
                图标: "dot.radiowaves.left.and.right",
                图标颜色: Color(red: 0.20, green: 0.55, blue: 0.91),
                标题: "UDP",
                数值: "\(udp数量)",
                单位: "连接"
            )

            // 活跃连接数
            统计卡片(
                图标: "bolt.fill",
                图标颜色: .成功色,
                标题: "活跃",
                数值: "\(活跃数量)",
                单位: "连接"
            )

            // 总流量
            统计卡片(
                图标: "arrow.down.circle.fill",
                图标颜色: .主题色,
                标题: "下载",
                数值: 格式化字节(总下行),
                单位: "上传 \(格式化字节(总上行))"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    /// 单个统计卡片
    private func 统计卡片(图标: String, 图标颜色: Color, 标题: String, 数值: String, 单位: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: 图标)
                    .font(.system(size: 14))
                    .foregroundColor(图标颜色)
                Text(标题)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(数值)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(单位)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.页面背景)
        .cornerRadius(10)
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

// MARK: - 预览

#Preview {
    网络活动内容区()
        .environmentObject(AppState.共享)
        .background(Color.页面背景)
}
