//
//  UIConst.swift
//  NewVPN
//
//  全局设计令牌：颜色、字体、间距、圆角、动画时长
//  所有页面禁止硬编码样式，必须引用本文件常量
//

import SwiftUI

// MARK: - 间距常量（基于 8pt 网格）

enum 间距常量 {
    /// 紧凑间距：图标与文字之间
    static let 紧凑: CGFloat = 8
    /// 中等间距：表单行间距
    static let 中等: CGFloat = 12
    /// 标准间距：卡片内边距
    static let 标准: CGFloat = 16
    /// 宽松间距：卡片之间
    static let 宽松: CGFloat = 24
    /// 表单行高度
    static let 表单行高: CGFloat = 44
    /// 按钮高度
    static let 按钮高: CGFloat = 44
}

// MARK: - 圆角常量

enum 圆角常量 {
    /// 小圆角：标签、徽章
    static let 小: CGFloat = 6
    /// 标准圆角：卡片、输入框、按钮
    static let 标准: CGFloat = 10
    /// 大圆角：弹窗、大卡片
    static let 大: CGFloat = 16
}

// MARK: - 语义化颜色（程序化定义，自动适配浅色/深色模式）

extension Color {
    /// 主色：主按钮、高亮、激活状态
    static var 主题色: Color {
        Color(light: Color(red: 0.0, green: 0.48, blue: 1.0),
              dark: Color(red: 0.33, green: 0.62, blue: 1.0))
    }

    /// 次要文字、辅助说明
    static var 次要文字: Color {
        Color(light: Color(red: 0.55, green: 0.55, blue: 0.57),
              dark: Color(red: 0.70, green: 0.70, blue: 0.72))
    }

    /// 成功：运行正常、连接成功
    static var 成功色: Color {
        Color(light: Color(red: 0.20, green: 0.78, blue: 0.35),
              dark: Color(red: 0.30, green: 0.85, blue: 0.45))
    }

    /// 浅绿色背景：测速按钮等操作背景
    static var 浅绿色背景: Color {
        Color(light: Color(red: 0.85, green: 0.95, blue: 0.86),
              dark: Color(red: 0.15, green: 0.30, blue: 0.18))
    }

    /// 绿色文字：浅绿色背景上的文字
    static var 绿色文字: Color {
        Color(light: Color(red: 0.15, green: 0.55, blue: 0.25),
              dark: Color(red: 0.50, green: 0.90, blue: 0.60))
    }

    /// 测速绿色：右滑测速按钮背景（小火箭风格）
    static var 测速绿色: Color {
        Color(light: Color(red: 0.20, green: 0.78, blue: 0.35),
              dark: Color(red: 0.30, green: 0.85, blue: 0.45))
    }

    /// 警告：即将过期、需要注意
    static var 警告色: Color {
        Color(light: Color(red: 1.0, green: 0.62, blue: 0.0),
              dark: Color(red: 1.0, green: 0.72, blue: 0.20))
    }

    /// 危险：错误、断开、删除
    static var 危险色: Color {
        Color(light: Color(red: 1.0, green: 0.23, blue: 0.19),
              dark: Color(red: 1.0, green: 0.35, blue: 0.31))
    }

    /// 页面背景
    static var 页面背景: Color {
        Color(light: Color(red: 0.95, green: 0.95, blue: 0.97),
              dark: Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    /// 卡片背景
    static var 卡片背景: Color {
        Color(light: Color.white,
              dark: Color(red: 0.12, green: 0.12, blue: 0.13))
    }

    /// 分割线
    static var 分割线: Color {
        Color(light: Color(red: 0.88, green: 0.88, blue: 0.90),
              dark: Color(red: 0.22, green: 0.22, blue: 0.23))
    }
}

// MARK: - 颜色深浅模式适配工具

extension Color {
    /// 根据浅色/深色模式返回对应颜色
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - 字体层级

enum 字体层级 {
    /// 页面大标题：28pt 粗体
    static let 大标题 = Font.system(size: 28, weight: .bold)
    /// 卡片标题：17pt 半粗体
    static let 卡片标题 = Font.system(size: 17, weight: .semibold)
    /// 正文：14pt 常规
    static let 正文 = Font.system(size: 14, weight: .regular)
    /// 辅助说明：12pt 常规
    static let 辅助说明 = Font.system(size: 12, weight: .regular)
    /// 数据指标：20pt 粗体
    static let 数据指标 = Font.system(size: 20, weight: .bold)
    /// 按钮文字：16pt 半粗体
    static let 按钮文字 = Font.system(size: 16, weight: .semibold)
}

// MARK: - 动画时长

enum 动画常量 {
    /// 快速动画：状态切换、Toast
    static let 快速: Double = 0.2
    /// 标准动画：卡片折叠、页面过渡
    static let 标准: Double = 0.3
}

// MARK: - 全局常量

enum 全局常量 {
    /// App Group 共享目录标识
    static let App组标识 = "group.com.newvpn.app"
    /// 隧道扩展 Bundle 标识
    static let 隧道扩展标识 = "com.newvpn.app.tunnel"
    /// GitHub 仓库地址
    static let 仓库地址 = "https://github.com/lambret-1/new-vpn"
    /// 日志环形缓冲区最大条数
    static let 日志缓冲条数 = 2000
    /// 抓包会话最大保存数量
    static let 抓包最大会话数 = 500
    /// 网络活动最大连接数
    static let 网络活动最大连接数 = 300
}
