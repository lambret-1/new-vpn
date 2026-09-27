//
//  抓包存储管理器.swift
//  NewVPN
//
//  HTTP 抓包记录存储管理，基于 App Group 实现主 App 与扩展进程共享
//  环形缓冲区，上限 500 条，超出滚动覆盖
//

import Foundation
import Combine

/// 抓包存储管理器（单例，主 App 和扩展进程共用）
final class 抓包存储管理器: ObservableObject {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = 抓包存储管理器()

    // MARK: - 常量

    /// App Group ID
    private let AppGroupID = "group.com.newvpn.app"
    /// 抓包记录存储键
    private let 抓包记录键 = "httpCaptureRecords"
    /// 最大记录数（环形缓冲）
    private let 最大记录数 = 500
    /// 抓包开关存储键
    private let 抓包开关键 = "httpCaptureEnabled"

    // MARK: - 属性

    /// App Group UserDefaults
    private var 共享默认: UserDefaults? {
        UserDefaults(suiteName: AppGroupID)
    }

    /// 内存缓存（减少磁盘读写）
    private var 内存缓存: [抓包记录] = []
    /// 内存缓存是否已加载
    private var 缓存已加载 = false
    /// 串行队列（保证读写线程安全）
    private let 串行队列 = DispatchQueue(label: "com.newvpn.capture.storage")

    // MARK: - 初始化

    private init() {
        加载到内存()
    }

    // MARK: - 开关管理

    /// 抓包功能是否启用
    var 是否启用: Bool {
        get {
            共享默认?.bool(forKey: 抓包开关键) ?? false
        }
        set {
            共享默认?.set(newValue, forKey: 抓包开关键)
            共享默认?.synchronize()
            if !newValue {
                // 关闭时清空记录
                清空记录()
            }
        }
    }

    // MARK: - 记录读写

    /// 获取所有抓包记录（按时间倒序）
    func 获取所有记录() -> [抓包记录] {
        串行队列.sync {
            if !缓存已加载 {
                加载到内存()
            }
            return 内存缓存
        }
    }

    /// 获取符合筛选条件的记录
    func 获取筛选记录(_ 筛选: 抓包筛选条件) -> [抓包记录] {
        let 全部 = 获取所有记录()
        if 筛选.是否空 { return 全部 }
        return 全部.filter { 筛选.匹配($0) }
    }

    /// 添加新记录（请求开始时调用）
    /// - Returns: 新记录的 ID
    @discardableResult
    func 添加记录(_ 记录: 抓包记录) -> UUID {
        串行队列.async { [weak self] in
            guard let self = self else { return }
            if !self.缓存已加载 {
                self.加载到内存()
            }
            // 插入到开头（最新在前）
            self.内存缓存.insert(记录, at: 0)
            // 环形缓冲：超出上限移除最旧的
            if self.内存缓存.count > self.最大记录数 {
                self.内存缓存.removeLast(self.内存缓存.count - self.最大记录数)
            }
            self.持久化()
        }
        return 记录.id
    }

    /// 更新已有记录（请求完成时调用）
    func 更新记录(_ 记录: 抓包记录) {
        串行队列.async { [weak self] in
            guard let self = self else { return }
            if !self.缓存已加载 {
                self.加载到内存()
            }
            if let 索引 = self.内存缓存.firstIndex(where: { $0.id == 记录.id }) {
                self.内存缓存[索引] = 记录
                self.持久化()
            }
        }
    }

    /// 根据 ID 获取单条记录
    func 获取记录(id: UUID) -> 抓包记录? {
        获取所有记录().first { $0.id == id }
    }

    /// 清空所有记录
    func 清空记录() {
        串行队列.async { [weak self] in
            guard let self = self else { return }
            self.内存缓存.removeAll()
            self.持久化()
        }
    }

    /// 删除单条记录
    func 删除记录(id: UUID) {
        串行队列.async { [weak self] in
            guard let self = self else { return }
            if !self.缓存已加载 {
                self.加载到内存()
            }
            self.内存缓存.removeAll { $0.id == id }
            self.持久化()
        }
    }

    // MARK: - 统计

    /// 记录总数
    var 记录总数: Int {
        获取所有记录().count
    }

    /// 错误请求数
    var 错误请求数: Int {
        获取所有记录().filter { $0.是否失败 }.count
    }

    /// HTTPS 请求数
    var HTTPS请求数: Int {
        获取所有记录().filter { $0.是否HTTPS }.count
    }

    // MARK: - 私有方法

    /// 从磁盘加载到内存
    private func 加载到内存() {
        guard let 共享默认 = 共享默认,
              let 数据 = 共享默认.data(forKey: 抓包记录键),
              let 记录 = try? JSONDecoder().decode([抓包记录].self, from: 数据) else {
            内存缓存 = []
            缓存已加载 = true
            return
        }
        内存缓存 = 记录
        缓存已加载 = true
    }

    /// 持久化到磁盘
    private func 持久化() {
        guard let 共享默认 = 共享默认,
              let 数据 = try? JSONEncoder().encode(内存缓存) else {
            return
        }
        共享默认.set(数据, forKey: 抓包记录键)
        共享默认.synchronize()
        // 通知 UI 刷新
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
}
