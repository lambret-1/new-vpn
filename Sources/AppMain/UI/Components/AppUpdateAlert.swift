//
//  AppUpdateAlert.swift
//  NewVPN
//
//  应用更新多状态居中弹窗
//  状态：检测中 / 发现新版本 / 已是最新 / 检测失败 / 下载中
//  样式：居中显示，缩放淡入动画，四角统一圆角
//

import SwiftUI

/// 应用更新弹窗视图（居中显示）
struct AppUpdateAlert: View {
    /// 更新管理器
    @ObservedObject var 更新管理器: AppUpdateManager
    /// 下载管理器
    @ObservedObject var 下载管理器: AppDownloadManager
    /// 关闭回调
    let 关闭回调: () -> Void

    /// 屏幕尺寸
    private let 屏幕宽度 = UIScreen.main.bounds.width
    private let 屏幕高度 = UIScreen.main.bounds.height

    /// 弹窗宽度
    private var 弹窗宽度: CGFloat { 屏幕宽度 - 64 }

    /// 弹窗最大高度
    private var 最大高度: CGFloat { 屏幕高度 * 0.75 }

    var body: some View {
        ZStack {
            // 半透明背景遮罩
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    处理外部点击()
                }

            // 居中弹窗主体
            弹窗内容
                .frame(width: 弹窗宽度)
                .frame(maxHeight: 最大高度)
                .background(Color.卡片背景)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.2), radius: 20, y: 4)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
        .animation(.easeOut(duration: 0.25), value: 更新管理器.检测状态)
        .animation(.easeOut(duration: 0.25), value: 下载管理器.下载状态)
    }

    // MARK: - 外部点击处理

    private func 处理外部点击() {
        // 检测中和下载中不允许点击外部关闭
        if case .检测中 = 更新管理器.检测状态 { return }
        if 下载管理器.下载状态 == .下载中 { return }
        关闭回调()
    }

    // MARK: - 弹窗内容

    @ViewBuilder
    private var 弹窗内容: some View {
        switch 下载管理器.下载状态 {
        case .下载中:
            下载中视图
        default:
            switch 更新管理器.检测状态 {
            case .检测中(let 步骤):
                检测中视图(步骤: 步骤)
            case .发现新版本(let 版本):
                发现新版本视图(版本: 版本)
            case .已是最新:
                已是最新视图
            case .检测失败(let 错误):
                检测失败视图(错误: 错误)
            case .空闲:
                EmptyView()
            }
        }
    }

    // MARK: - 检测中视图（紧凑高度）

    private func 检测中视图(步骤: 检测步骤文本) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            // 蓝色圆形加载动画
            ZStack {
                Circle()
                    .fill(Color.主题色.opacity(0.15))
                    .frame(width: 48, height: 48)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                    .scaleEffect(1.0)
            }

            Text("正在检测更新")
                .font(.system(size: 16, weight: .semibold))

            Text(步骤.rawValue)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer(minLength: 0)
        }
        .frame(height: 70)
        .padding(.horizontal, 24)
    }

    // MARK: - 发现新版本视图（自适应高度，可滚动）

    private func 发现新版本视图(版本: 版本信息模型) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    // 顶部下载图标
                    ZStack {
                        Circle()
                            .fill(Color.主题色.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.主题色)
                    }
                    .padding(.top, 24)

                    // 标题
                    Text("发现新版本")
                        .font(.system(size: 20, weight: .bold))

                    // 版本号
                    Text("v\(更新管理器.当前版本号) → v\(版本.最新版本)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.主题色)

                    // 发布时间
                    Text("发布时间：\(版本.发布日期)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    // 信息卡片
                    VStack(alignment: .leading, spacing: 10) {
                        Text("自动构建发布")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.bottom, 4)

                        信息行(标签: "版本", 值: "v\(版本.最新版本)")
                        信息行(标签: "构建环境", 值: 版本.构建环境)
                        信息行(标签: "最低支持", 值: 版本.最低iOS版本)
                        信息行(标签: "产物", 值: 版本.产物描述)
                        信息行(标签: "文件名", 值: 版本.产物文件名)

                        Divider()

                        Text("本 Release 由 GitHub Actions 自动构建发布，每次推送 main 分支自动更新。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.页面背景)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // 更新说明
                    if !版本.更新说明.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("更新说明")
                                .font(.system(size: 14, weight: .semibold))
                            Text(版本.更新说明)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 16)
            }

            // 底部按钮区（固定不滚动）
            VStack(spacing: 12) {
                // 下载更新按钮
                Button {
                    开始下载(版本: 版本)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                        Text("下载更新")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.主题色)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)

                // 查看更新详情
                Button {
                    if let url = URL(string: 版本.详情地址) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("查看更新详情")
                        .font(.system(size: 14))
                        .foregroundColor(.主题色)
                }
                .buttonStyle(PlainButtonStyle())

                // 底部选项
                HStack(spacing: 24) {
                    Button {
                        更新管理器.忽略当前版本(版本.最新版本)
                    } label: {
                        Text("忽略此版本")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("|")
                        .foregroundColor(.分割线)

                    Button {
                        更新管理器.稍后提醒()
                    } label: {
                        Text("稍后提醒")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - 已是最新视图（固定高度220pt）

    private var 已是最新视图: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            // 成功图标
            ZStack {
                Circle()
                    .fill(Color.成功色.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.成功色)
            }

            Text("0")
                .font(.system(size: 18, weight: .semibold))

            Text("当前 v\(更新管理器.当前版本号) 已是最新稳定版本")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Button {
                关闭回调()
            } label: {
                Text("关闭")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.主题色)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 40)

            Spacer(minLength: 0)
        }
        .frame(height: 70)
        .padding(.horizontal, 24)
    }

    // MARK: - 检测失败视图（固定高度240pt）

    private func 检测失败视图(错误: String) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            // 错误图标
            ZStack {
                Circle()
                    .fill(Color.危险色.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.危险色)
            }

            Text("检测失败")
                .font(.system(size: 18, weight: .semibold))

            Text(错误)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    关闭回调()
                } label: {
                    Text("关闭")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.页面背景)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    更新管理器.开始检测(静默模式: false)
                } label: {
                    Text("重试")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.主题色)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 0)
        }
        .frame(height: 70)
        .padding(.horizontal, 24)
    }

    // MARK: - 下载中视图（固定高度260pt）

    private var 下载中视图: some View {
        VStack(spacing: 0) {
            Text("正在下载更新")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 24)
                .padding(.bottom, 16)

            下载进度视图(下载管理器: 下载管理器) {
                下载管理器.取消下载()
            }

            Spacer(minLength: 0)
        }
        .frame(height: 70)
        .padding(.horizontal, 24)
    }

    // MARK: - 信息行组件

    private func 信息行(标签: String, 值: String) -> some View {
        HStack(alignment: .top) {
            Text(标签)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(值)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    // MARK: - 开始下载

    private func 开始下载(版本: 版本信息模型) {
        下载管理器.开始下载(下载地址: 版本.下载地址) { 临时文件URL in
            guard let url = 临时文件URL else { return }
            // 下载完成后关闭弹窗，弹出系统分享面板
            关闭回调()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                下载管理器.弹出分享面板(文件URL: url)
            }
        }
    }
}

// MARK: - 预览

#Preview {
    AppUpdateAlert(
        更新管理器: AppUpdateManager.共享,
        下载管理器: AppDownloadManager.共享
    ) {}
}
