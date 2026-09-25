//
//  运行模式选择面板.swift
//  NewVPN
//
//  顶部下拉运行模式选择面板
//  触发方式：右下角设置图标长按
//  面板内显示三个运行模式：规则分流、全局代理、全局直连
//  MitM、HTTP 抓包功能预留后续开发
//

import SwiftUI

// MARK: - 运行模式选择面板覆盖层

/// 运行模式选择面板覆盖层修饰符
struct 运行模式面板覆盖层: ViewModifier {
    /// 绑定是否显示面板
    @Binding var 显示面板: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            // 半透明灰色遮罩 + 面板
            if 显示面板 {
                运行模式面板内容(关闭: { 显示面板 = false })
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 动画常量.标准), value: 显示面板)
    }
}

// MARK: - 面板内容

/// 运行模式选择面板内容
private struct 运行模式面板内容: View {
    /// 关闭回调
    let 关闭: () -> Void
    /// 全局状态
    @EnvironmentObject private var 状态: AppState
    /// 隧道管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器

    /// 面板高度（基于截图测量：约占屏幕 26%）
    private let 面板高度: CGFloat = UIScreen.main.bounds.height * 0.26
    /// 圆形按钮直径（基于截图测量：约屏宽 15.8%）
    private let 按钮直径: CGFloat = UIScreen.main.bounds.width * 0.158
    /// 运行模式按钮间距
    private let 按钮间距: CGFloat = 间距常量.宽松

    var body: some View {
        ZStack(alignment: .top) {
            // 半透明灰色遮罩（点击非功能区关闭）
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { 关闭() }

            // 顶部下拉面板
            VStack(spacing: 间距常量.标准) {
                // 面板顶部拖拽指示条
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.分割线)
                    .frame(width: 36, height: 4)
                    .padding(.top, 间距常量.紧凑)

                // 面板标题
                Text("运行模式")
                    .font(字体层级.卡片标题)
                    .foregroundColor(.primary)

                // 三个模式按钮（水平排列）
                HStack(spacing: 按钮间距) {
                    ForEach(隧道运行模式.allCases, id: \.self) { 模式 in
                        模式按钮(模式: 模式,
                                选中: 隧道管理.配置.运行模式 == 模式,
                                直径: 按钮直径) {
                            切换运行模式(模式)
                        }
                    }
                }
                .padding(.horizontal, 间距常量.标准)

                // 当前模式描述
                Text(隧道管理.配置.运行模式.描述)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 间距常量.宽松)
                    .padding(.bottom, 间距常量.标准)

                // 预留功能提示（MitM、HTTP 抓包后续开发）
                HStack(spacing: 间距常量.中等) {
                    预留功能按钮(标题: "MitM", 图标: "key", 颜色: .成功色)
                    预留功能按钮(标题: "重写", 图标: "pencil.tip", 颜色: .粉色)
                    预留功能按钮(标题: "HTTP 抓取", 图标: "arrow.down.doc", 颜色: .紫色)
                }
                .padding(.bottom, 间距常量.标准)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 圆角常量.大)
                    .fill(Color.卡片背景)
            )
            .padding(.horizontal, 间距常量.标准)
            .padding(.top, 0)
        }
    }

    /// 切换运行模式
    private func 切换运行模式(_ 新模式: 隧道运行模式) {
        隧道管理.配置.运行模式 = 新模式
        隧道管理.保存运行模式偏好()
        // 如果隧道已连接，需要重新加载配置
        if 隧道管理.当前状态.是否活动 {
            隧道管理.重新加载配置()
        }
        关闭()
    }
}

// MARK: - 模式按钮

/// 单个运行模式按钮（圆形图标 + 文字）
private struct 模式按钮: View {
    /// 模式类型
    let 模式: 隧道运行模式
    /// 是否选中
    let 选中: Bool
    /// 按钮直径
    let 直径: CGFloat
    /// 点击回调
    let 操作: () -> Void

    var body: some View {
        Button(action: 操作) {
            VStack(spacing: 间距常量.紧凑) {
                // 圆形图标
                ZStack {
                    Circle()
                        .fill(选中 ? Color.主题色 : Color.页面背景)
                        .frame(width: 直径, height: 直径)
                        .overlay(
                            Circle()
                                .stroke(选中 ? Color.主题色 : Color.分割线, lineWidth: 选中 ? 2 : 1)
                        )

                    Image(systemName: 模式图标)
                        .font(.system(size: 直径 * 0.38, weight: .semibold))
                        .foregroundColor(选中 ? .white : .次要文字)
                }

                // 模式名称
                Text(模式.rawValue)
                    .font(字体层级.辅助说明)
                    .foregroundColor(选中 ? .主题色 : .primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 模式对应图标
    private var 模式图标: String {
        switch 模式 {
        case .规则分流: return "arrow.triangle.branch"
        case .全局代理: return "globe"
        case .全局直连: return "point.bottomleft.forward.to.arrow.trianglehead.topright"
        }
    }
}

// MARK: - 预留功能按钮

/// 预留功能按钮（MitM、重写、HTTP 抓取，后续开发）
private struct 预留功能按钮: View {
    /// 标题
    let 标题: String
    /// 图标
    let 图标: String
    /// 主题颜色
    let 颜色: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: 图标)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.次要文字)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.页面背景)
                )

            Text(标题)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.次要文字)

            Text("待开发")
                .font(.system(size: 8, weight: .regular))
                .foregroundColor(.次要文字.opacity(0.6))
        }
        .opacity(0.5)
    }
}

// MARK: - 颜色扩展

private extension Color {
    /// 粉色（重写功能）
    static var 粉色: Color {
        Color(light: Color(red: 1.0, green: 0.45, blue: 0.65),
              dark: Color(red: 1.0, green: 0.55, blue: 0.70))
    }

    /// 紫色（HTTP 抓取功能）
    static var 紫色: Color {
        Color(light: Color(red: 0.65, green: 0.50, blue: 0.85),
              dark: Color(red: 0.70, green: 0.55, blue: 0.90))
    }
}

// MARK: - 视图扩展

extension View {
    /// 添加运行模式选择面板覆盖层
    func 运行模式面板(显示: Binding<Bool>) -> some View {
        self.modifier(运行模式面板覆盖层(显示面板: 显示))
    }
}
