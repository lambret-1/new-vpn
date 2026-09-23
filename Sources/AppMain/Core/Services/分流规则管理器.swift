//
//  分流规则管理器.swift
//  NewVPN
//
//  分流规则管理器：规则管理、预设规则、统计、导入导出
//

import Foundation
import Combine

// MARK: - 分流规则管理器

/// 分流规则全局管理器
final class 分流规则管理器: ObservableObject {
    /// 共享单例
    static let 共享 = 分流规则管理器()

    // MARK: - 配置状态

    /// 分流配置
    @Published var 配置: 分流配置模型 = .默认

    /// 最近测试结果
    @Published var 最近测试结果: 分流测试结果?

    /// 是否正在导入
    @Published var 是否导入中 = false

    // MARK: - 持久化

    /// 配置存储键
    private let 配置存储键 = "分流配置"

    /// 私有初始化
    private init() {
        加载配置()
    }

    // MARK: - 配置管理

    /// 加载配置
    private func 加载配置() {
        if let 数据 = UserDefaults.standard.data(forKey: 配置存储键),
           let 解码配置 = try? JSONDecoder().decode(分流配置模型.self, from: 数据) {
            配置 = 解码配置
        }
    }

    /// 保存配置
    func 保存配置() {
        if let 数据 = try? JSONEncoder().encode(配置) {
            UserDefaults.standard.set(数据, forKey: 配置存储键)
        }
    }

    /// 重置为默认配置
    func 重置配置() {
        配置 = .默认
        保存配置()
    }

    // MARK: - 分组管理

    /// 添加分组
    func 添加分组(_ 分组: 分流规则分组) {
        配置.分组列表.append(分组)
        保存配置()
    }

    /// 删除分组
    func 删除分组(_ 分组: 分流规则分组) {
        配置.分组列表.removeAll { $0.id == 分组.id }
        保存配置()
    }

    /// 切换分组展开状态
    func 切换分组展开(_ 分组: 分流规则分组) {
        if let 索引 = 配置.分组列表.firstIndex(where: { $0.id == 分组.id }) {
            配置.分组列表[索引].是否展开.toggle()
        }
    }

    /// 切换分组启用状态
    func 切换分组启用(_ 分组: 分流规则分组) {
        if let 索引 = 配置.分组列表.firstIndex(where: { $0.id == 分组.id }) {
            配置.分组列表[索引].启用.toggle()
            保存配置()
        }
    }

    // MARK: - 规则管理

    /// 添加规则到指定分组
    func 添加规则(_ 规则: 分流规则模型, 到分组: 分流规则分组) {
        if let 分组索引 = 配置.分组列表.firstIndex(where: { $0.id == 到分组.id }) {
            配置.分组列表[分组索引].规则列表.append(规则)
            保存配置()
        }
    }

    /// 更新规则
    func 更新规则(_ 规则: 分流规则模型) {
        for (分组索引, 分组) in 配置.分组列表.enumerated() {
            if let 规则索引 = 分组.规则列表.firstIndex(where: { $0.id == 规则.id }) {
                配置.分组列表[分组索引].规则列表[规则索引] = 规则
                保存配置()
                return
            }
        }
    }

    /// 删除规则
    func 删除规则(_ 规则: 分流规则模型) {
        for (分组索引, 分组) in 配置.分组列表.enumerated() {
            if let 规则索引 = 分组.规则列表.firstIndex(where: { $0.id == 规则.id }) {
                配置.分组列表[分组索引].规则列表.remove(at: 规则索引)
                保存配置()
                return
            }
        }
    }

    /// 切换规则启用状态
    func 切换规则启用(_ 规则: 分流规则模型) {
        for (分组索引, 分组) in 配置.分组列表.enumerated() {
            if let 规则索引 = 分组.规则列表.firstIndex(where: { $0.id == 规则.id }) {
                配置.分组列表[分组索引].规则列表[规则索引].启用.toggle()
                保存配置()
                return
            }
        }
    }

    /// 移动规则顺序
    func 移动规则(在分组: 分流规则分组, 从源索引: IndexSet, 到目标索引: Int) {
        if let 分组索引 = 配置.分组列表.firstIndex(where: { $0.id == 在分组.id }) {
            配置.分组列表[分组索引].规则列表.move(fromOffsets: 从源索引, toOffset: 到目标索引)
            保存配置()
        }
    }

    // MARK: - 规则匹配

    /// 匹配分流规则
    func 匹配规则(域名: String? = nil,
                 IP地址: String? = nil,
                 端口: Int? = nil,
                 协议: 网络协议? = nil) -> 分流规则模型? {
        guard 配置.启用分流 else { return nil }

        let 匹配规则 = 分流规则服务.共享.匹配规则(
            域名: 域名,
            IP地址: IP地址,
            端口: 端口,
            协议: 协议,
            规则列表: 配置.所有规则
        )

        // 更新命中统计
        if let 规则 = 匹配规则, 配置.启用统计 {
            记录命中(规则)
        }

        return 匹配规则
    }

    /// 获取分流动作
    func 获取分流动作(域名: String? = nil,
                     IP地址: String? = nil,
                     端口: Int? = nil,
                     协议: 网络协议? = nil) -> 分流动作 {
        if let 规则 = 匹配规则(域名: 域名, IP地址: IP地址, 端口: 端口, 协议: 协议) {
            return 规则.动作
        }
        return 配置.默认动作
    }

    /// 记录规则命中
    private func 记录命中(_ 规则: 分流规则模型) {
        for (分组索引, 分组) in 配置.分组列表.enumerated() {
            if let 规则索引 = 分组.规则列表.firstIndex(where: { $0.id == 规则.id }) {
                配置.分组列表[分组索引].规则列表[规则索引].命中次数 += 1
                配置.分组列表[分组索引].规则列表[规则索引].最后命中时间 = Date()
                return
            }
        }
    }

    // MARK: - 规则测试

    /// 测试规则匹配
    func 测试规则(测试值: String) -> 分流测试结果 {
        let 结果 = 分流规则服务.共享.测试匹配(
            测试值: 测试值,
            规则列表: 配置.所有规则,
            默认动作: 配置.默认动作
        )
        最近测试结果 = 结果
        return 结果
    }

    // MARK: - 预设规则

    /// 应用预设规则集
    func 应用预设规则集(_ 预设: 预设规则集, 到分组: 分流规则分组? = nil) {
        let 目标分组: 分流规则分组

        if let 分组 = 到分组 {
            目标分组 = 分组
        } else {
            // 创建新分组
            let 新分组 = 分流规则分组(
                名称: 预设.名称,
                描述: 预设.描述,
                图标: 预设.图标,
                规则列表: []
            )
            添加分组(新分组)
            目标分组 = 新分组
        }

        // 添加规则
        for 规则 in 预设.规则列表 {
            添加规则(规则, 到分组: 目标分组)
        }
    }

    /// 导入预设规则集（追加到现有分组）
    func 导入预设规则(_ 预设: 预设规则集, 追加到分组: 分流规则分组) {
        for 规则 in 预设.规则列表 {
            添加规则(规则, 到分组: 追加到分组)
        }
    }

    // MARK: - 导入导出

    /// 从 Clash 配置导入规则
    func 从Clash导入(_ 配置文本: String, 到分组: 分流规则分组? = nil) -> Int {
        是否导入中 = true
        defer { 是否导入中 = false }

        let 导入规则 = 分流规则服务.共享.从Clash导入规则(配置文本)

        let 目标分组 = 到分组 ?? 配置.分组列表.first ?? 分流规则分组(名称: "导入规则", 规则列表: [])

        if 到分组 == nil && !配置.分组列表.contains(where: { $0.id == 目标分组.id }) {
            添加分组(目标分组)
        }

        for 规则 in 导入规则 {
            添加规则(规则, 到分组: 目标分组)
        }

        return 导入规则.count
    }

    /// 从 sing-box 配置导入规则
    func 从SingBox导入(_ 配置文本: String, 到分组: 分流规则分组? = nil) -> Int {
        是否导入中 = true
        defer { 是否导入中 = false }

        let 导入规则 = 分流规则服务.共享.从SingBox导入规则(配置文本)

        let 目标分组 = 到分组 ?? 配置.分组列表.first ?? 分流规则分组(名称: "导入规则", 规则列表: [])

        if 到分组 == nil && !配置.分组列表.contains(where: { $0.id == 目标分组.id }) {
            添加分组(目标分组)
        }

        for 规则 in 导入规则 {
            添加规则(规则, 到分组: 目标分组)
        }

        return 导入规则.count
    }

    /// 导出为 Clash 格式
    func 导出为Clash格式() -> String {
        分流规则服务.共享.导出为Clash格式(配置.所有规则)
    }

    // MARK: - 统计

    /// 规则统计
    var 统计: (总规则数: Int, 启用规则数: Int, 总命中数: Int, 分组数: Int) {
        let 所有规则 = 配置.分组列表.flatMap { $0.规则列表 }
        let 启用规则 = 所有规则.filter { $0.启用 }
        let 总命中 = 所有规则.reduce(0) { $0 + $1.命中次数 }
        return (所有规则.count, 启用规则.count, 总命中, 配置.分组列表.count)
    }

    /// 清除所有命中统计
    func 清除统计() {
        for (分组索引, _) in 配置.分组列表.enumerated() {
            for (规则索引, _) in 配置.分组列表[分组索引].规则列表.enumerated() {
                配置.分组列表[分组索引].规则列表[规则索引].命中次数 = 0
                配置.分组列表[分组索引].规则列表[规则索引].最后命中时间 = nil
            }
        }
        保存配置()
    }

    /// 按命中次数排序的规则
    var 热门规则: [分流规则模型] {
        配置.所有规则
            .filter { $0.命中次数 > 0 }
            .sorted { $0.命中次数 > $1.命中次数 }
    }
}
