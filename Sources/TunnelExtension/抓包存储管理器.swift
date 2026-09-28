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
    /// 最大记录数（环形缓冲，内存优化：从500降至200）
    private let 最大记录数 = 200
    /// 抓包开关存储键
    private let 抓包开关键 = "httpCaptureEnabled"
    /// 热更新指令键
    private let 热更新指令键 = "captureHotUpdateCommand"
    /// 热更新结果键
    private let 热更新结果键 = "captureHotUpdateResult"
    /// 热更新事件日志键
    private let 热更新日志键 = "captureHotUpdateLogs"
    /// 最大热更新日志数
    private let 最大日志数 = 50

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

    // MARK: - 热更新通信

    /// 热更新指令数据结构
    struct 热更新指令: Codable {
        let 指令ID: String
        let 抓包启用: Bool
        let HTTPS抓包启用: Bool
        let 时间戳: Date
    }

    /// 热更新结果数据结构
    struct 热更新结果: Codable {
        let 指令ID: String
        let 成功: Bool
        let 错误信息: String?
        let 时间戳: Date
    }

    /// 热更新事件日志
    struct 热更新日志: Codable, Identifiable {
        let id: UUID
        let 时间: Date
        let 类型: String  // info/success/error
        let 消息: String

        init(类型: String, 消息: String) {
            self.id = UUID()
            self.时间 = Date()
            self.类型 = 类型
            self.消息 = 消息
        }
    }

    /// 发送热更新指令（主 App 调用）
    func 发送热更新指令(抓包启用: Bool, HTTPS抓包启用: Bool) -> String {
        let 指令ID = UUID().uuidString
        let 指令 = 热更新指令(
            指令ID: 指令ID,
            抓包启用: 抓包启用,
            HTTPS抓包启用: HTTPS抓包启用,
            时间戳: Date()
        )
        if let 共享默认 = 共享默认,
           let 数据 = try? JSONEncoder().encode(指令) {
            共享默认.set(数据, forKey: 热更新指令键)
            共享默认.synchronize()
            添加热更新日志(类型: "info", 消息: "发送热更新指令：抓包=\(抓包启用 ? "开启" : "关闭")，HTTPS=\(HTTPS抓包启用 ? "开启" : "关闭")")
        }
        return 指令ID
    }

    /// 读取并清除热更新指令（扩展进程调用）
    func 读取热更新指令() -> 热更新指令? {
        guard let 共享默认 = 共享默认,
              let 数据 = 共享默认.data(forKey: 热更新指令键),
              let 指令 = try? JSONDecoder().decode(热更新指令.self, from: 数据) else {
            return nil
        }
        // 读取后清除指令，避免重复处理
        共享默认.removeObject(forKey: 热更新指令键)
        共享默认.synchronize()
        return 指令
    }

    /// 写入热更新结果（扩展进程调用）
    func 写入热更新结果(指令ID: String, 成功: Bool, 错误信息: String? = nil) {
        let 结果 = 热更新结果(
            指令ID: 指令ID,
            成功: 成功,
            错误信息: 错误信息,
            时间戳: Date()
        )
        if let 共享默认 = 共享默认,
           let 数据 = try? JSONEncoder().encode(结果) {
            共享默认.set(数据, forKey: 热更新结果键)
            共享默认.synchronize()
            添加热更新日志(类型: 成功 ? "success" : "error", 消息: 成功 ? "热更新成功" : "热更新失败：\(错误信息 ?? "未知错误")")
        }
    }

    /// 读取热更新结果（主 App 调用，读取后清除）
    func 读取热更新结果() -> 热更新结果? {
        guard let 共享默认 = 共享默认,
              let 数据 = 共享默认.data(forKey: 热更新结果键),
              let 结果 = try? JSONDecoder().decode(热更新结果.self, from: 数据) else {
            return nil
        }
        共享默认.removeObject(forKey: 热更新结果键)
        共享默认.synchronize()
        return 结果
    }

    /// 添加热更新日志
    func 添加热更新日志(类型: String, 消息: String) {
        var 日志列表 = 获取热更新日志()
        日志列表.insert(热更新日志(类型: 类型, 消息: 消息), at: 0)
        if 日志列表.count > 最大日志数 {
            日志列表 = Array(日志列表.prefix(最大日志数))
        }
        if let 共享默认 = 共享默认,
           let 数据 = try? JSONEncoder().encode(日志列表) {
            共享默认.set(数据, forKey: 热更新日志键)
            共享默认.synchronize()
        }
    }

    /// 获取热更新日志
    func 获取热更新日志() -> [热更新日志] {
        guard let 共享默认 = 共享默认,
              let 数据 = 共享默认.data(forKey: 热更新日志键),
              let 日志 = try? JSONDecoder().decode([热更新日志].self, from: 数据) else {
            return []
        }
        return 日志
    }

    /// 清空热更新日志
    func 清空热更新日志() {
        if let 共享默认 = 共享默认 {
            共享默认.removeObject(forKey: 热更新日志键)
            共享默认.synchronize()
        }
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
