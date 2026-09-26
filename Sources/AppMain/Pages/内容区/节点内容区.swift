//
//  节点内容区.swift
//  NewVPN
//
//  节点卡片对应的内容区：分组列表 + 展开节点详情
//  右滑卡片露出测速按钮
//

import SwiftUI

/// 节点内容区视图
struct 节点内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    var body: some View {
        VStack(spacing: 10) {
            if 状态.节点分组列表.isEmpty {
                // 空状态：无节点时提示添加远程订阅
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无节点")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("请在「编辑配置文件」中添加远程订阅并更新")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                // 分组列表（远程订阅导入的节点按订阅名称分组常驻显示）
                VStack(spacing: 10) {
                    ForEach($状态.节点分组列表) { $分组 in
                        分组行视图(分组: $分组)
                    }
                }
                .padding(.horizontal, 15)
            }
        }
    }
}

// MARK: - 分组行视图

/// 节点分组行视图
private struct 分组行视图: View {
    /// 分组数据绑定
    @Binding var 分组: 节点分组模型
    /// 全局状态
    @EnvironmentObject private var 状态: AppState
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    var body: some View {
        VStack(spacing: 0) {
            // 分组标题行
            HStack(spacing: 12) {
                // 左侧测速图标按钮
                Button {
                    执行分组测速()
                } label: {
                    ZStack {
                        if 测速管理器.是否测速中 {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                        } else {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.主题色)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(测速管理器.是否测速中)

                // 分组名称
                Text(分组.名称)
                    .font(.system(size: 15, weight: .medium))

                Spacer()

                // 节点数量 + 展开箭头
                HStack(spacing: 8) {
                    Text("\(分组.节点数量)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Image(systemName: 分组.是否展开 ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.卡片背景)
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    分组.是否展开.toggle()
                }
            }
            .contextMenu {
                Button {
                    复制分组JSON()
                } label: {
                    Label("复制 JSON", systemImage: "doc.on.doc")
                }
                Button {
                    分享分组JSON()
                } label: {
                    Label("分享 JSON", systemImage: "square.and.arrow.up")
                }
            }

            // 展开的节点列表
            if 分组.是否展开 {
                VStack(spacing: 8) {
                    ForEach(分组.节点列表) { 节点 in
                        可滑动节点行视图(节点: 节点)
                            .id(节点.id)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
    }

    /// 执行分组批量测速（完成后按延迟排序）
    private func 执行分组测速() {
        guard !分组.节点列表.isEmpty else { return }

        测速管理器.批量测速(
            分组.节点列表,
            节点更新: { 节点, 结果 in
                // 更新节点测速数据
                if let 索引 = 分组.节点列表.firstIndex(where: { $0.id == 节点.id }) {
                    分组.节点列表[索引].测速数据 = 测速结果(
                        延迟毫秒: 结果.延迟毫秒,
                        抖动毫秒: 结果.抖动毫秒,
                        丢包率: 结果.丢包率,
                        测速时间: 结果.测速时间,
                        成功: 结果.成功
                    )
                }
            },
            全部完成: { _ in
                // 测速完成后按延迟排序（成功的在前，失败的在后）
                DispatchQueue.main.async {
                    分组.节点列表.sort { 节点1, 节点2 in
                        let 成功1 = 节点1.测速数据?.成功 ?? false
                        let 成功2 = 节点2.测速数据?.成功 ?? false
                        if 成功1 != 成功2 {
                            return 成功1 && !成功2
                        }
                        let 延迟1 = 节点1.测速数据?.延迟毫秒 ?? Int.max
                        let 延迟2 = 节点2.测速数据?.延迟毫秒 ?? Int.max
                        return 延迟1 < 延迟2
                    }
                }
            }
        )
    }

    // MARK: - 分组 JSON 导出

    /// 生成分组内所有节点的 sing-box 出站配置 JSON 字符串
    private func 生成分组JSON() -> String {
        let 出站列表 = 分组.节点列表.compactMap { 节点 in
            SingBox配置生成器.共享.节点转换为出站(节点, 标签: 节点.名称)
        }
        let 编码器 = JSONEncoder()
        编码器.keyEncodingStrategy = .convertToSnakeCase
        编码器.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let 数据 = try? 编码器.encode(出站列表) else { return "" }
        return String(data: 数据, encoding: .utf8) ?? ""
    }

    /// 复制分组 JSON 到剪贴板
    private func 复制分组JSON() {
        let json = 生成分组JSON()
        guard !json.isEmpty else { return }
        UIPasteboard.general.string = json
    }

    /// 分享分组 JSON（弹出 iOS 系统分享面板）
    private func 分享分组JSON() {
        let json = 生成分组JSON()
        guard !json.isEmpty else { return }

        let 活动控制器 = UIActivityViewController(
            activityItems: [json],
            applicationActivities: nil
        )

        // 获取最顶层视图控制器
        guard let 窗口 = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              var 顶层控制器 = 窗口.rootViewController else {
            return
        }
        while let 弹出的 = 顶层控制器.presentedViewController {
            顶层控制器 = 弹出的
        }

        // iPad 适配
        if let 弹出控制器 = 活动控制器.popoverPresentationController {
            弹出控制器.sourceView = 顶层控制器.view
            弹出控制器.sourceRect = CGRect(
                x: 顶层控制器.view.bounds.midX,
                y: 顶层控制器.view.bounds.midY,
                width: 0, height: 0
            )
            弹出控制器.permittedArrowDirections = []
        }

        顶层控制器.present(活动控制器, animated: true)
    }
}

// MARK: - 可滑动节点行视图

/// 可滑动节点行视图（右滑露出测速按钮）
private struct 可滑动节点行视图: View {
    /// 节点数据
    let 节点: 节点模型
    /// 全局状态
    @EnvironmentObject private var 状态: AppState
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    /// 滑动偏移量
    @State private var 偏移量: CGFloat = 0
    /// 拖拽起始偏移量
    @State private var 拖拽起始偏移: CGFloat = 0

    /// 展开宽度（测速按钮宽度）
    private let 展开宽度: CGFloat = 70

    /// 是否为当前选中节点
    private var 是否选中: Bool {
        状态.当前节点ID == 节点.id
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // 底层：测速按钮（仅在滑动时显示，避免幻影）
            HStack(spacing: 0) {
                Button {
                    测速管理器.测速节点(节点) { _ in }
                    // 测速后自动收起
                    withAnimation(.easeOut(duration: 0.2)) {
                        偏移量 = 0
                    }
                } label: {
                    VStack(spacing: 4) {
                        if 测速管理器.节点测速状态[节点.id]?.是否测速中 == true {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text("测速")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 展开宽度, height: 60)
                    .background(Color.测速绿色)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .opacity(偏移量 > 5 ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: 偏移量)

            // 上层：节点卡片内容
            节点卡片内容(节点: 节点, 是否选中: 是否选中)
                .offset(x: 偏移量)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { 值 in
                            if 拖拽起始偏移 == 0 {
                                拖拽起始偏移 = 偏移量
                            }
                            let 目标偏移 = 拖拽起始偏移 + 值.translation.width
                            // 限制滑动范围，添加阻尼效果
                            if 目标偏移 < 0 {
                                偏移量 = 目标偏移 * 0.3
                            } else if 目标偏移 > 展开宽度 {
                                偏移量 = 展开宽度 + (目标偏移 - 展开宽度) * 0.3
                            } else {
                                偏移量 = 目标偏移
                            }
                        }
                        .onEnded { 值 in
                            let 最终速度 = 值.predictedEndTranslation.width - 值.translation.width
                            withAnimation(.easeOut(duration: 0.25)) {
                                if 偏移量 > 展开宽度 / 2 || 最终速度 > 50 {
                                    偏移量 = 展开宽度
                                } else {
                                    偏移量 = 0
                                }
                            }
                            拖拽起始偏移 = 0
                        }
                )
                .onTapGesture {
                    if 偏移量 > 0 {
                        // 已展开时点击收起
                        withAnimation(.easeOut(duration: 0.2)) {
                            偏移量 = 0
                        }
                    } else {
                        选中节点()
                    }
                }
        }
        .frame(height: 60)
        .clipped()
    }

    /// 选中节点
    private func 选中节点() {
        withAnimation(.easeInOut(duration: 0.2)) {
            状态.保存选中节点(节点)
        }
    }
}

// MARK: - 节点卡片内容

/// 节点卡片内容
private struct 节点卡片内容: View {
    /// 节点数据
    let 节点: 节点模型
    /// 是否选中
    let 是否选中: Bool
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    var body: some View {
        HStack(spacing: 10) {
            // 选中指示器
            if 是否选中 {
                Capsule()
                    .fill(Color.主题色)
                    .frame(width: 3, height: 28)
            }

            // 左侧：协议 + 节点名称(tag) + 地址/标签
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(节点.协议.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(是否选中 ? Color.主题色 : Color.主题色.opacity(0.7))
                        .cornerRadius(4)
                    Text(节点.名称)
                        .font(.system(size: 14, weight: 是否选中 ? .medium : .regular))
                        .lineLimit(1)
                }
                Text("\(节点.地址):\(节点.端口) · \(节点.标签.joined(separator: " · "))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧：选中标记 + 测速结果
            HStack(spacing: 8) {
                // 选中标记
                if 是否选中 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.主题色)
                }

                // 测速结果展示
                测速结果展示(节点ID: 节点.id)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 60)
        .background(是否选中 ? Color.主题色.opacity(0.12) : Color.卡片背景)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(是否选中 ? Color.主题色.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - 预览

#Preview {
    节点内容区()
        .environmentObject(AppState.共享)
        .environmentObject(测速管理器.共享)
        .background(Color.页面背景)
}
