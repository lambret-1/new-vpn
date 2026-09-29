//
//  规则集生成器.swift
//  NewVPN
//
//  将分流规则拆分为 sing-box 本地规则集文件，减少内核内存占用
//  域名类规则和IP类规则分别生成规则集，其他类型保持内联
//

import Foundation

/// 规则集生成器：将分流规则转换为 sing-box source 格式规则集文件
final class 规则集生成器 {
    /// 共享单例
    static let 共享 = 规则集生成器()

    /// App Group 共享目录
    private var 共享目录: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.newvpn.app")
    }

    /// 规则集文件存储子目录
    private let 规则集目录名 = "rule_sets"

    /// 私有初始化
    private init() {}

    // MARK: - 生成规则集

    /// 生成本地规则集文件
    /// - Parameter 规则列表: 分流规则列表
    /// - Returns: 生成的规则集标签列表（按动作+类型分组）
    @discardableResult
    func 生成规则集(规则列表: [分流规则项]) -> [规则集信息] {
        guard let 目录 = 获取规则集目录() else { return [] }

        // 按动作+类型分组
        var 代理域名: [SingBox源规则] = []
        var 直连域名: [SingBox源规则] = []
        var 拦截域名: [SingBox源规则] = []
        var 代理IP: [SingBox源规则] = []
        var 直连IP: [SingBox源规则] = []
        var 拦截IP: [SingBox源规则] = []

        for 规则 in 规则列表 where 规则.启用 {
            guard let 源规则 = 转换为源规则(规则) else { continue }

            switch 规则.动作 {
            case .代理:
                if 源规则.is域名类 {
                    代理域名.append(源规则)
                } else if 源规则.isIP类 {
                    代理IP.append(源规则)
                }
            case .直连:
                if 源规则.is域名类 {
                    直连域名.append(源规则)
                } else if 源规则.isIP类 {
                    直连IP.append(源规则)
                }
            case .拦截, .拒绝:
                if 源规则.is域名类 {
                    拦截域名.append(源规则)
                } else if 源规则.isIP类 {
                    拦截IP.append(源规则)
                }
            case .全局代理, .放行:
                break // 不生成规则集
            }
        }

        var 生成的规则集: [规则集信息] = []

        // 写入规则集文件
        if !代理域名.isEmpty {
            if 写入规则集文件(目录: 目录, 文件名: "proxy-domain.json", 规则: 代理域名) {
                生成的规则集.append(规则集信息(标签: "proxy-domain", 文件名: "proxy-domain.json", 出站: "proxy"))
            }
        }
        if !直连域名.isEmpty {
            if 写入规则集文件(目录: 目录, 文件名: "direct-domain.json", 规则: 直连域名) {
                生成的规则集.append(规则集信息(标签: "direct-domain", 文件名: "direct-domain.json", 出站: "DIRECT"))
            }
        }
        if !拦截域名.isEmpty {
            if 写入规则集文件(目录: 目录, 文件名: "reject-domain.json", 规则: 拦截域名) {
                生成的规则集.append(规则集信息(标签: "reject-domain", 文件名: "reject-domain.json", 出站: "REJECT"))
            }
        }
        if !代理IP.isEmpty {
            if 写入规则集文件(目录: 目录, 文件名: "proxy-ip.json", 规则: 代理IP) {
                生成的规则集.append(规则集信息(标签: "proxy-ip", 文件名: "proxy-ip.json", 出站: "proxy"))
            }
        }
        if !直连IP.isEmpty {
            if 写入规则集文件(目录: 目录, 文件名: "direct-ip.json", 规则: 直连IP) {
                生成的规则集.append(规则集信息(标签: "direct-ip", 文件名: "direct-ip.json", 出站: "DIRECT"))
            }
        }
        if !拦截IP.isEmpty {
            if 写入规则集文件(目录: 目录, 文件名: "reject-ip.json", 规则: 拦截IP) {
                生成的规则集.append(规则集信息(标签: "reject-ip", 文件名: "reject-ip.json", 出站: "REJECT"))
            }
        }

        return 生成的规则集
    }

    /// 获取所有已生成的规则集信息
    func 获取所有规则集() -> [规则集信息] {
        guard let 目录 = 获取规则集目录() else { return [] }
        let 文件管理器 = FileManager.default
        guard let 文件列表 = try? 文件管理器.contentsOfDirectory(at: 目录, includingPropertiesForKeys: nil) else { return [] }

        var 规则集列表: [规则集信息] = []
        for 文件 in 文件列表 where 文件.pathExtension == "json" {
            let 文件名 = 文件.lastPathComponent
            let 标签 = 文件名.replacingOccurrences(of: ".json", with: "")
            let 出站: String
            if 标签.hasPrefix("proxy") { 出站 = "proxy" }
            else if 标签.hasPrefix("direct") { 出站 = "DIRECT" }
            else if 标签.hasPrefix("reject") { 出站 = "REJECT" }
            else { continue }
            规则集列表.append(规则集信息(标签: 标签, 文件名: 文件名, 出站: 出站))
        }
        return 规则集列表
    }

    /// 获取规则集文件完整路径
    func 获取规则集路径(文件名: String) -> String? {
        guard let 目录 = 获取规则集目录() else { return nil }
        return 目录.appendingPathComponent(文件名).path
    }

    // MARK: - 私有方法

    /// 获取规则集目录（不存在则创建）
    private func 获取规则集目录() -> URL? {
        guard let 共享目录 = 共享目录 else { return nil }
        let 目录 = 共享目录.appendingPathComponent(规则集目录名, isDirectory: true)
        let 文件管理器 = FileManager.default
        if !文件管理器.fileExists(atPath: 目录.path) {
            try? 文件管理器.createDirectory(at: 目录, withIntermediateDirectories: true)
        }
        return 目录
    }

    /// 将分流规则转换为 sing-box 源规则
    /// 注意：sing-box source 格式要求所有字段为数组
    private func 转换为源规则(_ 规则: 分流规则项) -> SingBox源规则? {
        switch 规则.类型 {
        case .域名精确:
            return SingBox源规则(domain: [规则.匹配值])
        case .域名后缀:
            return SingBox源规则(domainSuffix: [规则.匹配值])
        case .域名关键词:
            return SingBox源规则(domainKeyword: [规则.匹配值])
        case .正则表达式:
            return SingBox源规则(domainRegex: [规则.匹配值])
        case .IP地址:
            return SingBox源规则(ipCidr: ["\(规则.匹配值)/32"])
        case .IP段:
            return SingBox源规则(ipCidr: [规则.匹配值])
        default:
            return nil // 其他类型不生成规则集，保持内联
        }
    }

    /// 写入规则集文件（source 格式）
    private func 写入规则集文件(目录: URL, 文件名: String, 规则: [SingBox源规则]) -> Bool {
        let 规则集 = SingBox源规则集(version: 1, rules: 规则)
        guard let 数据 = try? JSONEncoder().encode(规则集) else { return false }
        let 文件路径 = 目录.appendingPathComponent(文件名)
        do {
            try 数据.write(to: 文件路径, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - 数据模型

/// 规则集信息
struct 规则集信息: Hashable {
    /// 规则集标签
    let 标签: String
    /// 文件名
    let 文件名: String
    /// 对应出站
    let 出站: String
}

/// sing-box source 格式规则集
struct SingBox源规则集: Codable {
    /// 版本号
    let version: Int
    /// 规则列表
    let rules: [SingBox源规则]
}

/// sing-box 源规则（仅支持域名和IP类）
/// 注意：sing-box source 格式要求所有字段为数组，不能是单个字符串
struct SingBox源规则: Codable, Hashable {
    /// 精确域名列表
    var domain: [String]?
    /// 域名后缀列表
    var domainSuffix: [String]?
    /// 域名关键词列表
    var domainKeyword: [String]?
    /// 域名正则列表
    var domainRegex: [String]?
    /// IP CIDR 列表
    var ipCidr: [String]?

    /// 是否域名类规则
    var is域名类: Bool {
        domain != nil || domainSuffix != nil || domainKeyword != nil || domainRegex != nil
    }

    /// 是否IP类规则
    var isIP类: Bool {
        ipCidr != nil
    }

    enum CodingKeys: String, CodingKey {
        case domain
        case domainSuffix = "domain_suffix"
        case domainKeyword = "domain_keyword"
        case domainRegex = "domain_regex"
        case ipCidr = "ip_cidr"
    }
}
