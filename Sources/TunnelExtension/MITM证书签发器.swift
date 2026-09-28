//
//  MITM证书签发器.swift
//  NewVPN-Tunnel
//
//  MITM 动态证书签发器：根据目标域名用 CA 证书实时签发服务器证书
// 一期：支持单域名证书签发，证书缓存复用
//

import Foundation
import Security

/// MITM 动态证书签发器
final class MITM证书签发器 {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = MITM证书签发器()

    // MARK: - 属性

    /// CA 证书（SecCertificate）
    private var ca证书: SecCertificate?
    /// CA 私钥（SecKey）
    private var ca私钥: SecKey?
    /// 证书缓存：域名 -> (身份, 过期时间)
    private var 证书缓存: [String: (身份: SecIdentity, 过期时间: Date)] = [:]
    /// 缓存队列
    private let 缓存队列 = DispatchQueue(label: "com.newvpn.mitm.certcache")
    /// 证书有效期（秒）：7天
    private let 证书有效期: TimeInterval = 7 * 24 * 3600

    // MARK: - 初始化

    private init() {}

    // MARK: - 加载 CA 证书

    /// 加载 CA 证书和私钥
    /// - Parameters:
    ///   - 证书PEM: CA 证书 PEM 字符串
    ///   - 私钥PEM: CA 私钥 PEM 字符串
    /// - Returns: 是否加载成功
    @discardableResult
    func 加载CA证书(证书PEM: String, 私钥PEM: String) -> Bool {
        // 解析 CA 证书
        guard let 证书数据 = 解析PEM证书(证书PEM),
              let 证书 = SecCertificateCreateWithData(nil, 证书数据 as CFData) else {
            扩展日志记录器.共享.错误("MITM", "解析 CA 证书失败")
            return false
        }
        self.ca证书 = 证书

        // 解析 CA 私钥
        guard let 私钥 = 解析PEM私钥(私钥PEM) else {
            扩展日志记录器.共享.错误("MITM", "解析 CA 私钥失败")
            return false
        }
        self.ca私钥 = 私钥

        扩展日志记录器.共享.信息("MITM", "CA 证书加载成功")
        return true
    }

    /// 获取 CA 证书（用于 TLS 证书链）
    func 获取CA证书() -> SecCertificate? {
        return ca证书
    }

    // MARK: - 获取服务器身份（用于 TLS）

    /// 获取指定域名的服务器身份（含证书和私钥），优先从缓存读取
    /// - Parameter 域名: 目标域名
    /// - Returns: SecIdentity，失败返回 nil
    func 获取服务器身份(域名: String) -> SecIdentity? {
        let 标准化域名 = 域名.lowercased().trimmingCharacters(in: .whitespaces)
        guard !标准化域名.isEmpty else { return nil }

        // 检查缓存
        if let 缓存 = 缓存队列.sync(execute: { 证书缓存[标准化域名] }) {
            if 缓存.过期时间 > Date() {
                return 缓存.身份
            }
        }

        // 签发新证书
        guard let 身份 = 签发服务器证书(域名: 标准化域名) else {
            扩展日志记录器.共享.错误("MITM", "签发域名证书失败：\(标准化域名)")
            return nil
        }

        // 写入缓存
        let 过期时间 = Date().addingTimeInterval(证书有效期)
        缓存队列.async {
            self.证书缓存[标准化域名] = (身份, 过期时间)
            // 缓存上限：最多缓存 100 张证书（内存优化：从200降至100），超出清理最旧的
            if self.证书缓存.count > 100 {
                let 排序 = self.证书缓存.sorted { $0.value.过期时间 < $1.value.过期时间 }
                for i in 0..<(self.证书缓存.count - 100) {
                    self.证书缓存.removeValue(forKey: 排序[i].key)
                }
            }
        }

        return 身份
    }

    // MARK: - 签发服务器证书

    /// 用 CA 证书签发指定域名的服务器证书
    /// - Parameter 域名: 目标域名
    /// - Returns: SecIdentity，失败返回 nil
    private func 签发服务器证书(域名: String) -> SecIdentity? {
        guard let ca证书 = self.ca证书, let ca私钥 = self.ca私钥 else {
            扩展日志记录器.共享.错误("MITM", "CA 证书未加载")
            return nil
        }

        // 1. 为服务器生成新的密钥对（RSA 2048）
        let 密钥属性: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var 错误: Unmanaged<CFError>?
        guard let 服务器私钥 = SecKeyCreateRandomKey(密钥属性 as CFDictionary, &错误) else {
            扩展日志记录器.共享.错误("MITM", "生成服务器密钥对失败：\(错误?.takeRetainedValue().localizedDescription ?? "未知")")
            return nil
        }
        guard let 服务器公钥 = SecKeyCopyPublicKey(服务器私钥) else {
            扩展日志记录器.共享.错误("MITM", "获取服务器公钥失败")
            return nil
        }

        // 2. 使用 X509 证书签发器动态签发域名证书（CN=域名，SAN=DNS:域名）
        guard let 证书DER = X509证书签发器.共享.签发服务器证书(
            域名: 域名,
            CA证书: ca证书,
            CA私钥: ca私钥,
            服务器公钥: 服务器公钥,
            有效期: 证书有效期
        ) else {
            扩展日志记录器.共享.错误("MITM", "签发域名证书失败：\(域名)")
            return nil
        }

        // 3. 从 DER 数据创建 SecCertificate
        guard let 服务器证书 = SecCertificateCreateWithData(nil, 证书DER as CFData) else {
            扩展日志记录器.共享.错误("MITM", "创建 SecCertificate 失败：\(域名)，DER长度=\(证书DER.count)")
            return nil
        }

        // 验证证书能否被系统正确解析
        if let 主题 = SecCertificateCopyNormalizedSubjectSequence(服务器证书) as Data? {
            扩展日志记录器.共享.追踪("MITM", "证书解析成功：\(域名)，主题DER长度=\(主题.count)")
        } else {
            扩展日志记录器.共享.错误("MITM", "证书解析失败：\(域名)")
        }

        // 验证证书的公钥
        if let 证书公钥 = SecCertificateCopyKey(服务器证书) {
            扩展日志记录器.共享.追踪("MITM", "证书公钥提取成功：\(域名)")
        } else {
            扩展日志记录器.共享.错误("MITM", "证书公钥提取失败：\(域名)")
        }

        扩展日志记录器.共享.信息("MITM", "域名证书签发成功：\(域名)，DER长度=\(证书DER.count)")

        // 验证证书是否由 CA 正确签发（SecTrust 验证）
        验证证书链(服务器证书: 服务器证书, CA证书: ca证书, 域名: 域名)

        // 4. 将服务器证书和私钥添加到钥匙串，创建 SecIdentity
        let 标签 = "com.newvpn.mitm.\(域名)"
        guard let 身份 = 创建身份(证书: 服务器证书, 私钥: 服务器私钥, 标签: 标签) else {
            扩展日志记录器.共享.错误("MITM", "创建服务器身份失败：\(域名)")
            return nil
        }

        return 身份
    }

    /// 从证书和私钥创建 SecIdentity
    private func 创建身份(证书: SecCertificate, 私钥: SecKey, 标签: String) -> SecIdentity? {
        // 先清理旧的钥匙串条目
        let 删除查询: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: 标签
        ]
        SecItemDelete(删除查询 as CFDictionary)

        // 1. 先将私钥添加到钥匙串
        let 私钥标签 = "\(标签).key"
        SecItemDelete([kSecClass as String: kSecClassKey, kSecAttrLabel as String: 私钥标签] as CFDictionary)
        let 私钥添加: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecValueRef as String: 私钥,
            kSecAttrLabel as String: 私钥标签,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let 私钥状态 = SecItemAdd(私钥添加 as CFDictionary, nil)
        if 私钥状态 != errSecSuccess && 私钥状态 != errSecDuplicateItem {
            扩展日志记录器.共享.错误("MITM", "添加私钥到钥匙串失败：\(私钥状态)")
        } else {
            扩展日志记录器.共享.追踪("MITM", "私钥添加成功：\(标签)")
        }

        // 2. 再将证书添加到钥匙串（与私钥关联后自动形成 SecIdentity）
        let 证书标签 = "\(标签).cert"
        SecItemDelete([kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: 证书标签] as CFDictionary)
        let 证书添加: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: 证书,
            kSecAttrLabel as String: 证书标签,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let 证书状态 = SecItemAdd(证书添加 as CFDictionary, nil)
        if 证书状态 != errSecSuccess && 证书状态 != errSecDuplicateItem {
            扩展日志记录器.共享.错误("MITM", "添加证书到钥匙串失败：\(证书状态)")
        } else {
            扩展日志记录器.共享.追踪("MITM", "证书添加成功：\(标签)")
        }

        // 3. 通过证书引用查询 SecIdentity（最可靠的方式）
        let 证书查询: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchItemList as String: [证书],
            kSecReturnRef as String: true
        ]
        var 证书结果: AnyObject?
        let 证书查询状态 = SecItemCopyMatching(证书查询 as CFDictionary, &证书结果)
        if 证书查询状态 == errSecSuccess, let 身份 = 证书结果 as! SecIdentity? {
            扩展日志记录器.共享.追踪("MITM", "SecIdentity 查询成功：\(标签)")
            return 身份
        }

        扩展日志记录器.共享.错误("MITM", "SecIdentity 查询失败：\(证书查询状态) (\(标签))")
        return nil
    }

    // MARK: - PEM 解析工具

    /// 解析 PEM 格式证书为 DER 数据
    private func 解析PEM证书(_ pem: String) -> Data? {
        var 内容 = pem
        内容 = 内容.replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
        内容 = 内容.replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
        内容 = 内容.replacingOccurrences(of: "\n", with: "")
        内容 = 内容.replacingOccurrences(of: "\r", with: "")
        内容 = 内容.trimmingCharacters(in: .whitespaces)
        return Data(base64Encoded: 内容)
    }

    /// 解析 PEM 格式私钥为 SecKey（支持 PKCS#8 和 PKCS#1 格式）
    private func 解析PEM私钥(_ pem: String) -> SecKey? {
        // 检测私钥格式
        let 是PKCS8 = ASN1解码器.是PKCS8格式(pem)
        let 是PKCS1 = ASN1解码器.是PKCS1格式(pem)

        var 私钥数据: Data?

        if 是PKCS8 {
            // PKCS#8 格式：需要解析 ASN.1 结构，提取 PKCS#1 私钥
            扩展日志记录器.共享.追踪("MITM", "检测到 PKCS#8 格式私钥，正在转换为 PKCS#1 格式")
            私钥数据 = ASN1解码器.解析PKCS8PEM并转换为PKCS1(pem)
            if 私钥数据 == nil {
                扩展日志记录器.共享.错误("MITM", "PKCS#8 私钥转换为 PKCS#1 失败")
            }
        } else if 是PKCS1 {
            // PKCS#1 格式：直接 base64 解码
            扩展日志记录器.共享.追踪("MITM", "检测到 PKCS#1 格式私钥")
            var 内容 = pem
            内容 = 内容.replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            内容 = 内容.replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            内容 = 内容.replacingOccurrences(of: "\n", with: "")
            内容 = 内容.replacingOccurrences(of: "\r", with: "")
            内容 = 内容.trimmingCharacters(in: .whitespaces)
            私钥数据 = Data(base64Encoded: 内容)
        } else {
            扩展日志记录器.共享.错误("MITM", "未知私钥格式（既不是 PKCS#8 也不是 PKCS#1）")
            return nil
        }

        guard let 数据 = 私钥数据, !数据.isEmpty else {
            扩展日志记录器.共享.错误("MITM", "私钥数据解码失败或为空")
            return nil
        }

        let 属性: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var 错误: Unmanaged<CFError>?
        guard let 私钥 = SecKeyCreateWithData(数据 as CFData, 属性 as CFDictionary, &错误) else {
            if let 错误 = 错误?.takeRetainedValue() {
                扩展日志记录器.共享.错误("MITM", "SecKeyCreateWithData 失败：\(错误.localizedDescription)")
            }
            return nil
        }

        扩展日志记录器.共享.追踪("MITM", "私钥解析成功，数据长度=\(数据.count)")
        return 私钥
    }

    // MARK: - 清空缓存

    /// 清空证书缓存
    func 清空缓存() {
        缓存队列.async {
            self.证书缓存.removeAll()
        }
    }

    // MARK: - 证书链验证

    /// 验证服务器证书是否由 CA 正确签发
    private func 验证证书链(服务器证书: SecCertificate, CA证书: SecCertificate, 域名: String) {
        let 策略 = SecPolicyCreateSSL(true, 域名 as CFString)
        var 可选信任: SecTrust?
        let 创建状态 = SecTrustCreateWithCertificates([服务器证书, CA证书] as CFArray, 策略, &可选信任)
        guard 创建状态 == errSecSuccess, let 信任 = 可选信任 else {
            扩展日志记录器.共享.错误("MITM", "SecTrust 创建失败：\(创建状态) (\(域名))")
            return
        }

        // 设置 CA 证书为锚点
        SecTrustSetAnchorCertificates(信任, [CA证书] as CFArray)
        SecTrustSetAnchorCertificatesOnly(信任, true)

        // 同步评估
        var 错误: CFError?
        let 结果 = SecTrustEvaluateWithError(信任, &错误)
        if 结果 {
            扩展日志记录器.共享.追踪("MITM", "证书链验证通过：\(域名)")
        } else {
            let 错误描述 = 错误?.localizedDescription ?? "未知错误"
            扩展日志记录器.共享.错误("MITM", "证书链验证失败：\(域名) - \(错误描述)")
        }
    }
}
