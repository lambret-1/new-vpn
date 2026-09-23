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

    var body: some View {
        VStack(spacing: 16) {
            // TCP/UDP 统计区
            流量统计区()

            // 连接记录列表
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
        .padding(.horizontal, 15)
    }
}

// MARK: - 流量统计区

/// TCP/UDP 流量统计区
private struct 流量统计区: View {
    var body: some View {
        HStack(spacing: 0) {
            // TCP 统计
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("TCP")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.91, green: 0.36, blue: 0.20))
                        .cornerRadius(6)
                    Spacer()
                }
                Text("360")
                    .font(.system(size: 36, weight: .bold))
                Text("UDP")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.91, green: 0.36, blue: 0.20).opacity(0.7))
                    .cornerRadius(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("34")
                    .font(.system(size: 36, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            // 中间分割线
            Rectangle()
                .fill(Color.分割线)
                .frame(width: 1)
                .padding(.vertical, 8)

            // 拦截/JS 统计
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "nosign")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.91, green: 0.36, blue: 0.20))
                    Text("49")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                }
                HStack(spacing: 8) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.91, green: 0.36, blue: 0.20))
                    Text("2")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：时间 + 延迟 + 连接序号
            HStack {
                Text(时间格式.string(from: 连接.开始时间))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("#\(Int.random(in: 10...50))ms")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.主题色)
                Spacer()
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(连接.序号 + 350)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 第二行：域名
            Text("\(连接.域名 ?? 连接.远程地址):\(连接.远程端口)")
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)

            // 第三行：规则标签
            Text("HOST-SUFFIX, \(连接.域名 ?? "未知"), 规则匹配")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // 第四行：出站策略 + 流量
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: 连接.出站策略 == "直连" ? "arrow.right" : "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(连接.出站策略 == "直连" ? .成功色 : .主题色)
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
