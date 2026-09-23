//
//  AppState.swift
//  NewVPN
//
//  全局应用状态：隧道状态、当前页面、主题、各模块 Mock 数据
//  一期使用 Mock 数据，后续替换为真实业务模块数据源
//

import SwiftUI
import Foundation

// MARK: - 隧道状态枚举

/// VPN 隧道运行状态
enum 隧道状态枚举: Equatable {
    /// 已断开
    case 已断开
    /// 准备中
    case 准备中
    /// 连接中
    case 连接中
    /// 运行中
    case 运行中
    /// 重连中
    case 重连中
    /// 错误
    case 错误(String)

    /// 状态显示文字
    var 显示文字: String {
        switch self {
        case .已断开: return "已断开"
        case .准备中: return "准备中"
        case .连接中: return "连接中"
        case .运行中: return "运行中"
        case .重连中: return "重连中"
        case .错误: return "连接错误"
        }
    }

    /// 是否处于活跃状态（非断开/错误）
    var 是否活跃: Bool {
        switch self {
        case .已断开, .错误:
            return false
        default:
            return true
        }
    }
}

// MARK: - 页面类型枚举

/// 侧边导航页面类型
enum 页面类型: String, CaseIterable, Identifiable {
    case 首页
    case 节点
    case 订阅
    case 测速
    case 分流
    case MITM重写
    case 抓包
    case 网络活动
    case 脚本
    case 日志
    case 设置
    case 关于

    var id: String { rawValue }

    /// 页面对应 SF Symbol 图标
    var 图标: String {
        switch self {
        case .首页: return "house"
        case .节点: return "list.bullet"
        case .订阅: return "arrow.down.circle"
        case .测速: return "gauge"
        case .分流: return "arrow.triangle.branch"
        case .MITM重写: return "pencil.and.outline"
        case .抓包: return "doc.text.magnifyingglass"
        case .网络活动: return "antenna.radiowaves.left.and.right"
        case .脚本: return "curlybraces"
        case .日志: return "ladybug"
        case .设置: return "gearshape"
        case .关于: return "info.circle"
        }
    }

    /// 页面标题
    var 标题: String { rawValue }
}

// MARK: - 主题枚举

/// 应用外观主题
enum 应用主题: String, CaseIterable {
    case 跟随系统
    case 浅色
    case 深色
}

// MARK: - 顶部功能卡片类型

/// 顶部横向滑动功能卡片类型
enum 顶部卡片类型: String, CaseIterable, Identifiable {
    case 节点
    case 网络活动
    case 重写规则
    case 分流规则
    case 日志

    var id: String { rawValue }

    /// 卡片标题
    var 标题: String { rawValue }

    /// 卡片背景色（十六进制）
    var 背景色: Color {
        switch self {
        case .节点: return Color(red: 0.24, green: 0.77, blue: 0.82)
        case .网络活动: return Color(red: 0.91, green: 0.36, blue: 0.20)
        case .重写规则: return Color(red: 0.99, green: 0.33, blue: 0.63)
        case .分流规则: return Color(red: 0.35, green: 0.78, blue: 0.98)
        case .日志: return Color(red: 0.42, green: 0.42, blue: 0.44)
        }
    }

    /// 卡片 SF Symbol 图标
    var 图标: String {
        switch self {
        case .节点: return "server.rack"
        case .网络活动: return "list.clipboard"
        case .重写规则: return "pencil"
        case .分流规则: return "arrow.triangle.branch"
        case .日志: return "doc.text"
        }
    }
}

// MARK: - 底部工具栏弹窗类型

/// 底部工具栏弹出的功能页面类型
enum 底部弹窗类型: String, CaseIterable, Identifiable {
    case 编辑配置文件
    case DNS记录
    case JS脚本记录
    case TCPUDP流量
    case 设置

    var id: String { rawValue }

    /// 弹窗标题
    var 标题: String { rawValue }

    /// 工具栏 SF Symbol 图标
    var 图标: String {
        switch self {
        case .编辑配置文件: return "square.and.pencil"
        case .DNS记录: return "magnifyingglass"
        case .JS脚本记录: return "curlybraces"
        case .TCPUDP流量: return "chart.bar.xaxis"
        case .设置: return "gearshape"
        }
    }
}

// MARK: - 节点分组模型

/// 节点分组数据模型
struct 节点分组模型: Identifiable {
    let id = UUID()
    /// 分组名称
    var 名称: String
    /// 分组内节点列表
    var 节点列表: [节点模型]
    /// 是否展开
    var 是否展开: Bool
    /// 是否正在测速
    var 测速中: Bool

    /// 节点数量
    var 节点数量: Int { 节点列表.count }
}

// MARK: - 全局应用状态

/// 全局应用状态对象，管理隧道状态、页面导航、Mock 数据
final class AppState: ObservableObject {
    /// 全局单例
    static let 共享 = AppState()

    // MARK: 导航状态

    /// 当前选中页面
    @Published var 当前页面: 页面类型 = .首页
    /// 当前选中顶部卡片
    @Published var 当前顶部卡片: 顶部卡片类型 = .节点
    /// 当前底部弹窗（nil 表示未弹出）
    @Published var 当前底部弹窗: 底部弹窗类型?

    // MARK: 隧道状态

    /// 隧道运行状态
    @Published var 隧道状态: 隧道状态枚举 = .已断开
    /// 当前选中节点 ID
    @Published var 当前节点ID: UUID?
    /// 隧道运行时长（秒）
    @Published var 运行时长秒: Int = 0
    /// 上行速率（字节/秒）
    @Published var 上行速率: Int64 = 0
    /// 下行速率（字节/秒）
    @Published var 下行速率: Int64 = 0
    /// 累计上行流量（字节）
    @Published var 累计上行: Int64 = 0
    /// 累计下行流量（字节）
    @Published var 累计下行: Int64 = 0

    // MARK: 外观设置

    /// 应用主题
    @Published var 主题: 应用主题 = .跟随系统

    // MARK: Mock 数据集合

    /// 节点列表
    @Published var 节点列表: [节点模型] = []
    /// 订阅列表
    @Published var 订阅列表: [订阅模型] = []
    /// 分流规则列表
    @Published var 分流规则列表: [分流规则模型] = []
    /// 重写规则列表
    @Published var 重写规则列表: [重写规则模型] = []
    /// 脚本列表
    @Published var 脚本列表: [脚本模型] = []
    /// 日志列表
    @Published var 日志列表: [日志模型] = []
    /// 抓包会话列表
    @Published var 抓包列表: [抓包会话模型] = []
    /// 网络连接列表
    @Published var 网络连接列表: [网络连接模型] = []
    /// 节点分组列表（按分组名聚合）
    @Published var 节点分组列表: [节点分组模型] = []
    /// 远程订阅列表
    @Published var 远程订阅列表: [远程订阅模型] = []

    /// Mock 数据刷新定时器
    private var 模拟定时器: Timer?

    /// 私有初始化，加载 Mock 数据
    private init() {
        加载模拟数据()
        加载订阅列表()
    }

    // MARK: - 当前节点便捷属性

    /// 当前选中的节点对象
    var 当前节点: 节点模型? {
        guard let id = 当前节点ID else { return nil }
        return 节点列表.first { $0.id == id }
    }

    // MARK: - 隧道启停（Mock 状态机）

    /// 切换隧道启停状态
    func 切换隧道() {
        switch 隧道状态 {
        case .已断开, .错误:
            启动隧道模拟()
        default:
            停止隧道模拟()
        }
    }

    /// 模拟启动隧道流程
    private func 启动隧道模拟() {
        guard 当前节点 != nil || !节点列表.isEmpty else {
            隧道状态 = .错误("未选择节点")
            return
        }

        if 当前节点ID == nil {
            当前节点ID = 节点列表.first?.id
        }

        隧道状态 = .准备中

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.隧道状态 = .连接中
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.隧道状态 = .运行中
            self?.开始流量模拟()
        }
    }

    /// 模拟停止隧道
    private func 停止隧道模拟() {
        模拟定时器?.invalidate()
        模拟定时器 = nil
        隧道状态 = .已断开
        上行速率 = 0
        下行速率 = 0
        运行时长秒 = 0
    }

    /// 模拟实时流量数据
    private func 开始流量模拟() {
        模拟定时器?.invalidate()
        模拟定时器 = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let 上 = Int64.random(in: 50_000...2_500_000)
            let 下 = Int64.random(in: 200_000...9_000_000)

            self.上行速率 = 上
            self.下行速率 = 下
            self.累计上行 += 上
            self.累计下行 += 下
            self.运行时长秒 += 1
        }
    }

    // MARK: - 加载 Mock 数据

    /// 加载全部模拟数据
    private func 加载模拟数据() {
        节点列表 = Mock数据.生成节点()
        订阅列表 = Mock数据.生成订阅()
        分流规则列表 = Mock数据.生成分流规则()
        重写规则列表 = Mock数据.生成重写规则()
        脚本列表 = Mock数据.生成脚本()
        日志列表 = Mock数据.生成日志()
        抓包列表 = Mock数据.生成抓包会话()
        网络连接列表 = Mock数据.生成网络连接()
        节点分组列表 = Mock数据.生成节点分组(节点列表: 节点列表)
        当前节点ID = 节点列表.first?.id
    }

    // MARK: - 分组测速

    /// 对指定分组内所有节点执行模拟测速
    func 执行分组测速(分组ID: UUID) {
        guard let 索引 = 节点分组列表.firstIndex(where: { $0.id == 分组ID }) else { return }
        节点分组列表[索引].测速中 = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            // 模拟更新每个节点的测速数据
            for (节点索引, _) in self.节点分组列表[索引].节点列表.enumerated() {
                let 延迟 = Int.random(in: 50...300)
                let 下载 = Double.random(in: 50...300)
                self.节点分组列表[索引].节点列表[节点索引].测速数据 = 测速结果(
                    延迟毫秒: 延迟,
                    抖动毫秒: Int.random(in: 1...20),
                    丢包率: Double.random(in: 0...2),
                    下载速率: 下载,
                    上传速率: Double.random(in: 10...80),
                    测速时间: Date(),
                    成功: true
                )
            }
            self.节点分组列表[索引].测速中 = false
        }
    }

    // MARK: - 订阅管理

    /// 从本地存储加载订阅列表
    private func 加载订阅列表() {
        远程订阅列表 = 订阅存储.共享.读取订阅列表()
    }

    /// 添加新订阅
    func 添加订阅(_ 订阅: 远程订阅模型) {
        远程订阅列表.append(订阅)
        保存订阅列表()
    }

    /// 删除订阅
    func 删除订阅(_ 订阅: 远程订阅模型) {
        远程订阅列表.removeAll { $0.id == 订阅.id }
        订阅下载服务.共享.删除本地配置(订阅ID: 订阅.id)
        保存订阅列表()
    }

    /// 保存订阅列表到本地
    func 保存订阅列表() {
        订阅存储.共享.保存订阅列表(远程订阅列表)
    }

    /// 更新指定订阅（下载并自动解析节点）
    func 更新订阅(订阅ID: UUID, 完成: @escaping (Result<订阅下载结果, 订阅下载错误>) -> Void) {
        guard let 索引 = 远程订阅列表.firstIndex(where: { $0.id == 订阅ID }) else { return }
        let 订阅 = 远程订阅列表[索引]

        远程订阅列表[索引].上次状态 = .更新中

        订阅下载服务.共享.下载并解析(订阅) { [weak self] 结果 in
            guard let self = self else { return }

            switch 结果 {
            case .success(let 解析结果):
                self.远程订阅列表[索引].上次状态 = .成功
                self.远程订阅列表[索引].上次更新时间 = Date()
                // 将解析出的节点添加到节点列表
                self.合并解析节点(解析结果.节点列表, 订阅名称: 订阅.名称)
            case .failure(let 错误):
                self.远程订阅列表[索引].上次状态 = .失败(错误.localizedDescription)
            }

            self.保存订阅列表()
            // 转换为下载结果回调
            if case .success = 结果 {
                完成(.success(订阅下载结果(配置内容: "", 下载时间: Date(), 文件大小: 0)))
            } else if case .failure(let 错误) = 结果 {
                完成(.failure(错误))
            }
        }
    }

    /// 合并解析出的节点到节点列表
    private func 合并解析节点(_ 解析节点: [解析节点模型], 订阅名称: String) {
        let 新节点 = 解析节点.map { 解析节点 -> 节点模型 in
            var 节点 = 解析节点.转换为节点模型()
            节点.分组 = 订阅名称
            节点.来源类型 = "订阅导入"
            return 节点
        }

        // 移除该订阅旧的节点，添加新节点
        节点列表.removeAll { $0.来源类型 == "订阅导入" && $0.分组 == 订阅名称 }
        节点列表.append(contentsOf: 新节点)

        // 重新生成分组
        节点分组列表 = Mock数据.生成节点分组(节点列表: 节点列表)
    }

    /// 获取指定订阅解析出的节点
    func 获取订阅节点(订阅ID: UUID) -> [节点模型] {
        guard let 订阅 = 远程订阅列表.first(where: { $0.id == 订阅ID }) else { return [] }
        return 节点列表.filter { $0.分组 == 订阅.名称 && $0.来源类型 == "订阅导入" }
    }

    /// 批量更新所有启用自动更新的订阅
    func 批量更新自动更新订阅() {
        for 订阅 in 远程订阅列表 where 订阅.自动更新启用 {
            更新订阅(订阅ID: 订阅.id) { _ in }
        }
    }
}

// MARK: - Mock 数据生成器

/// Mock 数据生成工具，集中管理所有假数据
enum Mock数据 {
    /// 生成模拟节点列表
    static func 生成节点() -> [节点模型] {
        [
            节点模型(
                id: UUID(),
                名称: "香港-01",
                协议: .vless,
                地址: "hk01.example.com",
                端口: 443,
                用户标识: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                传输类型: .ws,
                启用TLS: true,
                服务器名称: "hk01.example.com",
                分组: "香港",
                标签: ["香港", "直连"],
                备注: "主力节点",
                来源类型: "订阅导入",
                测速数据: 测速结果(延迟毫秒: 82, 抖动毫秒: 5, 丢包率: 0,
                              下载速率: 230.5, 上传速率: 65.2,
                              测速时间: Date(), 成功: true)
            ),
            节点模型(
                id: UUID(),
                名称: "香港-02",
                协议: .vmess,
                地址: "hk02.example.com",
                端口: 443,
                用户标识: "b2c3d4e5-f6a7-8901-bcde-f12345678901",
                传输类型: .tcp,
                启用TLS: true,
                服务器名称: "hk02.example.com",
                分组: "香港",
                标签: ["香港"],
                备注: nil,
                来源类型: "订阅导入",
                测速数据: 测速结果(延迟毫秒: 95, 抖动毫秒: 8, 丢包率: 0.5,
                              下载速率: 180.0, 上传速率: 50.0,
                              测速时间: Date(), 成功: true)
            ),
            节点模型(
                id: UUID(),
                名称: "日本-01",
                协议: .vless,
                地址: "jp01.example.com",
                端口: 443,
                用户标识: "c3d4e5f6-a7b8-9012-cdef-123456789012",
                传输类型: .grpc,
                启用TLS: true,
                服务器名称: "jp01.example.com",
                分组: "日本",
                标签: ["日本", "游戏"],
                备注: "游戏加速",
                来源类型: "订阅导入",
                测速数据: 测速结果(延迟毫秒: 120, 抖动毫秒: 10, 丢包率: 0,
                              下载速率: 150.0, 上传速率: 40.0,
                              测速时间: Date(), 成功: true)
            ),
            节点模型(
                id: UUID(),
                名称: "美国-01",
                协议: .trojan,
                地址: "us01.example.com",
                端口: 443,
                用户标识: nil,
                传输类型: .tcp,
                启用TLS: true,
                服务器名称: "us01.example.com",
                分组: "美国",
                标签: ["美国"],
                备注: nil,
                来源类型: "手动添加",
                测速数据: 测速结果(延迟毫秒: 210, 抖动毫秒: 15, 丢包率: 1.0,
                              下载速率: 90.0, 上传速率: 30.0,
                              测速时间: Date(), 成功: true)
            ),
            节点模型(
                id: UUID(),
                名称: "新加坡-01",
                协议: .vless,
                地址: "sg01.example.com",
                端口: 8443,
                用户标识: "d4e5f6a7-b8c9-0123-defa-234567890123",
                传输类型: .ws,
                启用TLS: true,
                服务器名称: "sg01.example.com",
                分组: "新加坡",
                标签: ["新加坡"],
                备注: nil,
                来源类型: "订阅导入",
                测速数据: nil
            )
        ]
    }

    /// 生成模拟订阅列表
    static func 生成订阅() -> [订阅模型] {
        [
            订阅模型(
                id: UUID(),
                名称: "主力订阅",
                地址: "https://sub.example.com/main",
                启用: true,
                自动更新: true,
                更新间隔分钟: 60,
                上次更新: Date().addingTimeInterval(-3600),
                更新状态: "成功",
                错误信息: nil,
                流量信息: 订阅流量信息(总流量: 107_374_182_400,
                                      已用流量: 21_474_836_480,
                                      到期时间: Date().addingTimeInterval(60 * 60 * 24 * 60)),
                节点数量: 4
            ),
            订阅模型(
                id: UUID(),
                名称: "备用订阅",
                地址: "https://sub2.example.com/backup",
                启用: true,
                自动更新: false,
                更新间隔分钟: 1440,
                上次更新: Date().addingTimeInterval(-86400 * 2),
                更新状态: "成功",
                错误信息: nil,
                流量信息: 订阅流量信息(总流量: 53_687_091_200,
                                      已用流量: 48_318_382_080,
                                      到期时间: Date().addingTimeInterval(60 * 60 * 24 * 5)),
                节点数量: 1
            ),
            订阅模型(
                id: UUID(),
                名称: "过期订阅",
                地址: "https://sub3.example.com/old",
                启用: false,
                自动更新: false,
                更新间隔分钟: 1440,
                上次更新: Date().addingTimeInterval(-86400 * 30),
                更新状态: "失败",
                错误信息: "HTTP 404：订阅地址不存在",
                流量信息: 订阅流量信息(总流量: 10_737_418_240,
                                      已用流量: 10_737_418_240,
                                      到期时间: Date().addingTimeInterval(-86400)),
                节点数量: 0
            )
        ]
    }

    /// 生成分流规则
    static func 生成分流规则() -> [分流规则模型] {
        [
            分流规则模型(id: UUID(), 名称: "内网直连", 启用: true,
                        匹配类型: .内网IP, 匹配值: "", 动作: .直连,
                        启用MITM: false, 优先级: 10, 备注: "局域网地址直连"),
            分流规则模型(id: UUID(), 名称: "国内域名直连", 启用: true,
                        匹配类型: .域名后缀, 匹配值: "cn,baidu.com,taobao.com",
                        动作: .直连, 启用MITM: false, 优先级: 20, 备注: nil),
            分流规则模型(id: UUID(), 名称: "广告拦截", 启用: true,
                        匹配类型: .域名关键词, 匹配值: "ads,advert,doubleclick",
                        动作: .拦截, 启用MITM: false, 优先级: 30, 备注: nil),
            分流规则模型(id: UUID(), 名称: "示例启用MITM", 启用: true,
                        匹配类型: .域名后缀, 匹配值: "example.com",
                        动作: .代理, 启用MITM: true, 优先级: 40,
                        备注: "测试 HTTPS 重写"),
            分流规则模型(id: UUID(), 名称: "兜底代理", 启用: true,
                        匹配类型: .域名正则, 匹配值: ".*",
                        动作: .代理, 启用MITM: false, 优先级: 99, 备注: "全部走代理")
        ]
    }

    /// 生成重写规则
    static func 生成重写规则() -> [重写规则模型] {
        [
            重写规则模型(id: UUID(), 名称: "移除广告JS", 启用: true,
                        域名后缀: "example.com", 路径正则: "\\.js$",
                        重写类型: "响应Body正则替换",
                        匹配表达式: "adScript\\(\\)",
                        替换内容: "/*广告已移除*/",
                        优先级: 10),
            重写规则模型(id: UUID(), 名称: "添加请求头", 启用: false,
                        域名后缀: "api.example.com", 路径正则: ".*",
                        重写类型: "请求头添加",
                        匹配表达式: "X-Custom-Header",
                        替换内容: "newvpn",
                        优先级: 20)
        ]
    }

    /// 生成脚本
    static func 生成脚本() -> [脚本模型] {
        [
            脚本模型(
                id: UUID(),
                名称: "移除网页广告",
                启用: true,
                描述: "页面加载完成后移除广告 DOM 元素",
                触发时机: "HTTP响应",
                匹配域名: "example.com",
                脚本内容: "function main(event) {\n  $http.log(\"脚本触发\");\n  var ads = document.querySelectorAll(\".ad\");\n  ads.forEach(function(el) { el.remove(); });\n}",
                超时毫秒: 200,
                优先级: 10
            ),
            脚本模型(
                id: UUID(),
                名称: "请求日志记录",
                启用: false,
                描述: "记录所有 API 请求到日志",
                触发时机: "HTTP请求",
                匹配域名: "api.example.com",
                脚本内容: "function main(event) {\n  $http.log(\"请求: \" + event.request.url);\n}",
                超时毫秒: 100,
                优先级: 20
            )
        ]
    }

    /// 生成日志
    static func 生成日志() -> [日志模型] {
        let 现在 = Date()
        return [
            日志模型(id: UUID(), 时间: 现在.addingTimeInterval(-60),
                    级别: .信息, 模块: "VPN模块", 内容: "隧道状态切换为：运行中"),
            日志模型(id: UUID(), 时间: 现在.addingTimeInterval(-55),
                    级别: .信息, 模块: "节点模块", 内容: "当前节点：香港-01"),
            日志模型(id: UUID(), 时间: 现在.addingTimeInterval(-30),
                    级别: .调试, 模块: "内核", 内容: "出站连接建立：hk01.example.com:443"),
            日志模型(id: UUID(), 时间: 现在.addingTimeInterval(-15),
                    级别: .警告, 模块: "订阅模块", 内容: "备用订阅流量已使用 90%，即将用尽"),
            日志模型(id: UUID(), 时间: 现在.addingTimeInterval(-5),
                    级别: .信息, 模块: "网络活动", 内容: "新建 TCP 连接：142.25.x.x:443")
        ]
    }

    /// 生成抓包会话
    static func 生成抓包会话() -> [抓包会话模型] {
        [
            抓包会话模型(
                id: UUID(), 序号: 1, 方法: "GET",
                URL地址: "https://example.com/api/config",
                域名: "example.com", 路径: "/api/config",
                状态码: 200, 开始时间: Date().addingTimeInterval(-30),
                耗时毫秒: 152, 请求大小: 320, 响应大小: 2048,
                内容类型: "application/json", 已解密: true,
                请求头: ["User-Agent": "NewVPN/1.0", "Accept": "application/json"],
                响应头: ["Content-Type": "application/json", "Server": "nginx"],
                请求Body: nil,
                响应Body: "{\"status\":\"ok\",\"version\":\"1.0\"}"
            ),
            抓包会话模型(
                id: UUID(), 序号: 2, 方法: "POST",
                URL地址: "https://api.example.com/v1/data",
                域名: "api.example.com", 路径: "/v1/data",
                状态码: 201, 开始时间: Date().addingTimeInterval(-20),
                耗时毫秒: 280, 请求大小: 512, 响应大小: 128,
                内容类型: "application/json", 已解密: true,
                请求头: ["Content-Type": "application/json"],
                响应头: ["Content-Type": "application/json"],
                请求Body: "{\"key\":\"value\"}",
                响应Body: "{\"id\":123}"
            ),
            抓包会话模型(
                id: UUID(), 序号: 3, 方法: "GET",
                URL地址: "https://www.google.com/",
                域名: "www.google.com", 路径: "/",
                状态码: nil, 开始时间: Date().addingTimeInterval(-5),
                耗时毫秒: nil, 请求大小: 256, 响应大小: nil,
                内容类型: "text/html", 已解密: false,
                请求头: ["User-Agent": "Mozilla/5.0"],
                响应头: [:],
                请求Body: nil, 响应Body: nil
            )
        ]
    }

    /// 生成网络连接
    static func 生成网络连接() -> [网络连接模型] {
        [
            网络连接模型(id: UUID(), 序号: 1, 协议: "TCP",
                        本地地址: "10.0.0.2", 本地端口: 51234,
                        远程地址: "142.25.1.100", 远程端口: 443,
                        域名: "www.google.com", 国家地区: "美国",
                        出站策略: "代理", 开始时间: Date().addingTimeInterval(-60),
                        已关闭: false, 上行字节: 2048, 下行字节: 15360),
            网络连接模型(id: UUID(), 序号: 2, 协议: "TCP",
                        本地地址: "10.0.0.2", 本地端口: 51235,
                        远程地址: "110.242.68.66", 远程端口: 443,
                        域名: "www.baidu.com", 国家地区: "中国",
                        出站策略: "直连", 开始时间: Date().addingTimeInterval(-30),
                        已关闭: false, 上行字节: 512, 下行字节: 4096),
            网络连接模型(id: UUID(), 序号: 3, 协议: "UDP",
                        本地地址: "10.0.0.2", 本地端口: 53000,
                        远程地址: "8.8.8.8", 远程端口: 53,
                        域名: nil, 国家地区: "美国",
                        出站策略: "代理", 开始时间: Date().addingTimeInterval(-10),
                        已关闭: true, 上行字节: 64, 下行字节: 128)
        ]
    }

    /// 根据节点列表按分组名聚合生成分组
    static func 生成节点分组(节点列表: [节点模型]) -> [节点分组模型] {
        let 分组字典 = Dictionary(grouping: 节点列表) { $0.分组 }
        return 分组字典.map { 分组名, 节点 in
            节点分组模型(
                名称: 分组名,
                节点列表: 节点,
                是否展开: false,
                测速中: false
            )
        }.sorted { $0.名称 < $1.名称 }
    }
}
