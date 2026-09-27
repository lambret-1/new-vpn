//
//  X509证书签发器.swift
//  NewVPN-Tunnel
//
//  X.509 证书动态签发器：为指定域名构造并签名服务器证书
//  使用 ASN.1 DER 编码 + Security framework RSA 签名
//

import Foundation
import Security

/// X.509 证书签发器
final class X509证书签发器 {
    // MARK: - 单例

    static let 共享 = X509证书签发器()

    private init() {}

    // MARK: - 签发服务器证书

    /// 为指定域名签发服务器证书
    /// - Parameters:
    ///   - 域名: 目标域名（如 www.example.com）
    ///   - CA证书: CA 证书（SecCertificate）
    ///   - CA私钥: CA 私钥（SecKey）
    ///   - 服务器公钥: 服务器公钥（SecKey）
    ///   - 有效期: 证书有效期（秒）
    /// - Returns: 签发的证书 DER 数据，失败返回 nil
    func 签发服务器证书(域名: String, CA证书: SecCertificate, CA私钥: SecKey, 服务器公钥: SecKey, 有效期: TimeInterval = 7 * 24 * 3600) -> Data? {
        // 1. 构造 TBSCertificate
        guard let tbs证书 = 构造TBS证书(域名: 域名, CA证书: CA证书, 服务器公钥: 服务器公钥, 有效期: 有效期) else {
            NSLog("[X509] 构造 TBSCertificate 失败")
            return nil
        }

        // 2. 用 CA 私钥对 TBSCertificate 进行 SHA256 签名
        guard let 签名 = 签名数据(数据: tbs证书, 私钥: CA私钥) else {
            NSLog("[X509] 签名 TBSCertificate 失败")
            return nil
        }

        // 3. 构造完整 Certificate：SEQUENCE { TBSCertificate, 签名算法, 签名值 }
        let 签名算法 = ASN1编码器.序列([
            ASN1编码器.对象标识符(ASN1编码器.OID.sha256WithRSAEncryption),
            ASN1编码器.空()
        ])
        let 签名值 = ASN1编码器.位串(签名)

        let 完整证书 = ASN1编码器.序列([tbs证书, 签名算法, 签名值])

        return 完整证书
    }

    // MARK: - 构造 TBSCertificate

    /// 构造 TBSCertificate（待签名证书）
    private func 构造TBS证书(域名: String, CA证书: SecCertificate, 服务器公钥: SecKey, 有效期: TimeInterval) -> Data? {
        // 版本：v3 [0] { INTEGER 2 }
        let 版本 = ASN1编码器.上下文特定(.contextSpecific0, 值: ASN1编码器.整数(2))

        // 序列号：随机 16 字节
        var 序列号字节 = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 { 序列号字节[i] = UInt8.random(in: 0...255) }
        序列号字节[0] &= 0x7F // 确保正数
        let 序列号 = ASN1编码器.整数(Data(序列号字节))

        // 签名算法：sha256WithRSAEncryption
        let 签名算法 = ASN1编码器.序列([
            ASN1编码器.对象标识符(ASN1编码器.OID.sha256WithRSAEncryption),
            ASN1编码器.空()
        ])

        // 颁发者：从 CA 证书提取
        guard let 颁发者 = 提取证书主题(证书: CA证书) else {
            NSLog("[X509] 提取 CA 证书主题失败")
            return nil
        }

        // 有效期
        let 现在 = Date()
        let 过期 = 现在.addingTimeInterval(有效期)
        let 有效期序列 = ASN1编码器.序列([
            ASN1编码器.utc时间(现在),
            ASN1编码器.utc时间(过期)
        ])

        // 主体：CN=域名
        let 主体 = 构造名称(属性: [
            (ASN1编码器.OID.countryName, .可打印字符串("CN")),
            (ASN1编码器.OID.organizationName, .可打印字符串("NewVPN")),
            (ASN1编码器.OID.commonName, .可打印字符串(域名))
        ])

        // 主体公钥信息
        guard let 公钥信息 = 构造公钥信息(公钥: 服务器公钥) else {
            NSLog("[X509] 构造公钥信息失败")
            return nil
        }

        // 扩展 [3] { SEQUENCE { 扩展... } }
        let 扩展 = 构造扩展(域名: 域名)

        // 组装 TBSCertificate
        return ASN1编码器.序列([
            版本,
            序列号,
            签名算法,
            颁发者,
            有效期序列,
            主体,
            公钥信息,
            扩展
        ])
    }

    // MARK: - 构造名称（RDNSequence）

    /// 名称属性类型
    enum 名称属性值 {
        case 可打印字符串(String)
        case utf8字符串(String)
    }

    /// 构造 RDNSequence 名称
    private func 构造名称(属性: [(oid: [UInt8], 值: 名称属性值)]) -> Data {
        var rdn集合 = [Data]()
        for 属性项 in 属性 {
            let 值数据: Data
            switch 属性项.值 {
            case .可打印字符串(let 字符串):
                值数据 = ASN1编码器.可打印字符串(字符串)
            case .utf8字符串(let 字符串):
                值数据 = ASN1编码器.utf8字符串(字符串)
            }
            let 属性类型值 = ASN1编码器.序列([
                ASN1编码器.对象标识符(属性项.oid),
                值数据
            ])
            let rdn = ASN1编码器.集合([属性类型值])
            rdn集合.append(rdn)
        }
        return ASN1编码器.序列(rdn集合)
    }

    // MARK: - 构造公钥信息

    /// 构造 SubjectPublicKeyInfo
    private func 构造公钥信息(公钥: SecKey) -> Data? {
        // 从 SecKey 提取公钥的 DER 数据（包含算法标识符和公钥位串）
        guard let 公钥数据 = SecKeyCopyExternalRepresentation(公钥, nil) as Data? else {
            NSLog("[X509] 提取公钥外部表示失败")
            return nil
        }

        // 算法标识符：rsaEncryption
        let 算法标识符 = ASN1编码器.序列([
            ASN1编码器.对象标识符(ASN1编码器.OID.rsaEncryption),
            ASN1编码器.空()
        ])

        // 公钥位串
        let 公钥位串 = ASN1编码器.位串(公钥数据)

        return ASN1编码器.序列([算法标识符, 公钥位串])
    }

    // MARK: - 构造扩展

    /// 构造证书扩展
    private func 构造扩展(域名: String) -> Data {
        var 扩展列表 = [Data]()

        // basicConstraints: CA:FALSE
        let basicConstraints值 = ASN1编码器.序列([
            ASN1编码器.编码(标签: .boolean, 值: Data([0x00])) // FALSE
        ])
        let basicConstraints扩展 = ASN1编码器.序列([
            ASN1编码器.对象标识符(ASN1编码器.OID.basicConstraints),
            ASN1编码器.编码(标签: .boolean, 值: Data([0xFF])), // critical=TRUE
            ASN1编码器.八位组串(basicConstraints值)
        ])
        扩展列表.append(basicConstraints扩展)

        // keyUsage: digitalSignature + keyEncipherment
        let keyUsage值 = ASN1编码器.位串(Data([0xA0]), 未使用位: 6) // bit 5(digitalSignature) + bit 6(keyEncipherment) = 0xA0
        let keyUsage扩展 = ASN1编码器.序列([
            ASN1编码器.对象标识符(ASN1编码器.OID.keyUsage),
            ASN1编码器.编码(标签: .boolean, 值: Data([0xFF])), // critical=TRUE
            ASN1编码器.八位组串(keyUsage值)
        ])
        扩展列表.append(keyUsage扩展)

        // extendedKeyUsage: serverAuth + clientAuth
        let extendedKeyUsage值 = ASN1编码器.序列([
            ASN1编码器.对象标识符(ASN1编码器.OID.serverAuth),
            ASN1编码器.对象标识符(ASN1编码器.OID.clientAuth)
        ])
        let extendedKeyUsage扩展 = ASN1编码器.序列([
            ASN1编码器.对象标识符(ASN1编码器.OID.extendedKeyUsage),
            ASN1编码器.八位组串(extendedKeyUsage值)
        ])
        扩展列表.append(extendedKeyUsage扩展)

        // subjectAltName: DNS:域名
        let san值 = ASN1编码器.序列([
            ASN1编码器.上下文特定(.contextSpecific2, 值: ASN1编码器.ia5字符串(域名)) // [2] = dNSName
        ])
        let san扩展 = ASN1编码器.序列([
            ASN1编码器.对象标识符(ASN1编码器.OID.subjectAltName),
            ASN1编码器.八位组串(san值)
        ])
        扩展列表.append(san扩展)

        let 扩展序列 = ASN1编码器.序列(扩展列表)
        return ASN1编码器.上下文特定(.contextSpecific3, 值: 扩展序列)
    }

    // MARK: - 提取证书主题

    /// 从 SecCertificate 提取主题名称的 DER 数据
    private func 提取证书主题(证书: SecCertificate) -> Data? {
        // SecCertificateCopyNormalizedSubjectSequence 返回 DER 编码的主题
        if let 主题 = SecCertificateCopyNormalizedSubjectSequence(证书) as Data? {
            return 主题
        }
        return nil
    }

    // MARK: - 签名

    /// 用 RSA 私钥对数据进行 SHA256 签名
    private func 签名数据(数据: Data, 私钥: SecKey) -> Data? {
        var 错误: Unmanaged<CFError>?
        guard let 签名 = SecKeyCreateSignature(私钥, .rsaSignatureMessagePKCS1v15SHA256, 数据 as CFData, &错误) as Data? else {
            if let 错误 = 错误?.takeRetainedValue() {
                NSLog("[X509] 签名失败：\(错误.localizedDescription)")
            }
            return nil
        }
        return 签名
    }
}
