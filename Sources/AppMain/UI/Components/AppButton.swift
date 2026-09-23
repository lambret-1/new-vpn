//
//  AppButton.swift
//  NewVPN
//
//  统一按钮组件：三种样式（主要/次要/危险），带加载状态、防重复点击
//

import SwiftUI

/// 按钮样式枚举
enum AppButton样式 {
    /// 主要按钮：实心主题色
    case 主要
    /// 次要按钮：描边
    case 次要
    /// 危险按钮：红色
    case 危险
}

/// 统一按钮组件
struct AppButton: View {
    /// 按钮文字
    let 文字: String
    /// 按钮样式
    let 样式: AppButton样式
    /// 是否显示加载状态
    let 加载中: Bool
    /// 是否占满整行宽度
    let 全宽: Bool
    /// 点击回调
    private let 动作: () -> Void

    /// 防重复点击时间窗口
    @State private var 已点击: Bool = false

    /// 初始化按钮
    /// - Parameters:
    ///   - 文字: 按钮显示文字
    ///   - 样式: 按钮样式，默认为主要
    ///   - 加载中: 是否显示加载指示器
    ///   - 全宽: 是否占满父容器宽度
    ///   - 动作: 点击执行的闭包
    init(_ 文字: String,
         样式: AppButton样式 = .主要,
         加载中: Bool = false,
         全宽: Bool = true,
         动作: @escaping () -> Void) {
        self.文字 = 文字
        self.样式 = 样式
        self.加载中 = 加载中
        self.全宽 = 全宽
        self.动作 = 动作
    }

    var body: some View {
        Button {
            按钮点击()
        } label: {
            HStack(spacing: 间距常量.紧凑) {
                if 加载中 {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(前景颜色)
                        .scaleEffect(0.8)
                }

                Text(加载中 ? "处理中…" : 文字)
                    .font(字体层级.按钮文字)
            }
            .foregroundColor(前景颜色)
            .frame(maxWidth: 全宽 ? .infinity : nil)
            .frame(height: 间距常量.按钮高)
            .background(背景颜色)
            .clipShape(RoundedRectangle(cornerRadius: 圆角常量.标准))
            .overlay(
                RoundedRectangle(cornerRadius: 圆角常量.标准)
                    .stroke(描边颜色, lineWidth: 样式 == .次要 ? 1 : 0)
            )
        }
        .disabled(加载中 || 已点击)
        .opacity(加载中 || 已点击 ? 0.7 : 1.0)
        .buttonStyle(按压按钮样式())
    }

    /// 按钮点击处理（防抖）
    private func 按钮点击() {
        guard !已点击, !加载中 else { return }
        已点击 = true
        动作()

        // 1 秒后恢复可点击状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            已点击 = false
        }
    }

    /// 根据样式返回前景色
    private var 前景颜色: Color {
        switch 样式 {
        case .主要:
            return .white
        case .次要:
            return .主题色
        case .危险:
            return .white
        }
    }

    /// 根据样式返回背景色
    private var 背景颜色: Color {
        switch 样式 {
        case .主要:
            return .主题色
        case .次要:
            return .clear
        case .危险:
            return .危险色
        }
    }

    /// 根据样式返回描边色
    private var 描边颜色: Color {
        switch 样式 {
        case .主要:
            return .clear
        case .次要:
            return .主题色
        case .危险:
            return .clear
        }
    }
}

/// 按压缩放效果样式
private struct 按压按钮样式: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 动画常量.快速), value: configuration.isPressed)
    }
}

// MARK: - 按钮预览

#Preview("按钮样式集合") {
    VStack(spacing: 间距常量.中等) {
        AppButton("启动隧道", 样式: .主要) {}
        AppButton("导出配置", 样式: .次要) {}
        AppButton("删除节点", 样式: .危险) {}
        AppButton("加载中", 样式: .主要, 加载中: true) {}
    }
    .padding()
    .background(Color.页面背景)
}
