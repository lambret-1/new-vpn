//
//  证书与描述文件模型.swift
//  NewVPN
//
//  CA 证书和 VPN 描述文件数据模型
//

import Foundation

// MARK: - 证书类型

/// 证书类型
enum 证书类型: String, Codable, CaseIterable {
    /// 根证书
    case 根证书 = "根证书"
    /// 中间证书
    case 中间证书 = "中间证书"
    /// 客户端证书
    case 客户端证书 = "客户端证书"
    /// 服务器证书
    case 服务器证书 = "服务器证书"

    /// 显示图标
    var 图标: String {
        switch self {
        case .根证书: return "shield.fill"
        case .中间证书: return "shield.lefthalf.filled"
        case .客户端证书: return "person.crop.circle"
        case .服务器证书: return "server.rack"
        }
    }
}

// MARK: - 证书格式

/// 证书格式
enum 证书格式: String, Codable, CaseIterable {
    /// PEM 格式
    case pem = "PEM"
    /// DER 格式
    case der = "DER"
    /// PKCS12 格式
    case p12 = "PKCS12"

    /// 文件扩展名
    var 文件扩展名: String {
        switch self {
        case .pem: return "pem"
        case .der: return "cer"
        case .p12: return "p12"
        }
    }
}

// MARK: - 证书状态

/// 证书状态
enum 证书状态: String, Codable, CaseIterable {
    /// 未安装
    case 未安装 = "未安装"
    /// 已安装
    case 已安装 = "已安装"
    /// 已信任
    case 已信任 = "已信任"
    /// 已过期
    case 已过期 = "已过期"
    /// 已撤销
    case 已撤销 = "已撤销"

    /// 状态颜色
    var 状态颜色: String {
        switch self {
        case .已安装, .已信任: return "成功色"
        case .未安装: return "次要文字"
        case .已过期, .已撤销: return "危险色"
        }
    }
}

// MARK: - CA 证书模型

/// CA 证书数据模型
struct CA证书模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 证书名称
    var 名称: String
    /// 证书类型
    var 类型: 证书类型
    /// 证书格式
    var 格式: 证书格式
    /// 证书状态
    var 状态: 证书状态
    /// 证书数据（Base64 编码）
    var 证书数据: String
    /// 颁发者
    var 颁发者: String
    /// 主题
    var 主题: String
    /// 序列号
    var 序列号: String
    /// 生效日期
    var 生效日期: Date
    /// 过期日期
    var 过期日期: Date
    /// SHA1 指纹
    var SHA1指纹: String
    /// SHA256 指纹
    var SHA256指纹: String
    /// 公钥算法
    var 公钥算法: String
    /// 公钥长度
    var 公钥长度: Int
    /// 签名算法
    var 签名算法: String
    /// 是否用于 MITM
    var 用于MITM: Bool
    /// 是否用于 TLS 验证
    var 用于TLS验证: Bool
    /// 导入时间
    let 导入时间: Date
    /// 安装时间
    var 安装时间: Date?
    /// 备注
    var 备注: String?
    /// 标签
    var 标签: [String]

    /// 是否即将过期（30天内）
    var 是否即将过期: Bool {
        let 剩余天数 = Calendar.current.dateComponents([.day], from: Date(), to: 过期日期).day ?? 0
        return 剩余天数 <= 30 && 剩余天数 > 0
    }

    /// 是否已过期
    var 是否已过期: Bool {
        Date() > 过期日期
    }

    /// 剩余天数
    var 剩余天数: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: 过期日期).day ?? 0
    }

    /// 有效期显示
    var 有效期显示: String {
        let 格式化 = DateFormatter()
        格式化.dateFormat = "yyyy-MM-dd"
        return "\(格式化.string(from: 生效日期)) ~ \(格式化.string(from: 过期日期))"
    }

    /// 剩余时间显示
    var 剩余时间显示: String {
        if 是否已过期 {
            return "已过期"
        }
        let 天数 = 剩余天数
        if 天数 < 1 {
            return "即将过期"
        } else if 天数 < 30 {
            return "剩余 \(天数) 天"
        } else if 天数 < 365 {
            return "剩余 \(天数 / 30) 个月"
        } else {
            return "剩余 \(天数 / 365) 年"
        }
    }

    /// 指纹显示（前8位后4位）
    var 指纹显示: String {
        let 指纹 = SHA256指纹.replacingOccurrences(of: ":", with: "")
        guard 指纹.count >= 12 else { return 指纹 }
        let 前缀 = String(指纹.prefix(8))
        let 后缀 = String(指纹.suffix(4))
        return "\(前缀)...\(后缀)"
    }

    /// 默认证书
    static func 默认证书() -> CA证书模型 {
        CA证书模型(
            id: UUID(),
            名称: "NewVPN MITM 根证书",
            类型: .根证书,
            格式: .pem,
            状态: .未安装,
            证书数据: "",
            颁发者: "NewVPN MITM CA",
            主题: "NewVPN MITM CA",
            序列号: "1",
            生效日期: Date(),
            过期日期: Calendar.current.date(byAdding: .year, value: 10, to: Date()) ?? Date(),
            SHA1指纹: "",
            SHA256指纹: "",
            公钥算法: "RSA",
            公钥长度: 2048,
            签名算法: "SHA256WithRSA",
            用于MITM: true,
            用于TLS验证: false,
            导入时间: Date(),
            安装时间: nil,
            备注: "用于 HTTPS 抓包和 MITM 代理的根证书",
            标签: ["MITM", "内置"]
        )
    }
}

// MARK: - VPN 描述文件类型

/// VPN 描述文件类型
enum VPN描述文件类型: String, Codable, CaseIterable {
    /// IPSec
    case ipsec = "IPSec"
    /// IKEv2
    case ikev2 = "IKEv2"
    /// WireGuard
    case wireguard = "WireGuard"
    /// 自定义协议（PacketTunnel）
    case 自定义 = "自定义协议"

    /// 显示图标
    var 图标: String {
        switch self {
        case .ipsec: return "lock.shield"
        case .ikev2: return "lock.shield.fill"
        case .wireguard: return "bolt.shield"
        case .自定义: return "gearshape.2"
        }
    }
}

// MARK: - VPN 描述文件状态

/// VPN 描述文件状态
enum VPN描述文件状态: String, Codable, CaseIterable {
    /// 未安装
    case 未安装 = "未安装"
    /// 已安装
    case 已安装 = "已安装"
    /// 已连接
    case 已连接 = "已连接"
    /// 已断开
    case 已断开 = "已断开"
    /// 安装失败
    case 安装失败 = "安装失败"
    /// 已移除
    case 已移除 = "已移除"

    /// 状态颜色
    var 状态颜色: String {
        switch self {
        case .已安装, .已断开: return "成功色"
        case .已连接: return "主题色"
        case .未安装: return "次要文字"
        case .安装失败, .已移除: return "危险色"
        }
    }
}

// MARK: - VPN 描述文件模型

/// VPN 描述文件数据模型
struct VPN描述文件模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 描述文件名称
    var 名称: String
    /// 描述文件类型
    var 类型: VPN描述文件类型
    /// 描述文件状态
    var 状态: VPN描述文件状态
    /// Bundle Identifier（PacketTunnel 扩展）
    var 扩展BundleID: String
    /// 服务器地址
    var 服务器地址: String
    /// 用户名
    var 用户名: String?
    /// 密码引用（Keychain）
    var 密码引用: Data?
    /// 共享密钥
    var 共享密钥: String?
    /// 远程标识符（IKEv2）
    var 远程标识符: String?
    /// 本地标识符（IKEv2）
    var 本地标识符: String?
    /// 断开连接时是否保持连接
    var 断开时保持连接: Bool
    /// 按需连接
    var 按需连接: Bool
    /// 包含所有网络流量
    var 包含所有流量: Bool
    /// 代理配置
    var 代理配置: [String: Any]?
    /// DNS 服务器
    var DNS服务器: [String]
    /// 搜索域
    var 搜索域: [String]
    /// 排除的域名
    var 排除域名: [String]
    /// 描述文件数据（.mobileconfig XML）
    var 描述文件数据: String?
    /// 创建时间
    let 创建时间: Date
    /// 安装时间
    var 安装时间: Date?
    /// 最后连接时间
    var 最后连接时间: Date?
    /// 总连接时长（秒）
    var 总连接时长: TimeInterval
    /// 关联的节点 ID
    var 关联节点ID: UUID?
    /// 关联的节点名称
    var 关联节点名称: String?
    /// 备注
    var 备注: String?
    /// 标签
    var 标签: [String]

    /// 连接时长显示
    var 连接时长显示: String {
        let 小时 = Int(总连接时长) / 3600
        let 分钟 = (Int(总连接时长) % 3600) / 60
        if 小时 > 0 {
            return "\(小时)小时\(分钟)分钟"
        } else {
            return "\(分钟)分钟"
        }
    }

    /// 默认描述文件（PacketTunnel）
    static func 默认描述文件() -> VPN描述文件模型 {
        VPN描述文件模型(
            id: UUID(),
            名称: "NewVPN 隧道",
            类型: .自定义,
            状态: .未安装,
            扩展BundleID: "com.newvpn.app.tunnel",
            服务器地址: "127.0.0.1",
            用户名: nil,
            密码引用: nil,
            共享密钥: nil,
            远程标识符: nil,
            本地标识符: nil,
            断开时保持连接: false,
            按需连接: false,
            包含所有流量: true,
            代理配置: nil,
            DNS服务器: ["223.5.5.5", "119.29.29.29"],
            搜索域: [],
            排除域名: [],
            描述文件数据: nil,
            创建时间: Date(),
            安装时间: nil,
            最后连接时间: nil,
            总连接时长: 0,
            关联节点ID: nil,
            关联节点名称: nil,
            备注: "NewVPN 自定义协议隧道配置",
            标签: ["默认", "PacketTunnel"]
        )
    }
}

// MARK: - 证书导入结果

/// 证书导入结果
struct 证书导入结果 {
    /// 是否成功
    let 成功: Bool
    /// 导入的证书
    let 证书: CA证书模型?
    /// 错误信息
    let 错误信息: String?

    /// 成功结果
    static func 成功(证书: CA证书模型) -> 证书导入结果 {
        证书导入结果(成功: true, 证书: 证书, 错误信息: nil)
    }

    /// 失败结果
    static func 失败(错误: String) -> 证书导入结果 {
        证书导入结果(成功: false, 证书: nil, 错误信息: 错误)
    }
}

// MARK: - 描述文件安装结果

/// 描述文件安装结果
struct 描述文件安装结果 {
    /// 是否成功
    let 成功: Bool
    /// 错误信息
    let 错误信息: String?
    /// 安装的描述文件
    let 描述文件: VPN描述文件模型?

    /// 成功结果
    static func 成功(描述文件: VPN描述文件模型) -> 描述文件安装结果 {
        描述文件安装结果(成功: true, 错误信息: nil, 描述文件: 描述文件)
    }

    /// 失败结果
    static func 失败(错误: String) -> 描述文件安装结果 {
        描述文件安装结果(成功: false, 错误信息: 错误, 描述文件: nil)
    }
}
