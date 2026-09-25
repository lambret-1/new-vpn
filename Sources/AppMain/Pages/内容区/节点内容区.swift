//
//  节点内容区.swift
//  NewVPN
//
//  节点卡片对应的内容区：分组列表 + 展开节点详情
//  集成真实测速功能：单节点测速、分组批量测速
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
            // 批量测速进度条
            批量测速进度条 {
                测速管理器.取消测速()
            }

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
                LazyVStack(spacing: 10) {
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

            // 展开的节点列表
            if 分组.是否展开 {
                VStack(spacing: 8) {
                    ForEach(分组.节点列表) { 节点 in
                        节点行视图(节点: 节点)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
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
}

// MARK: - 节点行视图

/// 单个节点行视图
private struct 节点行视图: View {
    /// 节点数据
    let 节点: 节点模型
    /// 全局状态
    @EnvironmentObject private var 状态: AppState
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    /// 是否为当前选中节点
    private var 是否选中: Bool {
        状态.当前节点ID == 节点.id
    }

    var body: some View {
        HStack(spacing: 10) {
            // 选中指示器
            if 是否选中 {
                Capsule()
                    .fill(Color.主题色)
                    .frame(width: 3, height: 28)
            }

            // 左侧：协议 + 名称 + 标签
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(节点.协议.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(是否选中 ? Color.主题色 : Color.主题色.opacity(0.7))
                        .cornerRadius(4)
                    Text(节点.地址)
                        .font(.system(size: 14, weight: 是否选中 ? .medium : .regular))
                        .lineLimit(1)
                }
                Text(节点.标签.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 右侧：测速按钮 + 测速结果
            HStack(spacing: 8) {
                // 选中标记
                if 是否选中 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.主题色)
                }

                // 测速结果展示
                测速结果展示(节点ID: 节点.id)

                // 测速按钮
                测速按钮(节点ID: 节点.id) {
                    测速管理器.测速节点(节点) { _ in }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(是否选中 ? Color.主题色.opacity(0.12) : Color.卡片背景)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(是否选中 ? Color.主题色.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            选中节点()
        }
    }

    /// 选中节点
    private func 选中节点() {
        withAnimation(.easeInOut(duration: 0.2)) {
            状态.当前节点ID = 节点.id
        }
    }
}

// MARK: - 预览

#Preview {
    节点内容区()
        .environmentObject(AppState.共享)
        .environmentObject(测速管理器.共享)
        .background(Color.页面背景)
}
