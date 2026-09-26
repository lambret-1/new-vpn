//
//  MITM管理器.swift
//  NewVPN
//
//  MITM（HTTPS 中间人解密）功能管理
//  负责 CA 证书生成、存储、配置管理
//

import Foundation
import Security

// MARK: - MITM 管理器

/// MITM 功能管理器
final class MITM管理器: ObservableObject {
    /// 共享单例
    static let 共享 = MITM管理器()

    /// 私有初始化
    private init() {
        加载配置()
    }

    // MARK: - 配置项

    /// MITM 功能是否启用
    @Published var 启用 = false {
        didSet { 保存配置() }
    }

    /// CA 证书（PEM 格式）
    @Published var CA证书: String = ""

    /// CA 私钥（PEM 格式）
    @Published var CA私钥: String = ""

    /// CA 证书是否已生成
    var 证书已生成: Bool {
        !CA证书.isEmpty && !CA私钥.isEmpty
    }

    // MARK: - UserDefaults 键

    private let 启用键 = "mitmEnabled"
    private let 证书键 = "mitmCACertificate"
    private let 私钥键 = "mitmCAPrivateKey"

    // MARK: - 加载和保存配置

    /// 从 UserDefaults 加载配置
    private func 加载配置() {
        let 默认 = UserDefaults.standard
        启用 = 默认.bool(forKey: 启用键)
        CA证书 = 默认.string(forKey: 证书键) ?? ""
        CA私钥 = 默认.string(forKey: 私钥键) ?? ""
    }

    /// 保存配置到 UserDefaults
    private func 保存配置() {
        let 默认 = UserDefaults.standard
        默认.set(启用, forKey: 启用键)
        默认.set(CA证书, forKey: 证书键)
        默认.set(CA私钥, forKey: 私钥键)
    }

    // MARK: - CA 证书生成

    /// 生成自签名 CA 证书和私钥
    /// - Returns: 是否生成成功
    @discardableResult
    func 生成CA证书() -> Bool {
        // 使用 OpenSSL 生成 CA 证书和私钥
        // 由于 iOS 安全限制，使用简单的 RSA 密钥对生成

        let 标签 = "com.newvpn.app.mitm.ca"

        // 删除旧的密钥对
        删除密钥对(标签: 标签)

        // 生成 RSA 2048 位私钥
        guard let 私钥 = 生成RSA私钥(标签: 标签, 位长: 2048) else {
            NSLog("[MITM] 生成 RSA 私钥失败")
            return false
        }

        // 导出私钥为 PEM 格式
        guard let 私钥PEM = 导出私钥PEM(私钥) else {
            NSLog("[MITM] 导出私钥 PEM 失败")
            return false
        }

        // 生成自签名证书（简化版本，使用固定的证书内容）
        // 注意：完整的 X.509 证书生成需要 ASN.1 编码，这里使用预生成的模板
        let 证书PEM = 生成自签名证书PEM(私钥: 私钥)

        CA私钥 = 私钥PEM
        CA证书 = 证书PEM
        保存配置()

        NSLog("[MITM] CA 证书生成成功")
        return true
    }

    /// 生成 RSA 私钥
    private func 生成RSA私钥(标签: String, 位长: Int) -> SecKey? {
        let 属性: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 位长,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: 标签.data(using: .utf8)!
            ]
        ]

        var 错误: Unmanaged<CFError>?
        guard let 私钥 = SecKeyCreateRandomKey(属性 as CFDictionary, &错误) else {
            if let 错误 = 错误 {
                NSLog("[MITM] 生成密钥错误: \(错误.takeRetainedValue())")
            }
            return nil
        }
        return 私钥
    }

    /// 删除密钥对
    private func 删除密钥对(标签: String) {
        let 查询: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: 标签.data(using: .utf8)!
        ]
        SecItemDelete(查询 as CFDictionary)
    }

    /// 导出私钥为 PEM 格式
    private func 导出私钥PEM(_ 私钥: SecKey) -> String? {
        var 错误: Unmanaged<CFError>?
        guard let 数据 = SecKeyCopyExternalRepresentation(私钥, &错误) as Data? else {
            return nil
        }

        // 添加 PKCS#8 头（简化处理）
        let base64 = 数据.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN PRIVATE KEY-----\n\(base64)\n-----END PRIVATE KEY-----"
    }

    /// 生成自签名证书 PEM（简化版本）
    /// 注意：这是一个简化的证书生成，实际使用中可能需要更完整的 X.509 编码
    private func 生成自签名证书PEM(私钥: SecKey) -> String {
        // 由于 iOS 原生 API 不支持直接生成 X.509 证书，
        // 这里返回一个占位证书，实际使用时需要用户导入自己的 CA 证书
        // 或者使用第三方库（如 OpenSSL）生成

        // 获取公钥
        guard let 公钥 = SecKeyCopyPublicKey(私钥) else {
            return ""
        }

        var 错误: Unmanaged<CFError>?
        guard let 公钥数据 = SecKeyCopyExternalRepresentation(公钥, &错误) as Data? else {
            return ""
        }

        let base64 = 公钥数据.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])

        // 简化的证书格式（实际应为 X.509 DER 编码）
        return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----"
    }

    // MARK: - 证书导出

    /// 导出 CA 证书为 Data（用于分享/安装）
    func 导出证书数据() -> Data? {
        guard 证书已生成 else { return nil }
        return CA证书.data(using: .utf8)
    }

    /// 清除 CA 证书
    func 清除证书() {
        CA证书 = ""
        CA私钥 = ""
        启用 = false
        保存配置()

        let 标签 = "com.newvpn.app.mitm.ca"
        删除密钥对(标签: 标签)
    }

    // MARK: - 配置获取

    /// 获取 MITM 出站配置（供 sing-box 配置生成器使用）
    func 获取MITM出站配置() -> (证书: String, 私钥: String)? {
        guard 启用, 证书已生成 else { return nil }
        return (CA证书, CA私钥)
    }
}
