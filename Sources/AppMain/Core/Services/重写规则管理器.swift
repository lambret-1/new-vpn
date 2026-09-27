//
//  重写规则管理器.swift
//  NewVPN
//
//  URL 重写规则管理服务
//

import Foundation

// MARK: - 重写规则管理器

/// 重写规则管理器
final class 重写规则管理器: ObservableObject {
    /// 共享单例
    static let 共享 = 重写规则管理器()

    /// 私有初始化
    private init() {
        加载配置()
    }

    // MARK: - 配置

    /// 重写配置
    @Published var 配置 = 重写配置.默认

    // MARK: - UserDefaults 键

    private let 配置键 = "rewriteConfig"

    // MARK: - 加载和保存

    /// 从 UserDefaults 加载配置
    private func 加载配置() {
        guard let 数据 = UserDefaults.standard.data(forKey: 配置键),
              let 解码 = try? JSONDecoder().decode(重写配置.self, from: 数据) else {
            配置 = .默认
            return
        }
        配置 = 解码
    }

    /// 保存配置到 UserDefaults
    private func 保存配置() {
        if let 数据 = try? JSONEncoder().encode(配置) {
            UserDefaults.standard.set(数据, forKey: 配置键)
        }
    }

    // MARK: - 分组管理

    /// 添加分组
    func 添加分组(_ 分组: 重写规则分组) {
        配置.分组列表.append(分组)
        保存配置()
    }

    /// 删除分组
    func 删除分组(_ 分组: 重写规则分组) {
        配置.分组列表.removeAll { $0.id == 分组.id }
        保存配置()
    }

    /// 重命名分组
    func 重命名分组(_ 分组: 重写规则分组, 新名称: String) {
        if let 索引 = 配置.分组列表.firstIndex(where: { $0.id == 分组.id }) {
            配置.分组列表[索引].名称 = 新名称
            保存配置()
        }
    }

    /// 切换分组启用状态
    func 切换分组启用(_ 分组: 重写规则分组) {
        if let 索引 = 配置.分组列表.firstIndex(where: { $0.id == 分组.id }) {
            配置.分组列表[索引].启用.toggle()
            保存配置()
        }
    }

    // MARK: - 规则管理

    /// 添加规则到分组
    func 添加规则(_ 规则: 重写规则项, 到分组: 重写规则分组) {
        if let 索引 = 配置.分组列表.firstIndex(where: { $0.id == 到分组.id }) {
            配置.分组列表[索引].规则列表.append(规则)
            保存配置()
        }
    }

    /// 更新规则
    func 更新规则(_ 规则: 重写规则项) {
        for (分组索引, 分组) in 配置.分组列表.enumerated() {
            if let 规则索引 = 分组.规则列表.firstIndex(where: { $0.id == 规则.id }) {
                配置.分组列表[分组索引].规则列表[规则索引] = 规则
                保存配置()
                return
            }
        }
    }

    /// 删除规则
    func 删除规则(_ 规则: 重写规则项) {
        for (分组索引, 分组) in 配置.分组列表.enumerated() {
            if let 规则索引 = 分组.规则列表.firstIndex(where: { $0.id == 规则.id }) {
                配置.分组列表[分组索引].规则列表.remove(at: 规则索引)
                保存配置()
                return
            }
        }
    }

    /// 切换规则启用状态
    func 切换规则启用(_ 规则: 重写规则项) {
        for (分组索引, 分组) in 配置.分组列表.enumerated() {
            if let 规则索引 = 分组.规则列表.firstIndex(where: { $0.id == 规则.id }) {
                配置.分组列表[分组索引].规则列表[规则索引].启用.toggle()
                保存配置()
                return
            }
        }
    }

    // MARK: - 预设导入

    /// 应用预设重写规则集（创建新分组）
    func 应用预设规则集(_ 预设: 预设重写规则集) {
        let 新分组 = 重写规则分组(
            名称: 预设.名称,
            图标: 预设.图标,
            描述: 预设.描述,
            规则列表: 预设.规则列表
        )
        添加分组(新分组)
    }

    /// 导入预设规则到指定分组
    func 导入预设规则(_ 预设: 预设重写规则集, 追加到分组: 重写规则分组) {
        for 规则 in 预设.规则列表 {
            添加规则(规则, 到分组: 追加到分组)
        }
    }

    // MARK: - 统计

    /// 统计信息
    var 统计: (分组数: Int, 总规则数: Int, 启用规则数: Int) {
        let 所有规则 = 配置.分组列表.flatMap { $0.规则列表 }
        let 启用规则 = 所有规则.filter { $0.启用 }
        return (配置.分组列表.count, 所有规则.count, 启用规则.count)
    }

    /// 清除所有规则
    func 清除所有规则() {
        配置 = .默认
        保存配置()
    }
}
