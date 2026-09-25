//
//  网络活动管理器.swift
//  NewVPN
//
//  从 sing-box API 获取真实网络连接数据
//  定期轮询连接列表，更新 UI 显示
//

import Foundation

/// sing-box API 连接列表响应
struct SingBox连接列表响应: Codable {
    /// 连接列表
    let connections: [SingBox连接项]
}

/// sing-box API 单个连接项
struct SingBox连接项: Codable, Identifiable {
    /// 连接唯一标识
    let id: String
    /// 是否活跃
    let isActive: Bool?
    /// 连接元数据
    let metadata: SingBox连接元数据?
    /// 上行字节
    let upload: Int64?
    /// 下行字节
    let download: Int64?
    /// 开始时间
    let start: String?
    /// 出站链
    let chains: [String]?
    /// 匹配规则
    let rule: String?
    /// 规则负载
    let rulePayload: String?

    enum CodingKeys: String, CodingKey {
        case id
        case isActive
        case metadata
        case upload
        case download
        case start
        case chains
        case rule
        case rulePayload
    }
}

/// sing-box API 连接元数据
struct SingBox连接元数据: Codable {
    /// 网络协议（tcp/udp）
    let network: String?
    /// 源 IP
    let sourceIP: String?
    /// 源端口
    let sourcePort: String?
    /// 目标 IP
    let destinationIP: String?
    /// 目标端口
    let destinationPort: String?
    /// 主机名
    let host: String?
    /// 嗅探主机名
    let sniffHost: String?
    /// 进程路径
    let processPath: String?
    /// 进程名
    let processName: String?

    enum CodingKeys: String, CodingKey {
        case network
        case sourceIP
        case sourcePort
        case destinationIP
        case destinationPort
        case host
        case sniffHost
        case processPath
        case processName
    }
}

/// 网络活动管理器
/// 从 sing-box API 定期获取连接列表，更新 AppState
final class 网络活动管理器 {
    /// 单例
    static let 共享 = 网络活动管理器()

    /// sing-box API 地址
    private let api地址 = "http://127.0.0.1:9090"

    /// 轮询定时器
    private var 轮询定时器: Timer?

    /// 私有初始化
    private init() {}

    // MARK: - 开始/停止轮询

    /// 开始定期轮询连接列表
    func 开始轮询(间隔: TimeInterval = 2.0) {
        停止轮询()
        轮询定时器 = Timer.scheduledTimer(withTimeInterval: 间隔, repeats: true) { [weak self] _ in
            self?.获取连接列表()
        }
        // 立即获取一次
        获取连接列表()
    }

    /// 停止轮询
    func 停止轮询() {
        轮询定时器?.invalidate()
        轮询定时器 = nil
    }

    // MARK: - 获取连接列表

    /// 从 sing-box API 获取当前连接列表
    func 获取连接列表() {
        guard let url = URL(string: "\(api地址)/connections") else { return }

        let 任务 = URLSession.shared.dataTask(with: url) { [weak self] 数据, 响应, 错误 in
            guard let 数据 = 数据, 错误 == nil else {
                return
            }
            self?.解析连接列表(数据)
        }
        任务.resume()
    }

    /// 解析连接列表响应
    private func 解析连接列表(_ 数据: Data) {
        let 解码器 = JSONDecoder()
        解码器.dateDecodingStrategy = .iso8601

        guard let 响应 = try? 解码器.decode(SingBox连接列表响应.self, from: 数据) else {
            return
        }

        // 转换为 AppState 使用的网络连接模型
        let 连接列表 = 响应.connections.enumerated().map { (索引, 项) -> 网络连接模型 in
            let 域名 = 项.metadata?.sniffHost ?? 项.metadata?.host
            let 出站策略 = 项.chains?.first ?? "未知"
            let 开始时间 = 解析时间(项.start)

            return 网络连接模型(
                id: UUID(uuidString: 项.id) ?? UUID(),
                序号: 索引 + 1,
                协议: (项.metadata?.network ?? "tcp").uppercased(),
                本地地址: 项.metadata?.sourceIP ?? "",
                本地端口: Int(项.metadata?.sourcePort ?? "0") ?? 0,
                远程地址: 项.metadata?.destinationIP ?? "",
                远程端口: Int(项.metadata?.destinationPort ?? "0") ?? 0,
                域名: 域名,
                国家地区: nil,
                出站策略: 出站策略,
                开始时间: 开始时间,
                已关闭: !(项.isActive ?? true),
                上行字节: 项.upload ?? 0,
                下行字节: 项.download ?? 0,
                状态码: nil,
                匹配规则: 项.rule
            )
        }

        // 在主线程更新 UI
        DispatchQueue.main.async {
            AppState.共享.网络连接列表 = 连接列表
        }
    }

    /// 解析 ISO8601 时间字符串
    private func 解析时间(_ 字符串: String?) -> Date {
        guard let 字符串 = 字符串 else { return Date() }
        let 格式器 = ISO8601DateFormatter()
        格式器.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return 格式器.date(from: 字符串) ?? Date()
    }
}
