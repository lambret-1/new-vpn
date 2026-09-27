//
//  过滤规则管理器.swift
//  NewVPN
//
//  HTTP 抓包过滤规则管理，支持保存/加载/删除命名筛选条件
//

import Foundation

/// 已保存的过滤规则
struct 已保存过滤规则: Codable, Equatable, Identifiable {
    /// 唯一标识
    let id: UUID
    /// 规则名称
    var 名称: String
    /// 筛选条件
    var 筛选条件: 抓包筛选条件
    /// 创建时间
    let 创建时间: Date

    init(名称: String, 筛选条件: 抓包筛选条件) {
        self.id = UUID()
        self.名称 = 名称
        self.筛选条件 = 筛选条件
        self.创建时间 = Date()
    }
}

/// 过滤规则管理器（单例）
final class 过滤规则管理器 {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = 过滤规则管理器()

    // MARK: - 常量

    /// App Group ID
    private let AppGroupID = "group.com.newvpn.app"
    /// 存储键
    private let 存储键 = "savedCaptureFilters"

    // MARK: - 属性

    /// 已保存的规则列表
    private(set) var 规则列表: [已保存过滤规则] = []

    // MARK: - 初始化

    private init() {
        加载规则()
    }

    // MARK: - 公共方法

    /// 保存新规则
    func 保存规则(名称: String, 筛选条件: 抓包筛选条件) {
        // 检查是否已存在同名规则
        if let 索引 = 规则列表.firstIndex(where: { $0.名称 == 名称 }) {
            规则列表[索引].筛选条件 = 筛选条件
        } else {
            let 新规则 = 已保存过滤规则(名称: 名称, 筛选条件: 筛选条件)
            规则列表.append(新规则)
        }
        持久化()
    }

    /// 删除规则
    func 删除规则(_ id: UUID) {
        规则列表.removeAll { $0.id == id }
        持久化()
    }

    /// 获取规则
    func 获取规则(_ id: UUID) -> 已保存过滤规则? {
        规则列表.first { $0.id == id }
    }

    /// 规则数量
    var 规则数量: Int {
        规则列表.count
    }

    // MARK: - 私有方法

    /// 从磁盘加载
    private func 加载规则() {
        guard let 共享默认 = UserDefaults(suiteName: AppGroupID),
              let 数据 = 共享默认.data(forKey: 存储键),
              let 规则 = try? JSONDecoder().decode([已保存过滤规则].self, from: 数据) else {
            规则列表 = []
            return
        }
        规则列表 = 规则
    }

    /// 持久化到磁盘
    private func 持久化() {
        guard let 共享默认 = UserDefaults(suiteName: AppGroupID),
              let 数据 = try? JSONEncoder().encode(规则列表) else {
            return
        }
        共享默认.set(数据, forKey: 存储键)
        共享默认.synchronize()
    }
}
