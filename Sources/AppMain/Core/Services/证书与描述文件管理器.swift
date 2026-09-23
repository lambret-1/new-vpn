//
//  证书与描述文件管理器.swift
//  NewVPN
//
//  证书与描述文件管理器
//  管理 CA 证书列表、VPN 描述文件列表、安装状态监控
//

import Foundation
import Combine
import NetworkExtension

/// 证书与描述文件管理器
final class 证书与描述文件管理器: ObservableObject {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = 证书与描述文件管理器()

    // MARK: - 发布属性

    /// CA 证书列表
    @Published private(set) var 证书列表: [CA证书模型] = []

    /// VPN 描述文件列表
    @Published private(set) var 描述文件列表: [VPN描述文件模型] = []

    /// 是否加载中
    @Published var 是否加载中 = false

    /// 最近错误信息
    @Published var 最近错误: String?

    /// 搜索关键词
    @Published var 搜索关键词 = ""

    /// VPN 连接状态
    @Published private(set) var VPN连接状态: NEVPNStatus = .invalid

    // MARK: - 属性

    /// CA 证书服务
    private let 证书服务 = CA证书服务.共享

    /// VPN 描述文件服务
    private let 描述文件服务 = VPN描述文件服务.共享

    /// 连接状态观察者
    private var 连接状态观察者: NSObjectProtocol?

    // MARK: - 初始化

    private init() {
        加载数据()
        监听连接状态()
    }

    deinit {
        if let 观察者 = 连接状态观察者 {
            NotificationCenter.default.removeObserver(观察者)
        }
    }

    // MARK: - 数据加载

    /// 加载所有数据
    func 加载数据() {
        是否加载中 = true
        最近错误 = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let 证书 = self.证书服务.加载证书列表()
            let 描述文件 = self.描述文件服务.加载描述文件列表()

            DispatchQueue.main.async {
                self.证书列表 = 证书
                self.描述文件列表 = 描述文件
                self.是否加载中 = false
            }
        }
    }

    /// 筛选后的证书列表
    var 筛选后的证书列表: [CA证书模型] {
        if 搜索关键词.isEmpty {
            return 证书列表
        }
        return 证书列表.filter { 证书 in
            证书.名称.localizedCaseInsensitiveContains(搜索关键词) ||
            证书.主题.localizedCaseInsensitiveContains(搜索关键词) ||
            证书.颁发者.localizedCaseInsensitiveContains(搜索关键词)
        }
    }

    /// 筛选后的描述文件列表
    var 筛选后的描述文件列表: [VPN描述文件模型] {
        if 搜索关键词.isEmpty {
            return 描述文件列表
        }
        return 描述文件列表.filter { 描述文件 in
            描述文件.名称.localizedCaseInsensitiveContains(搜索关键词) ||
            描述文件.服务器地址.localizedCaseInsensitiveContains(搜索关键词)
        }
    }

    // MARK: - CA 证书管理

    /// 导入证书（从 PEM 字符串）
    func 导入证书(pem字符串: String, 名称: String? = nil, 完成: @escaping (证书导入结果) -> Void) {
        是否加载中 = true
        最近错误 = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let 结果 = self.证书服务.从PEM导入证书(pem字符串, 名称: 名称)

            DispatchQueue.main.async {
                self.是否加载中 = false
                if 结果.成功, let 证书 = 结果.证书 {
                    self.证书列表.append(证书)
                    _ = self.证书服务.保存证书列表(self.证书列表)
                } else {
                    self.最近错误 = 结果.错误信息
                }
                完成(结果)
            }
        }
    }

    /// 导入证书（从文件 URL）
    func 导入证书(文件URL: URL, 名称: String? = nil, 完成: @escaping (证书导入结果) -> Void) {
        是否加载中 = true
        最近错误 = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let 结果 = self.证书服务.从文件导入证书(文件URL: 文件URL, 名称: 名称)

            DispatchQueue.main.async {
                self.是否加载中 = false
                if 结果.成功, let 证书 = 结果.证书 {
                    self.证书列表.append(证书)
                    _ = self.证书服务.保存证书列表(self.证书列表)
                } else {
                    self.最近错误 = 结果.错误信息
                }
                完成(结果)
            }
        }
    }

    /// 删除证书
    func 删除证书(_ 证书: CA证书模型) {
        _ = 证书服务.删除证书文件(证书)
        证书列表.removeAll { $0.id == 证书.id }
        _ = 证书服务.保存证书列表(证书列表)
    }

    /// 更新证书
    func 更新证书(_ 证书: CA证书模型) {
        if let 索引 = 证书列表.firstIndex(where: { $0.id == 证书.id }) {
            证书列表[索引] = 证书
            _ = 证书服务.保存证书列表(证书列表)
        }
    }

    /// 标记证书为已安装
    func 标记证书已安装(_ 证书: CA证书模型) {
        if let 索引 = 证书列表.firstIndex(where: { $0.id == 证书.id }) {
            证书列表[索引].状态 = .已安装
            证书列表[索引].安装时间 = Date()
            _ = 证书服务.保存证书列表(证书列表)
        }
    }

    /// 导出证书为 PEM
    func 导出证书PEM(_ 证书: CA证书模型) -> String? {
        证书服务.导出为PEM(证书)
    }

    /// 生成证书描述文件 URL
    func 生成证书描述文件URL(_ 证书: CA证书模型) -> URL? {
        证书服务.保存描述文件到临时目录(证书)
    }

    /// 验证证书有效性
    func 验证证书有效性(_ 证书: CA证书模型) -> (有效: Bool, 原因: String?) {
        证书服务.验证证书有效性(证书)
    }

    // MARK: - VPN 描述文件管理

    /// 添加描述文件
    func 添加描述文件(_ 描述文件: VPN描述文件模型) {
        描述文件列表.append(描述文件)
        _ = 描述文件服务.保存描述文件列表(描述文件列表)
    }

    /// 删除描述文件
    func 删除描述文件(_ 描述文件: VPN描述文件模型) {
        // 如果是已安装的，先移除
        if 描述文件.状态 == .已安装 || 描述文件.状态 == .已连接 || 描述文件.状态 == .已断开 {
            描述文件服务.移除VPN配置(描述文件) { _, _ in }
        }
        描述文件列表.removeAll { $0.id == 描述文件.id }
        _ = 描述文件服务.保存描述文件列表(描述文件列表)
    }

    /// 更新描述文件
    func 更新描述文件(_ 描述文件: VPN描述文件模型) {
        if let 索引 = 描述文件列表.firstIndex(where: { $0.id == 描述文件.id }) {
            描述文件列表[索引] = 描述文件
            _ = 描述文件服务.保存描述文件列表(描述文件列表)
        }
    }

    /// 安装 VPN 配置
    func 安装VPN配置(_ 描述文件: VPN描述文件模型, 完成: @escaping (描述文件安装结果) -> Void) {
        是否加载中 = true
        最近错误 = nil

        描述文件服务.安装PacketTunnel配置(描述文件) { [weak self] 结果 in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.是否加载中 = false
                if 结果.成功, let 安装后的描述文件 = 结果.描述文件 {
                    if let 索引 = self.描述文件列表.firstIndex(where: { $0.id == 描述文件.id }) {
                        self.描述文件列表[索引] = 安装后的描述文件
                    } else {
                        self.描述文件列表.append(安装后的描述文件)
                    }
                    _ = self.描述文件服务.保存描述文件列表(self.描述文件列表)
                } else {
                    self.最近错误 = 结果.错误信息
                }
                完成(结果)
            }
        }
    }

    /// 移除 VPN 配置
    func 移除VPN配置(_ 描述文件: VPN描述文件模型, 完成: @escaping (Bool, String?) -> Void) {
        描述文件服务.移除VPN配置(描述文件) { [weak self] 成功, 错误 in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if 成功 {
                    if let 索引 = self.描述文件列表.firstIndex(where: { $0.id == 描述文件.id }) {
                        self.描述文件列表[索引].状态 = .已移除
                        _ = self.描述文件服务.保存描述文件列表(self.描述文件列表)
                    }
                } else {
                    self.最近错误 = 错误
                }
                完成(成功, 错误)
            }
        }
    }

    /// 连接 VPN
    func 连接VPN() -> (成功: Bool, 错误: String?) {
        let 结果 = 描述文件服务.连接VPN()
        if 结果.成功 {
            VPN连接状态 = .connected
        }
        return 结果
    }

    /// 断开 VPN
    func 断开VPN() {
        描述文件服务.断开VPN()
        VPN连接状态 = .disconnected
    }

    /// 刷新连接状态
    func 刷新连接状态() {
        VPN连接状态 = 描述文件服务.获取连接状态()
    }

    /// 生成描述文件 URL
    func 生成描述文件URL(_ 描述文件: VPN描述文件模型) -> URL? {
        描述文件服务.保存描述文件到临时目录(描述文件)
    }

    // MARK: - 统计信息

    /// 证书总数
    var 证书总数: Int { 证书列表.count }

    /// 已安装证书数
    var 已安装证书数: Int { 证书列表.filter { $0.状态 == .已安装 || $0.状态 == .已信任 }.count }

    /// 即将过期证书数
    var 即将过期证书数: Int { 证书列表.filter { $0.是否即将过期 }.count }

    /// 描述文件总数
    var 描述文件总数: Int { 描述文件列表.count }

    /// 已安装描述文件数
    var 已安装描述文件数: Int { 描述文件列表.filter { $0.状态 == .已安装 || $0.状态 == .已连接 || $0.状态 == .已断开 }.count }

    // MARK: - 私有方法

    /// 监听连接状态变化
    private func 监听连接状态() {
        连接状态观察者 = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.刷新连接状态()
        }
    }
}
