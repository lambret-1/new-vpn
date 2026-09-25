//
//  DNS管理器.swift
//  NewVPN
//
//  DNS 管理器：配置管理、查询日志、批量测速、泄漏检测
//

import Foundation
import Combine

// MARK: - DNS 管理器

/// DNS 全局管理器
final class DNS管理器: ObservableObject {
    /// 共享单例
    static let 共享 = DNS管理器()

    // MARK: - 配置状态

    /// DNS 配置
    @Published var 配置: DNS配置模型 = .默认

    /// DNS 查询记录列表
    @Published var 查询记录列表: [DNS记录模型] = []

    /// 是否正在测速
    @Published var 是否测速中 = false

    /// 当前测速的服务器名称
    @Published var 当前测速服务器: String?

    /// 泄漏检测结果
    @Published var 泄漏检测结果: DNS泄漏检测结果?

    /// 是否正在进行泄漏检测
    @Published var 是否泄漏检测中 = false

    // MARK: - 持久化

    /// 配置存储键
    private let 配置存储键 = "DNS配置"
    /// 记录存储键
    private let 记录存储键 = "DNS查询记录"
    /// App Group 标识
    private let AppGroup标识 = "group.com.newvpn.app"
    /// 刷新定时器
    private var 刷新定时器: Timer?

    /// 私有初始化
    private init() {
        加载配置()
        加载查询记录()
        启动扩展记录同步()
    }

    // MARK: - 扩展 DNS 记录同步

    /// 启动定时同步扩展进程的 DNS 查询记录
    private func 启动扩展记录同步() {
        刷新定时器 = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.同步扩展DNS记录()
        }
        同步扩展DNS记录()
    }

    /// 从 App Group 同步扩展进程的 DNS 查询记录
    func 同步扩展DNS记录() {
        guard let 共享默认 = UserDefaults(suiteName: AppGroup标识),
              let 记录列表 = 共享默认.array(forKey: "dnsQueryRecords") as? [[String: Any]] else {
            return
        }

        let 新记录 = 记录列表.compactMap { 字典 -> DNS记录模型? in
            guard let 域名 = 字典["域名"] as? String,
                  let 记录类型字符串 = 字典["记录类型"] as? String else {
                return nil
            }
            let 记录类型 = DNS记录类型(rawValue: 记录类型字符串) ?? .A
            let 解析结果 = 字典["解析结果"] as? [String] ?? []
            let TTL = 字典["TTL"] as? Int ?? 300
            let 时间戳 = 字典["查询时间"] as? TimeInterval ?? Date().timeIntervalSince1970
            let 响应时间 = 字典["响应时间"] as? Int ?? 0
            let DNS服务器 = 字典["DNS服务器"] as? String ?? "sing-box"
            let 来源字符串 = 字典["来源"] as? String ?? "远程"
            let 来源 = DNS来源(rawValue: 来源字符串) ?? .远程

            return DNS记录模型(
                域名: 域名,
                记录类型: 记录类型,
                解析结果: 解析结果,
                TTL: TTL,
                查询时间: Date(timeIntervalSince1970: 时间戳),
                响应时间: 响应时间,
                DNS服务器: DNS服务器,
                来源: 来源
            )
        }

        // 合并去重（按域名+查询时间）
        let 现有域名时间 = Set(查询记录列表.map { "\($0.域名)_\($0.查询时间.timeIntervalSince1970)" })
        let 去重新记录 = 新记录.filter { 记录 in
            !现有域名时间.contains("\(记录.域名)_\(记录.查询时间.timeIntervalSince1970)")
        }

        if !去重新记录.isEmpty {
            查询记录列表 = (去重新记录 + 查询记录列表).prefix(200).map { $0 }
            保存查询记录()
        }
    }

    // MARK: - 配置管理

    /// 加载配置
    private func 加载配置() {
        if let 数据 = UserDefaults.standard.data(forKey: 配置存储键),
           let 解码配置 = try? JSONDecoder().decode(DNS配置模型.self, from: 数据) {
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

    // MARK: - DNS 服务器管理

    /// 添加 DNS 服务器
    func 添加服务器(_ 服务器: DNS服务器模型) {
        配置.服务器列表.append(服务器)
        保存配置()
    }

    /// 删除 DNS 服务器
    func 删除服务器(_ 服务器: DNS服务器模型) {
        配置.服务器列表.removeAll { $0.id == 服务器.id }
        保存配置()
    }

    /// 切换服务器启用状态
    func 切换服务器启用(_ 服务器: DNS服务器模型) {
        if let 索引 = 配置.服务器列表.firstIndex(where: { $0.id == 服务器.id }) {
            配置.服务器列表[索引].启用.toggle()
            保存配置()
        }
    }

    /// 移动服务器顺序
    func 移动服务器(从源索引: IndexSet, 到目标索引: Int) {
        配置.服务器列表.move(fromOffsets: 从源索引, toOffset: 到目标索引)
        保存配置()
    }

    // MARK: - DNS 查询

    /// 执行 DNS 查询并记录
    @discardableResult
    func 查询域名(_ 域名: String, 记录类型: DNS记录类型 = .A) -> [String] {
        let 开始时间 = Date()

        // 检查自定义 hosts
        if let hosts记录 = 配置.自定义Hosts.first(where: { $0.启用 && $0.域名 == 域名 }) {
            let 记录 = DNS记录模型(
                域名: 域名,
                记录类型: .A,
                解析结果: [hosts记录.IP地址],
                TTL: 3600,
                查询时间: Date(),
                响应时间: 1,
                DNS服务器: "自定义Hosts",
                来源: .直连
            )
            添加查询记录(记录)
            return [hosts记录.IP地址]
        }

        // 检查过滤规则
        if 配置.启用过滤 {
            for 规则 in 配置.广告拦截规则 where 规则.启用 {
                if 匹配过滤规则(规则, 域名: 域名) {
                    let 记录 = DNS记录模型(
                        域名: 域名,
                        记录类型: 记录类型,
                        解析结果: 规则.动作 == .重定向 ? [规则.重定向地址 ?? "0.0.0.0"] : [],
                        TTL: 60,
                        查询时间: Date(),
                        响应时间: 1,
                        DNS服务器: "过滤规则",
                        来源: .拦截,
                        是否被拦截: 规则.动作 == .拦截,
                        拦截规则: 规则.名称
                    )
                    添加查询记录(记录)
                    return 记录.解析结果
                }
            }
        }

        // 执行实际查询
        let 服务器 = 配置.启用服务器.first?.地址显示 ?? "系统"
        let 结果 = DNS服务.共享.解析域名(域名, 记录类型: 记录类型, DNS服务器: 配置.启用自定义DNS ? 服务器 : nil)

        let 响应时间 = Int(Date().timeIntervalSince(开始时间) * 1000)

        let 记录 = DNS记录模型(
            域名: 域名,
            记录类型: 记录类型,
            解析结果: 结果,
            TTL: 300,
            查询时间: Date(),
            响应时间: 响应时间,
            DNS服务器: 服务器,
            来源: 配置.启用自定义DNS ? .远程 : .直连
        )
        添加查询记录(记录)

        return 结果
    }

    /// 匹配过滤规则
    private func 匹配过滤规则(_ 规则: DNS过滤规则, 域名: String) -> Bool {
        switch 规则.匹配类型 {
        case .域名精确:
            return 域名 == 规则.匹配值
        case .域名后缀:
            return 域名.hasSuffix(规则.匹配值) || 域名 == 规则.匹配值
        case .域名关键词:
            return 域名.contains(规则.匹配值)
        case .正则表达式:
            if let 正则 = try? NSRegularExpression(pattern: 规则.匹配值) {
                let 范围 = NSRange(域名.startIndex..., in: 域名)
                return 正则.firstMatch(in: 域名, range: 范围) != nil
            }
            return false
        }
    }

    // MARK: - 查询记录管理

    /// 添加查询记录
    private func 添加查询记录(_ 记录: DNS记录模型) {
        guard 配置.记录查询日志 else { return }

        查询记录列表.insert(记录, at: 0)

        // 限制记录数量
        if 查询记录列表.count > 配置.最大日志条数 {
            查询记录列表.removeLast(查询记录列表.count - 配置.最大日志条数)
        }

        保存查询记录()
    }

    /// 清除查询记录
    func 清除查询记录() {
        查询记录列表.removeAll()
        UserDefaults.standard.removeObject(forKey: 记录存储键)
    }

    /// 保存查询记录
    private func 保存查询记录() {
        if let 数据 = try? JSONEncoder().encode(查询记录列表) {
            UserDefaults.standard.set(数据, forKey: 记录存储键)
        }
    }

    /// 加载查询记录
    private func 加载查询记录() {
        if let 数据 = UserDefaults.standard.data(forKey: 记录存储键),
           let 记录 = try? JSONDecoder().decode([DNS记录模型].self, from: 数据) {
            查询记录列表 = 记录
        }
    }

    // MARK: - DNS 服务器测速

    /// 测速所有启用的 DNS 服务器
    func 测速所有服务器() {
        guard !是否测速中 else { return }

        是否测速中 = true
        let 服务器列表 = 配置.服务器列表

        DispatchQueue.global(qos: .userInitiated).async {
            for (索引, 服务器) in 服务器列表.enumerated() {
                DispatchQueue.main.async {
                    self.当前测速服务器 = 服务器.名称
                }

                let 延迟 = DNS服务.共享.测试服务器延迟(服务器)

                DispatchQueue.main.async {
                    if let 配置索引 = self.配置.服务器列表.firstIndex(where: { $0.id == 服务器.id }) {
                        self.配置.服务器列表[配置索引].测速延迟 = 延迟
                    }
                }

                // 避免过快
                Thread.sleep(forTimeInterval: 0.2)
            }

            DispatchQueue.main.async {
                self.是否测速中 = false
                self.当前测速服务器 = nil
                self.保存配置()
            }
        }
    }

    /// 测速单个 DNS 服务器
    func 测速服务器(_ 服务器: DNS服务器模型) {
        DispatchQueue.global(qos: .userInitiated).async {
            let 延迟 = DNS服务.共享.测试服务器延迟(服务器)

            DispatchQueue.main.async {
                if let 索引 = self.配置.服务器列表.firstIndex(where: { $0.id == 服务器.id }) {
                    self.配置.服务器列表[索引].测速延迟 = 延迟
                    self.保存配置()
                }
            }
        }
    }

    // MARK: - DNS 泄漏检测

    /// 执行 DNS 泄漏检测
    func 执行泄漏检测() {
        guard !是否泄漏检测中 else { return }

        是否泄漏检测中 = true

        DispatchQueue.global(qos: .userInitiated).async {
            let 预期服务器 = self.配置.启用服务器.map { $0.地址显示 }
            let 结果 = DNS服务.共享.泄漏检测(预期服务器: 预期服务器)

            DispatchQueue.main.async {
                self.泄漏检测结果 = 结果
                self.是否泄漏检测中 = false
            }
        }
    }

    // MARK: - 自定义 Hosts 管理

    /// 添加自定义 hosts
    func 添加Hosts(_ 条目: 自定义Hosts条目) {
        配置.自定义Hosts.append(条目)
        保存配置()
    }

    /// 删除自定义 hosts
    func 删除Hosts(_ 条目: 自定义Hosts条目) {
        配置.自定义Hosts.removeAll { $0.id == 条目.id }
        保存配置()
    }

    // MARK: - 过滤规则管理

    /// 添加过滤规则
    func 添加过滤规则(_ 规则: DNS过滤规则) {
        配置.广告拦截规则.append(规则)
        保存配置()
    }

    /// 删除过滤规则
    func 删除过滤规则(_ 规则: DNS过滤规则) {
        配置.广告拦截规则.removeAll { $0.id == 规则.id }
        保存配置()
    }

    // MARK: - 统计

    /// 查询统计
    var 查询统计: (总数: Int, 拦截数: Int, 缓存命中数: Int, 今日查询数: Int) {
        let 总数 = 查询记录列表.count
        let 拦截数 = 查询记录列表.filter { $0.是否被拦截 }.count
        let 缓存命中数 = 查询记录列表.filter { $0.来源 == .缓存 }.count
        let 今日查询数 = 查询记录列表.filter {
            Calendar.current.isDateInToday($0.查询时间)
        }.count
        return (总数, 拦截数, 缓存命中数, 今日查询数)
    }
}
