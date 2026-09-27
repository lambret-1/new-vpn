//
//  扩展日志记录器.swift
//  NewVPN-Tunnel
//
//  网络扩展共享日志记录器：将日志写入 App Group UserDefaults，供主 App 日志页面读取
//  所有扩展模块（隧道/MITM/抓包代理）统一通过此记录器输出日志
//

import Foundation

/// 扩展日志条目（与主 App 读取格式一致）
struct 扩展日志条目: Codable {
    let id: UUID
    let 时间: Date
    let 级别: String
    let 模块: String
    let 内容: String
}

/// 扩展日志记录器（单例）
final class 扩展日志记录器 {
    /// 共享单例
    static let 共享 = 扩展日志记录器()

    /// App Group UserDefaults
    private var 共享默认: UserDefaults? {
        UserDefaults(suiteName: "group.com.newvpn.app")
    }

    /// 日志写入队列（串行，避免并发解码-插入-编码-设置导致丢日志）
    private let 写入队列 = DispatchQueue(label: "com.newvpn.extension.log", qos: .utility)

    /// 最大保留日志条数
    private let 最大条数 = 500

    private init() {}

    // MARK: - 日志记录方法

    /// 记录信息级别日志
    func 信息(_ 模块: String, _ 内容: String) {
        记录(级别: "信息", 模块: 模块, 内容: 内容)
    }

    /// 记录调试级别日志
    func 调试(_ 模块: String, _ 内容: String) {
        记录(级别: "调试", 模块: 模块, 内容: 内容)
    }

    /// 记录警告级别日志
    func 警告(_ 模块: String, _ 内容: String) {
        记录(级别: "警告", 模块: 模块, 内容: 内容)
    }

    /// 记录错误级别日志
    func 错误(_ 模块: String, _ 内容: String) {
        记录(级别: "错误", 模块: 模块, 内容: 内容)
    }

    /// 记录追踪级别日志（最详细，默认不显示）
    func 追踪(_ 模块: String, _ 内容: String) {
        记录(级别: "追踪", 模块: 模块, 内容: 内容)
    }

    // MARK: - 核心写入逻辑

    /// 记录日志（核心方法，线程安全）
    private func 记录(级别: String, 模块: String, 内容: String) {
        let 条目 = 扩展日志条目(id: UUID(), 时间: Date(), 级别: 级别, 模块: 模块, 内容: 内容)

        // 同时输出到系统日志（便于 Xcode 控制台调试）
        NSLog("[扩展-\(模块)] \(内容)")

        // 异步写入 App Group UserDefaults
        写入队列.async { [weak self] in
            guard let self = self, let 共享默认 = self.共享默认 else { return }

            var 日志列表: [扩展日志条目] = []
            if let 日志数据 = 共享默认.data(forKey: "tunnelLogs"),
               let 已存列表 = try? JSONDecoder().decode([扩展日志条目].self, from: 日志数据) {
                日志列表 = 已存列表
            }

            // 新日志插入到最前面（倒序展示）
            日志列表.insert(条目, at: 0)

            // 超出上限时移除最旧的日志
            if 日志列表.count > self.最大条数 {
                日志列表.removeLast(日志列表.count - self.最大条数)
            }

            if let 编码数据 = try? JSONEncoder().encode(日志列表) {
                共享默认.set(编码数据, forKey: "tunnelLogs")
            }
        }
    }

    /// 清空所有扩展日志
    func 清空日志() {
        写入队列.async { [weak self] in
            guard let self = self, let 共享默认 = self.共享默认 else { return }
            共享默认.removeObject(forKey: "tunnelLogs")
            共享默认.synchronize()
        }
    }
}
