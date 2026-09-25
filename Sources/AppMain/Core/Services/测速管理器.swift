//
//  测速管理器.swift
//  NewVPN
//
//  测速任务管理器
//  管理单节点延迟测速、分组批量测速、全部节点测速、任务队列、取消
//

import Foundation
import Combine

// MARK: - 测速管理器

/// 测速任务管理器
final class 测速管理器: ObservableObject {
    /// 共享单例
    static let 共享 = 测速管理器()

    /// 测速配置
    @Published var 配置: 测速配置 = .默认

    /// 是否正在测速
    @Published var 是否测速中 = false

    /// 批量测速进度
    @Published var 批量进度: 批量测速进度?

    /// 单节点测速状态（节点ID: 状态）
    @Published var 节点测速状态: [UUID: 测速状态] = [:]

    /// 测速结果缓存（节点ID: 结果）
    @Published var 测速结果缓存: [UUID: 测速结果模型] = [:]

    /// 测速历史记录
    @Published var 历史记录: [测速历史记录] = []

    /// 测速任务队列
    private var 任务队列: [节点模型] = []
    /// 当前任务索引
    private var 当前任务索引 = 0
    /// 是否应该取消
    private var 应该取消 = false
    /// 测速并发队列
    private let 并发队列 = DispatchQueue(label: "com.newvpn.speedtest", qos: .userInitiated, attributes: .concurrent)
    /// 信号量（控制并发数）
    private var 并发信号量: DispatchSemaphore?

    /// 私有初始化
    private init() {}

    // MARK: - 单节点测速

    /// 测速单个节点
    /// - Parameters:
    ///   - 节点: 节点模型
    ///   - 完成: 完成回调
    func 测速节点(_ 节点: 节点模型, 完成: ((测速结果模型) -> Void)? = nil) {
        节点测速状态[节点.id] = .测速中

        并发队列.async { [weak self] in
            guard let self = self else { return }

            let 结果 = 测速服务.共享.测速节点(节点, 配置: self.配置)

            DispatchQueue.main.async {
                self.测速结果缓存[节点.id] = 结果
                self.节点测速状态[节点.id] = 结果.成功 ? .成功 : .失败(结果.错误信息 ?? "未知错误")
                完成?(结果)
            }
        }
    }

    // MARK: - 批量测速

    /// 批量测速多个节点
    /// - Parameters:
    ///   - 节点列表: 节点列表
    ///   - 节点更新: 单个节点测速完成回调
    ///   - 全部完成: 全部完成回调
    func 批量测速(_ 节点列表: [节点模型], 节点更新: ((节点模型, 测速结果模型) -> Void)? = nil, 全部完成: (([UUID: 测速结果模型]) -> Void)? = nil) {
        guard !是否测速中 else { return }
        guard !节点列表.isEmpty else {
            全部完成?([:])
            return
        }

        是否测速中 = true
        应该取消 = false
        任务队列 = 节点列表
        当前任务索引 = 0
        批量进度 = 批量测速进度(总数: 节点列表.count, 已完成: 0, 当前节点名称: nil)

        var 本次结果: [UUID: 测速结果模型] = [:]
        let 并发数 = max(1, min(配置.并发数, 5))
        并发信号量 = DispatchSemaphore(value: 并发数)

        并发队列.async { [weak self] in
            guard let self = self else { return }

            let 组 = DispatchGroup()

            for 节点 in 节点列表 {
                guard !self.应该取消 else { break }

                self.并发信号量?.wait()
                组.enter()

                DispatchQueue.global(qos: .userInitiated).async {
                    defer {
                        self.并发信号量?.signal()
                        组.leave()
                    }

                    guard !self.应该取消 else { return }

                    DispatchQueue.main.async {
                        self.节点测速状态[节点.id] = .测速中
                        self.批量进度?.当前节点名称 = 节点.名称
                    }

                    let 结果 = 测速服务.共享.测速节点(节点, 配置: self.配置)

                    DispatchQueue.main.async {
                        self.测速结果缓存[节点.id] = 结果
                        self.节点测速状态[节点.id] = 结果.成功 ? .成功 : .失败(结果.错误信息 ?? "未知错误")
                        本次结果[节点.id] = 结果
                        self.当前任务索引 += 1
                        self.批量进度?.已完成 = self.当前任务索引
                        节点更新?(节点, 结果)
                    }
                }
            }

            组.wait()

            DispatchQueue.main.async {
                self.是否测速中 = false
                self.批量进度?.当前节点名称 = nil

                // 保存历史记录
                let 成功结果 = 本次结果.values.filter { $0.成功 }
                let 平均延迟 = 成功结果.compactMap { $0.延迟毫秒 }.reduce(0, +) / max(1, 成功结果.count)

                let 历史 = 测速历史记录(
                    时间: Date(),
                    节点数: 本次结果.count,
                    平均延迟: 成功结果.isEmpty ? nil : 平均延迟
                )
                self.历史记录.insert(历史, at: 0)
                if self.历史记录.count > 50 {
                    self.历史记录.removeLast()
                }

                全部完成?(本次结果)
            }
        }
    }

    // MARK: - 取消测速

    /// 取消当前测速任务
    func 取消测速() {
        应该取消 = true
        是否测速中 = false
        批量进度 = nil

        // 重置所有测速中状态
        for (id, 状态) in 节点测速状态 {
            if 状态.是否测速中 {
                节点测速状态[id] = .未测速
            }
        }
    }

    // MARK: - 清除缓存

    /// 清除测速结果缓存
    func 清除缓存() {
        测速结果缓存.removeAll()
        节点测速状态.removeAll()
    }

    /// 清除指定节点的测速缓存
    func 清除节点缓存(节点ID: UUID) {
        测速结果缓存.removeValue(forKey: 节点ID)
        节点测速状态.removeValue(forKey: 节点ID)
    }

    // MARK: - 排序辅助

    /// 按延迟排序节点列表
    func 按延迟排序(_ 节点列表: [节点模型]) -> [节点模型] {
        节点列表.sorted { 节点1, 节点2 in
            let 延迟1 = 测速结果缓存[节点1.id]?.延迟毫秒 ?? Int.max
            let 延迟2 = 测速结果缓存[节点2.id]?.延迟毫秒 ?? Int.max
            return 延迟1 < 延迟2
        }
    }
}
