//
//  配置描述文件管理器.swift
//  NewVPN
//
//  配置描述文件管理器
//  管理配置列表、当前激活配置、配置切换、自动更新
//

import Foundation
import Combine

/// 配置描述文件管理器
final class 配置描述文件管理器: ObservableObject {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = 配置描述文件管理器()

    // MARK: - 发布属性

    /// 配置列表
    @Published private(set) var 配置列表: [配置描述文件] = []

    /// 当前激活的配置
    @Published private(set) var 当前激活配置: 配置描述文件?

    /// 是否加载中
    @Published var 是否加载中 = false

    /// 最近错误信息
    @Published var 最近错误: String?

    /// 搜索关键词
    @Published var 搜索关键词 = ""

    // MARK: - 属性

    /// 配置文件服务
    private let 服务 = 配置描述文件服务.共享

    /// 自动更新定时器
    private var 自动更新定时器: Timer?

    // MARK: - 初始化

    private init() {
        加载配置列表()
        启动自动更新检查()
    }

    // MARK: - 配置列表管理

    /// 加载配置列表
    func 加载配置列表() {
        是否加载中 = true
        最近错误 = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var 列表 = self.服务.加载元数据列表()

            // 如果没有配置，创建默认配置
            if 列表.isEmpty {
                let 默认配置 = 配置描述文件.默认配置()
                if self.服务.保存配置内容(默认配置, 内容: self.生成默认配置内容()) {
                    列表.append(默认配置)
                    _ = self.服务.保存元数据列表(列表)
                }
            }

            DispatchQueue.main.async {
                self.配置列表 = 列表
                self.当前激活配置 = 列表.first(where: { $0.是否激活 }) ?? 列表.first
                self.是否加载中 = false
            }
        }
    }

    /// 筛选后的配置列表
    var 筛选后的配置列表: [配置描述文件] {
        if 搜索关键词.isEmpty {
            return 配置列表
        }
        return 配置列表.filter { 配置 in
            配置.名称.localizedCaseInsensitiveContains(搜索关键词) ||
            (配置.描述?.localizedCaseInsensitiveContains(搜索关键词) ?? false) ||
            配置.标签.contains { $0.localizedCaseInsensitiveContains(搜索关键词) }
        }
    }

    /// 按类型分组的配置
    var 按类型分组: [(类型: 配置文件类型, 配置列表: [配置描述文件])] {
        let 分组 = Dictionary(grouping: 筛选后的配置列表) { $0.类型 }
        return 分组.map { (类型: $0.key, 配置列表: $0.value) }
            .sorted { $0.类型.rawValue < $1.类型.rawValue }
    }

    // MARK: - 配置激活与切换

    /// 激活配置
    func 激活配置(_ 配置: 配置描述文件) {
        // 取消所有配置的激活状态
        for i in 0..<配置列表.count {
            配置列表[i].是否激活 = false
        }

        // 激活新配置
        if let 索引 = 配置列表.firstIndex(where: { $0.id == 配置.id }) {
            配置列表[索引].是否激活 = true
            配置列表[索引].最后使用时间 = Date()
            当前激活配置 = 配置列表[索引]
        }

        // 保存元数据
        _ = 服务.保存元数据列表(配置列表)
    }

    /// 切换到下一个配置
    func 切换到下一个配置() {
        guard 配置列表.count > 1 else { return }
        guard let 当前 = 当前激活配置,
              let 当前索引 = 配置列表.firstIndex(where: { $0.id == 当前.id }) else {
            if let 第一个 = 配置列表.first {
                激活配置(第一个)
            }
            return
        }

        let 下一个索引 = (当前索引 + 1) % 配置列表.count
        激活配置(配置列表[下一个索引])
    }

    // MARK: - 配置增删改

    /// 添加配置
    func 添加配置(_ 配置: 配置描述文件) {
        配置列表.append(配置)
        _ = 服务.保存元数据列表(配置列表)
    }

    /// 更新配置
    func 更新配置(_ 配置: 配置描述文件) {
        if let 索引 = 配置列表.firstIndex(where: { $0.id == 配置.id }) {
            配置列表[索引] = 配置
            配置列表[索引].最后修改时间 = Date()
            if 配置.是否激活 {
                当前激活配置 = 配置列表[索引]
            }
            _ = 服务.保存元数据列表(配置列表)
        }
    }

    /// 删除配置
    func 删除配置(_ 配置: 配置描述文件) {
        // 不允许删除默认配置
        guard !配置.是否默认 else {
            最近错误 = "不能删除默认配置"
            return
        }

        // 删除文件
        _ = 服务.删除配置文件(配置)

        // 从列表移除
        配置列表.removeAll { $0.id == 配置.id }

        // 如果删除的是当前激活配置，激活第一个
        if 当前激活配置?.id == 配置.id {
            当前激活配置 = 配置列表.first
            if let 第一个 = 配置列表.first {
                激活配置(第一个)
            }
        }

        _ = 服务.保存元数据列表(配置列表)
    }

    /// 重命名配置
    func 重命名配置(_ 配置: 配置描述文件, 新名称: String) {
        guard !新名称.isEmpty else { return }
        if let 索引 = 配置列表.firstIndex(where: { $0.id == 配置.id }) {
            配置列表[索引].名称 = 新名称
            配置列表[索引].最后修改时间 = Date()
            if 配置.是否激活 {
                当前激活配置 = 配置列表[索引]
            }
            _ = 服务.保存元数据列表(配置列表)
        }
    }

    /// 复制配置
    func 复制配置(_ 配置: 配置描述文件, 新名称: String) -> 配置描述文件? {
        guard let 新配置 = 服务.复制配置文件(源配置: 配置, 新名称: 新名称) else {
            最近错误 = "复制配置失败"
            return nil
        }
        添加配置(新配置)
        return 新配置
    }

    // MARK: - 配置导入导出

    /// 从文件 URL 导入配置
    func 从URL导入配置(文件URL: URL, 名称: String? = nil, 完成: @escaping (配置文件导入结果) -> Void) {
        是否加载中 = true
        最近错误 = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let 结果 = self.服务.从URL导入配置(文件URL: 文件URL, 名称: 名称)

            DispatchQueue.main.async {
                self.是否加载中 = false
                if 结果.成功, let 配置 = 结果.配置 {
                    self.添加配置(配置)
                } else {
                    self.最近错误 = 结果.错误信息
                }
                完成(结果)
            }
        }
    }

    /// 从字符串导入配置
    func 从字符串导入配置(内容: String, 名称: String, 类型: 配置文件类型 = .singbox, 完成: @escaping (配置文件导入结果) -> Void) {
        是否加载中 = true
        最近错误 = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let 结果 = self.服务.从字符串导入配置(内容: 内容, 名称: 名称, 类型: 类型)

            DispatchQueue.main.async {
                self.是否加载中 = false
                if 结果.成功, let 配置 = 结果.配置 {
                    self.添加配置(配置)
                } else {
                    self.最近错误 = 结果.错误信息
                }
                完成(结果)
            }
        }
    }

    /// 导出配置
    func 导出配置(_ 配置: 配置描述文件, 选项: 配置文件导出选项 = .默认) -> URL? {
        服务.导出配置(配置, 选项: 选项)
    }

    // MARK: - 配置内容管理

    /// 加载配置内容
    func 加载配置内容(_ 配置: 配置描述文件) -> String? {
        服务.加载配置内容(配置)
    }

    /// 保存配置内容
    func 保存配置内容(_ 配置: 配置描述文件, 内容: String, 修改说明: String? = nil) -> Bool {
        // 创建版本备份
        _ = 服务.创建版本备份(配置, 修改说明: 修改说明)

        // 保存新内容
        guard 服务.保存配置内容(配置, 内容: 内容) else {
            最近错误 = "保存配置失败"
            return false
        }

        // 更新统计和版本号
        if let 索引 = 配置列表.firstIndex(where: { $0.id == 配置.id }) {
            配置列表[索引].统计 = 服务.计算配置统计(内容, 类型: 配置.类型)
            配置列表[索引].版本号 += 1
            配置列表[索引].版本 = "1.0.\(配置列表[索引].版本号)"
            配置列表[索引].最后修改时间 = Date()
            if 配置.是否激活 {
                当前激活配置 = 配置列表[索引]
            }
            _ = 服务.保存元数据列表(配置列表)
        }

        return true
    }

    /// 验证配置内容
    func 验证配置内容(_ 内容: String, 类型: 配置文件类型) -> (有效: Bool, 错误: String?, 警告: [String]) {
        服务.验证配置内容(内容, 类型: 类型)
    }

    // MARK: - 版本管理

    /// 加载配置版本列表
    func 加载版本列表(_ 配置: 配置描述文件) -> [配置文件版本记录] {
        服务.加载版本列表(配置.id)
    }

    /// 恢复配置版本
    func 恢复版本(_ 版本: 配置文件版本记录, 到配置: 配置描述文件) -> Bool {
        guard 服务.恢复版本(版本, 到配置: 到配置) else {
            最近错误 = "恢复版本失败"
            return false
        }

        // 更新配置的修改时间
        if let 索引 = 配置列表.firstIndex(where: { $0.id == 到配置.id }) {
            配置列表[索引].最后修改时间 = Date()
            _ = 服务.保存元数据列表(配置列表)
        }

        return true
    }

    // MARK: - 自动更新

    /// 启动自动更新检查
    private func 启动自动更新检查() {
        自动更新定时器?.invalidate()
        自动更新定时器 = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.检查自动更新()
        }
    }

    /// 检查自动更新
    func 检查自动更新() {
        let 现在 = Date()
        for 配置 in 配置列表 where 配置.自动更新 {
            guard let 上次更新 = 配置.上次更新时间 else {
                // 从未更新过，立即更新
                更新订阅配置(配置)
                continue
            }

            let 间隔分钟 = 现在.timeIntervalSince(上次更新) / 60
            if Int(间隔分钟) >= 配置.更新间隔分钟 {
                更新订阅配置(配置)
            }
        }
    }

    /// 更新订阅配置
    private func 更新订阅配置(_ 配置: 配置描述文件) {
        // 这里需要调用订阅下载服务来更新配置
        // 暂时只更新时间戳
        if let 索引 = 配置列表.firstIndex(where: { $0.id == 配置.id }) {
            配置列表[索引].上次更新时间 = Date()
            _ = 服务.保存元数据列表(配置列表)
        }
    }

    /// 切换自动更新
    func 切换自动更新(_ 配置: 配置描述文件, 启用: Bool) {
        if let 索引 = 配置列表.firstIndex(where: { $0.id == 配置.id }) {
            配置列表[索引].自动更新 = 启用
            _ = 服务.保存元数据列表(配置列表)
        }
    }

    // MARK: - 统计信息

    /// 配置总数
    var 配置总数: Int { 配置列表.count }

    /// 激活配置数（应该只有1个）
    var 激活配置数: Int { 配置列表.filter { $0.是否激活 }.count }

    /// 订阅配置数
    var 订阅配置数: Int { 配置列表.filter { $0.关联订阅ID != nil }.count }

    /// 总节点数
    var 总节点数: Int { 配置列表.reduce(0) { $0 + $1.统计.节点数量 } }

    // MARK: - 私有方法

    /// 生成默认配置内容（对齐官方客户端格式）
    private func 生成默认配置内容() -> String {
        """
        {
          "log": {
            "level": "debug",
            "timestamp": true
          },
          "dns": {
            "servers": [
              {
                "tag": "dns_resolver",
                "address": "tls://223.5.5.5",
                "detour": "DIRECT"
              },
              {
                "tag": "dns_proxy",
                "address": "https://8.8.8.8/dns-query",
                "detour": "proxy"
              }
            ],
            "final": "dns_proxy",
            "strategy": "ipv4_only"
          },
          "inbounds": [
            {
              "type": "tun",
              "tag": "tun-in",
              "address": ["172.19.0.1/30"],
              "mtu": 1500,
              "auto_route": true,
              "strict_route": true,
              "stack": "mixed"
            }
          ],
          "outbounds": [
            {
              "type": "direct",
              "tag": "DIRECT"
            },
            {
              "type": "block",
              "tag": "REJECT"
            }
          ],
          "route": {
            "rules": [
              {
                "ip_is_private": true,
                "outbound": "DIRECT"
              }
            ],
            "final": "DIRECT",
            "auto_detect_interface": false
          }
        }
        """
    }
}
