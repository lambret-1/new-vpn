//
//  策略组管理器.swift
//  NewVPN
//
//  从 sing-box Clash API 获取策略组（selector/urltest）实时数据
//  支持节点列表、延迟测速、手动切换、自动测速
//

import Foundation

/// Clash API 代理列表响应
struct Clash代理列表响应: Codable {
    /// 代理字典（名称: 代理详情）
    let proxies: [String: Clash代理项]
}

/// Clash API 单个代理项
struct Clash代理项: Codable {
    /// 代理名称
    let name: String
    /// 代理类型（Selector/URLTest/Shadowsocks/VLESS等）
    let type: String
    /// 当前选中节点（仅 Selector/URLTest 有）
    let now: String?
    /// 组内节点列表（仅 Selector/URLTest 有）
    let all: [String]?
    /// 历史延迟记录
    let history: [Clash延迟记录]?
    /// 是否为 UDP 支持
    let udp: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case now
        case all
        case history
        case udp
    }
}

/// Clash API 延迟记录
struct Clash延迟记录: Codable {
    /// 延迟（毫秒）
    let delay: Int
    /// 记录时间
    let time: String
}

/// 策略组管理器
/// 从 Clash API 定期获取策略组数据，支持切换节点和测速
final class 策略组管理器 {
    /// 单例
    static let 共享 = 策略组管理器()

    /// Clash API 地址
    private let api地址 = "http://127.0.0.1:9090"

    /// 轮询定时器
    private var 轮询定时器: Timer?

    /// 私有初始化
    private init() {}

    // MARK: - 开始/停止轮询

    /// 开始定期轮询策略组数据
    func 开始轮询() {
        停止轮询()
        刷新策略组()
        轮询定时器 = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.刷新策略组()
        }
    }

    /// 停止轮询
    func 停止轮询() {
        轮询定时器?.invalidate()
        轮询定时器 = nil
    }

    // MARK: - 刷新策略组

    /// 从 Clash API 刷新策略组列表
    func 刷新策略组() {
        guard let url = URL(string: "\(api地址)/proxies") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] 数据, 响应, 错误 in
            guard let 数据 = 数据, 错误 == nil else { return }

            do {
                let 响应 = try JSONDecoder().decode(Clash代理列表响应.self, from: 数据)
                self?.处理代理列表(响应.proxies)
            } catch {
                // 解析失败静默处理，API 可能未就绪
            }
        }.resume()
    }

    /// 处理代理列表，提取策略组
    private func 处理代理列表(_ 代理字典: [String: Clash代理项]) {
        var 策略组列表: [策略组模型] = []

        for (名称, 代理) in 代理字典 {
            let 类型大写 = 代理.type.uppercased()
            // 只提取 Selector 和 URLTest 类型的策略组
            guard 类型大写 == "SELECTOR" || 类型大写 == "URLTEST" else { continue }

            let 节点列表 = 代理.all ?? []
            let 当前选中 = 代理.now ?? ""
            let 类型 = 类型大写 == "SELECTOR" ? "selector" : "urltest"

            // 构建节点延迟字典
            var 节点延迟: [String: Int] = [:]
            for 节点名 in 节点列表 {
                if let 节点代理 = 代理字典[节点名],
                   let 最新延迟 = 节点代理.history?.last?.delay {
                    节点延迟[节点名] = 最新延迟
                }
            }

            let 组 = 策略组模型(
                名称: 名称,
                类型: 类型,
                当前选中: 当前选中,
                节点数量: 节点列表.count,
                节点列表: 节点列表,
                节点延迟: 节点延迟
            )
            策略组列表.append(组)
        }

        // 按名称排序，selector 在前
        策略组列表.sort { 组1, 组2 in
            if 组1.类型 != 组2.类型 {
                return 组1.类型 == "selector"
            }
            return 组1.名称 < 组2.名称
        }

        DispatchQueue.main.async {
            // 保留旧列表中的展开状态
            let 旧列表 = AppState.共享.策略组列表
            for 索引 in 策略组列表.indices {
                if let 旧组 = 旧列表.first(where: { $0.名称 == 策略组列表[索引].名称 }) {
                    策略组列表[索引].是否展开 = 旧组.是否展开
                }
            }
            AppState.共享.策略组列表 = 策略组列表
        }
    }

    // MARK: - 切换节点

    /// 切换策略组选中节点
    /// - Parameters:
    ///   - 组名: 策略组名称
    ///   - 节点名: 目标节点名称
    ///   - 完成: 完成回调
    func 切换节点(组名: String, 节点名: String, 完成: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "\(api地址)/proxies/\(组名.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? 组名)") else {
            完成?(false)
            return
        }

        var 请求 = URLRequest(url: url)
        请求.httpMethod = "PUT"
        请求.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let 参数: [String: String] = ["name": 节点名]
        请求.httpBody = try? JSONSerialization.data(withJSONObject: 参数)

        URLSession.shared.dataTask(with: 请求) { 数据, 响应, 错误 in
            let 成功 = 错误 == nil && (响应 as? HTTPURLResponse)?.statusCode == 204
            DispatchQueue.main.async {
                if 成功 {
                    // 切换成功后立即刷新
                    self.刷新策略组()
                }
                完成?(成功)
            }
        }.resume()
    }

    // MARK: - 测速

    /// 对策略组内节点进行延迟测速
    /// - Parameters:
    ///   - 组名: 策略组名称
    ///   - 完成: 完成回调，返回各节点延迟
    func 测速(组名: String, 完成: (([String: Int]) -> Void)? = nil) {
        guard let url = URL(string: "\(api地址)/proxies/\(组名.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? 组名)/delay?timeout=5000&url=http://www.gstatic.com/generate_204") else {
            完成?([:])
            return
        }

        URLSession.shared.dataTask(with: url) { 数据, 响应, 错误 in
            guard let 数据 = 数据, 错误 == nil else {
                DispatchQueue.main.async { 完成?([:]) }
                return
            }

            do {
                let 结果 = try JSONDecoder().decode([String: Int].self, from: 数据)
                DispatchQueue.main.async {
                    完成?(结果)
                    self.刷新策略组()
                }
            } catch {
                DispatchQueue.main.async { 完成?([:]) }
            }
        }.resume()
    }

    /// 对单个节点进行延迟测速
    /// - Parameters:
    ///   - 节点名: 节点名称
    ///   - 完成: 完成回调，返回延迟（毫秒），失败返回 nil
    func 测速单个节点(节点名: String, 完成: ((Int?) -> Void)? = nil) {
        let 编码名 = 节点名.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? 节点名
        guard let url = URL(string: "\(api地址)/proxies/\(编码名)/delay?timeout=5000&url=http://www.gstatic.com/generate_204") else {
            完成?(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { 数据, 响应, 错误 in
            guard let 数据 = 数据, 错误 == nil else {
                DispatchQueue.main.async { 完成?(nil) }
                return
            }

            do {
                let 结果 = try JSONDecoder().decode(Clash延迟记录.self, from: 数据)
                DispatchQueue.main.async {
                    完成?(结果.delay)
                    self.刷新策略组()
                }
            } catch {
                DispatchQueue.main.async { 完成?(nil) }
            }
        }.resume()
    }
}
