//
//  VPN描述文件服务.swift
//  NewVPN
//
//  VPN 描述文件服务
//  负责生成 .mobileconfig、通过 NEVPNManager 安装/移除 VPN 配置
//

import Foundation
import NetworkExtension

/// VPN 描述文件服务
final class VPN描述文件服务 {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = VPN描述文件服务()

    // MARK: - 属性

    /// 文件管理器
    private let 文件管理 = FileManager.default

    /// VPN 管理器
    private var VPN管理器: NEVPNManager {
        NEVPNManager.shared()
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 描述文件生成

    /// 生成 PacketTunnel 类型的 .mobileconfig 描述文件
    func 生成PacketTunnel描述文件(_ 描述文件: VPN描述文件模型) -> String? {
        let UUID字符串 = UUID().uuidString
        // 服务器地址为空时使用 127.0.0.1 作为默认值
        let 服务器地址 = 描述文件.服务器地址.isEmpty ? "127.0.0.1" : 描述文件.服务器地址

        // 生成 VendorConfig（自定义参数，由 Packet Tunnel Provider 代码解析）
        var 厂商配置: [String: Any] = [
            "serverAddress": 服务器地址
        ]

        if let 节点ID = 描述文件.关联节点ID {
            厂商配置["nodeId"] = 节点ID.uuidString
        }
        if let 节点名称 = 描述文件.关联节点名称 {
            厂商配置["nodeName"] = 节点名称
        }

        // 转换为 XML 兼容的字典
        let 厂商配置XML = 字典转XML(厂商配置)

        // 主 App Bundle ID（去掉最后一个组件）
        let 主AppBundleID = 描述文件.扩展BundleID.components(separatedBy: ".").dropLast().joined(separator: ".")

        let mobileconfig = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadDisplayName</key>
            <string>\(描述文件.名称)</string>
            <key>PayloadIdentifier</key>
            <string>com.newvpn.app.config</string>
            <key>PayloadUUID</key>
            <string>\(UUID().uuidString)</string>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadDisplayName</key>
                    <string>\(描述文件.名称)</string>
                    <key>PayloadIdentifier</key>
                    <string>com.newvpn.app.config.vpn</string>
                    <key>PayloadUUID</key>
                    <string>\(UUID字符串)</string>
                    <key>PayloadType</key>
                    <string>com.apple.vpn.managed</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                    <key>UserDefinedName</key>
                    <string>\(描述文件.名称)</string>
                    <key>VPNType</key>
                    <string>VPN</string>
                    <key>VPNSubType</key>
                    <string>\(描述文件.扩展BundleID)</string>
                    <key>ProviderBundleIdentifier</key>
                    <string>\(主AppBundleID)</string>
                    <key>VendorConfig</key>
                    \(厂商配置XML)
                    <key>OnDemandEnabled</key>
                    <integer>\(描述文件.按需连接 ? 1 : 0)</integer>
                </dict>
            </array>
        </dict>
        </plist>
        """

        return mobileconfig
    }

    /// 生成 IKEv2 类型的 .mobileconfig 描述文件
    func 生成IKEv2描述文件(_ 描述文件: VPN描述文件模型) -> String? {
        let UUID字符串 = UUID().uuidString

        let mobileconfig = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadDescription</key>
                    <string>配置 VPN 设置</string>
                    <key>PayloadDisplayName</key>
                    <string>\(描述文件.名称)</string>
                    <key>PayloadIdentifier</key>
                    <string>com.apple.vpn.managed.\(UUID字符串)</string>
                    <key>PayloadType</key>
                    <string>com.apple.vpn.managed</string>
                    <key>PayloadUUID</key>
                    <string>\(UUID字符串)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                    <key>UserDefinedName</key>
                    <string>\(描述文件.名称)</string>
                    <key>VPN</key>
                    <dict>
                        <key>AuthenticationMethod</key>
                        <string>SharedSecret</string>
                        <key>DisconnectOnIdle</key>
                        <integer>0</integer>
                        <key>IKEv2</key>
                        <dict>
                            <key>AuthenticationMethod</key>
                            <string>SharedSecret</string>
                            <key>ChildSecurityAssociationParameters</key>
                            <dict>
                                <key>DiffieHellmanGroup</key>
                                <integer>14</integer>
                                <key>EncryptionAlgorithm</key>
                                <string>AES-256</string>
                                <key>IntegrityAlgorithm</key>
                                <string>SHA2-256</string>
                                <key>LifeTimeInMinutes</key>
                                <integer>1440</integer>
                            </dict>
                            <key>DeadPeerDetectionRate</key>
                            <string>Medium</string>
                            <key>DisableMOBIKE</key>
                            <integer>0</integer>
                            <key>DisableRedirect</key>
                            <integer>0</integer>
                            <key>EnableCertificateRevocationCheck</key>
                            <integer>0</integer>
                            <key>EnablePFS</key>
                            <integer>0</integer>
                            <key>ExtendedAuthEnabled</key>
                            <integer>0</integer>
                            <key>IKESecurityAssociationParameters</key>
                            <dict>
                                <key>DiffieHellmanGroup</key>
                                <integer>14</integer>
                                <key>EncryptionAlgorithm</key>
                                <string>AES-256</string>
                                <key>IntegrityAlgorithm</key>
                                <string>SHA2-256</string>
                                <key>LifeTimeInMinutes</key>
                                <integer>1440</integer>
                            </dict>
                            <key>LocalIdentifier</key>
                            <string>\(描述文件.本地标识符 ?? "")</string>
                            <key>PayloadCertificateUUID</key>
                            <string></string>
                            <key>RemoteAddress</key>
                            <string>\(描述文件.服务器地址)</string>
                            <key>RemoteIdentifier</key>
                            <string>\(描述文件.远程标识符 ?? 描述文件.服务器地址)</string>
                            <key>UseConfigurationAttributeInternalIPSubnet</key>
                            <integer>0</integer>
                        </dict>
                        <key>OnDemandEnabled</key>
                        <integer>\(描述文件.按需连接 ? 1 : 0)</integer>
                        <key>OnDemandRules</key>
                        <array>
                            <dict>
                                <key>Action</key>
                                <string>Connect</string>
                            </dict>
                        </array>
                        <key>RemoteAddress</key>
                        <string>\(描述文件.服务器地址)</string>
                        <key>SharedSecret</key>
                        <string>\(描述文件.共享密钥 ?? "")</string>
                    </dict>
                    <key>VPNType</key>
                    <string>IKEv2</string>
                </dict>
            </array>
            <key>PayloadDescription</key>
            <string>VPN 配置描述文件</string>
            <key>PayloadDisplayName</key>
            <string>\(描述文件.名称)</string>
            <key>PayloadIdentifier</key>
            <string>com.newvpn.app.vpn.\(UUID().uuidString)</string>
            <key>PayloadOrganization</key>
            <string>NewVPN</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(UUID().uuidString)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """

        return mobileconfig
    }

    /// 保存描述文件到临时目录
    func 保存描述文件到临时目录(_ 描述文件: VPN描述文件模型) -> URL? {
        let 内容: String?
        switch 描述文件.类型 {
        case .自定义:
            内容 = 生成PacketTunnel描述文件(描述文件)
        case .ikev2:
            内容 = 生成IKEv2描述文件(描述文件)
        default:
            内容 = 生成PacketTunnel描述文件(描述文件)
        }

        guard let 描述文件内容 = 内容 else { return nil }
        guard let 临时目录 = 文件管理.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let 文件URL = 临时目录.appendingPathComponent("\(描述文件.名称).mobileconfig")
        do {
            try 描述文件内容.write(to: 文件URL, atomically: true, encoding: .utf8)
            return 文件URL
        } catch {
            return nil
        }
    }

    // MARK: - NEVPNManager 安装

    /// 安装 PacketTunnel VPN 配置
    func 安装PacketTunnel配置(_ 描述文件: VPN描述文件模型, 完成: @escaping (描述文件安装结果) -> Void) {
        let 管理器 = NEVPNManager.shared()

        管理器.loadFromPreferences { 错误 in
            if let 错误 = 错误 {
                完成(.失败(错误: "加载 VPN 配置失败：\(错误.localizedDescription)"))
                return
            }

            // 创建 PacketTunnel 协议
            let 协议 = NETunnelProviderProtocol()
            协议.providerBundleIdentifier = 描述文件.扩展BundleID
            协议.serverAddress = 描述文件.服务器地址

            // 提供者配置
            var 提供者配置: [String: Any] = [
                "serverAddress": 描述文件.服务器地址
            ]
            if let 节点ID = 描述文件.关联节点ID {
                提供者配置["nodeId"] = 节点ID.uuidString
            }
            if let 节点名称 = 描述文件.关联节点名称 {
                提供者配置["nodeName"] = 节点名称
            }
            协议.providerConfiguration = 提供者配置

            // 配置管理器
            管理器.protocolConfiguration = 协议
            管理器.localizedDescription = 描述文件.名称
            管理器.isEnabled = true
            管理器.isOnDemandEnabled = 描述文件.按需连接

            // 按需连接规则
            if 描述文件.按需连接 {
                let 规则 = NEOnDemandRuleConnect()
                管理器.onDemandRules = [规则]
            }

            // 保存配置
            管理器.saveToPreferences { 保存错误 in
                if let 保存错误 = 保存错误 {
                    完成(.失败(错误: "保存 VPN 配置失败：\(保存错误.localizedDescription)"))
                    return
                }

                // 重新加载以确认
                管理器.loadFromPreferences { _ in
                    var 更新后的描述文件 = 描述文件
                    更新后的描述文件.状态 = .已安装
                    更新后的描述文件.安装时间 = Date()
                    完成(.成功(描述文件: 更新后的描述文件))
                }
            }
        }
    }

    /// 移除 VPN 配置
    func 移除VPN配置(_ 描述文件: VPN描述文件模型, 完成: @escaping (Bool, String?) -> Void) {
        let 管理器 = NEVPNManager.shared()

        管理器.loadFromPreferences { 错误 in
            if let 错误 = 错误 {
                完成(false, "加载 VPN 配置失败：\(错误.localizedDescription)")
                return
            }

            // 移除配置
            管理器.removeFromPreferences { 移除错误 in
                if let 移除错误 = 移除错误 {
                    完成(false, "移除 VPN 配置失败：\(移除错误.localizedDescription)")
                    return
                }
                完成(true, nil)
            }
        }
    }

    /// 连接 VPN
    func 连接VPN() -> (成功: Bool, 错误: String?) {
        let 管理器 = NEVPNManager.shared()

        do {
            try 管理器.connection.startVPNTunnel()
            return (true, nil)
        } catch {
            return (false, "启动 VPN 隧道失败：\(error.localizedDescription)")
        }
    }

    /// 断开 VPN
    func 断开VPN() {
        let 管理器 = NEVPNManager.shared()
        管理器.connection.stopVPNTunnel()
    }

    /// 获取 VPN 连接状态
    func 获取连接状态() -> NEVPNStatus {
        NEVPNManager.shared().connection.status
    }

    /// 获取 VPN 连接时长
    func 获取连接时长() -> TimeInterval {
        guard let 连接日期 = NEVPNManager.shared().connection.connectedDate else {
            return 0
        }
        return Date().timeIntervalSince(连接日期)
    }

    // MARK: - 描述文件列表管理

    /// 描述文件目录 URL
    private var 描述文件目录: URL? {
        guard let 文档目录 = 文件管理.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let 目录 = 文档目录.appendingPathComponent("profiles", isDirectory: true)
        if !文件管理.fileExists(atPath: 目录.path) {
            try? 文件管理.createDirectory(at: 目录, withIntermediateDirectories: true)
        }
        return 目录
    }

    /// 元数据文件路径
    private var 元数据路径: URL? {
        描述文件目录?.appendingPathComponent("profiles.json")
    }

    /// 加载描述文件列表
    func 加载描述文件列表() -> [VPN描述文件模型] {
        guard let 路径 = 元数据路径,
              let 数据 = try? Data(contentsOf: 路径),
              let 列表 = try? JSONDecoder().decode([VPN描述文件模型].self, from: 数据) else {
            return []
        }
        return 列表
    }

    /// 保存描述文件列表
    func 保存描述文件列表(_ 列表: [VPN描述文件模型]) -> Bool {
        guard let 路径 = 元数据路径,
              let 数据 = try? JSONEncoder().encode(列表) else {
            return false
        }
        do {
            try 数据.write(to: 路径)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 私有方法

    /// 字典转 XML 字符串
    private func 字典转XML(_ 字典: [String: Any]) -> String {
        var 行: [String] = ["<dict>"]
        for (键, 值) in 字典 {
            行.append("<key>\(键)</key>")
            if let 字符串值 = 值 as? String {
                行.append("<string>\(字符串值)</string>")
            } else if let 整数值 = 值 as? Int {
                行.append("<integer>\(整数值)</integer>")
            } else if let 布尔值 = 值 as? Bool {
                行.append(布尔值 ? "<true/>" : "<false/>")
            } else if let 数组值 = 值 as? [Any] {
                行.append("<array>")
                for 元素 in 数组值 {
                    if let 字符串元素 = 元素 as? String {
                        行.append("<string>\(字符串元素)</string>")
                    }
                }
                行.append("</array>")
            }
        }
        行.append("</dict>")
        return 行.joined(separator: "\n                        ")
    }
}
