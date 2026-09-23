//
//  下载进度视图.swift
//  NewVPN
//
//  IPA 下载进度展示视图
//  包含圆环进度、百分比、已下载/总大小、下载速度、线性进度条、取消按钮
//

import SwiftUI

/// 下载进度视图
struct 下载进度视图: View {
    /// 下载管理器
    @ObservedObject var 下载管理器: AppDownloadManager
    /// 取消回调
    let 取消回调: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 圆环进度 + 百分比
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: 下载管理器.进度)
                    .stroke(Color.主题色, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: 下载管理器.进度)

                VStack(spacing: 2) {
                    Text("\(Int(下载管理器.进度 * 100))%")
                        .font(.system(size: 24, weight: .bold))
                    Text("下载中")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // 已下载 / 总大小
            Text("\(AppDownloadManager.格式化字节(下载管理器.已下载字节)) / \(AppDownloadManager.格式化字节(下载管理器.总字节))")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            // 下载速度
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.主题色)
                Text(String(format: "%.1f MB/s", 下载管理器.下载速度))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.主题色)
            }

            // 线性进度条
            ProgressView(value: 下载管理器.进度)
                .progressViewStyle(.linear)
                .tint(.主题色)
                .padding(.horizontal, 20)

            // 取消按钮
            Button {
                取消回调()
            } label: {
                Text("取消下载")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 20)
    }
}

// MARK: - 预览

#Preview {
    下载进度视图(下载管理器: AppDownloadManager.共享) {
        // 取消
    }
    .background(Color.卡片背景)
}
