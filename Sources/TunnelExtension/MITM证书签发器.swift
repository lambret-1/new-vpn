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
            NSLog("[扩展-MITM] 解析 CA 证书失败")
            return false
        }
        self.ca证书 = 证书

        // 解析 CA 私钥
        guard let 私钥 = 解析PEM私钥(私钥PEM) else {
            NSLog("[扩展-MITM] 解析 CA 私钥失败")
            return false
        }
        self.ca私钥 = 私钥

        NSLog("[扩展-MITM] CA 证书加载成功")
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
            NSLog("[扩展-MITM] 签发域名证书失败：\(标准化域名)")
            return nil
        }

        // 写入缓存
        let 过期时间 = Date().addingTimeInterval(证书有效期)
        缓存队列.async {
            self.证书缓存[标准化域名] = (身份, 过期时间)
            // 缓存上限：最多缓存 200 张证书，超出清理最旧的
            if self.证书缓存.count > 200 {
                let 排序 = self.证书缓存.sorted { $0.value.过期时间 < $1.value.过期时间 }
                for i in 0..<(self.证书缓存.count - 200) {
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
            NSLog("[扩展-MITM] CA 证书未加载")
            return nil
        }

        // 1. 为服务器生成新的密钥对（RSA 2048）
        let 密钥属性: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var 错误: Unmanaged<CFError>?
        guard let 服务器私钥 = SecKeyCreateRandomKey(密钥属性 as CFDictionary, &错误) else {
            NSLog("[扩展-MITM] 生成服务器密钥对失败：\(错误?.takeRetainedValue().localizedDescription ?? "未知")")
            return nil
        }
        guard let 服务器公钥 = SecKeyCopyPublicKey(服务器私钥) else {
            NSLog("[扩展-MITM] 获取服务器公钥失败")
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
            NSLog("[扩展-MITM] 签发域名证书失败：\(域名)")
            return nil
        }

        // 3. 从 DER 数据创建 SecCertificate
        guard let 服务器证书 = SecCertificateCreateWithData(nil, 证书DER as CFData) else {
            NSLog("[扩展-MITM] 创建 SecCertificate 失败：\(域名)，DER长度=\(证书DER.count)")
            return nil
        }

        // 验证证书能否被系统正确解析
        if let 主题 = SecCertificateCopyNormalizedSubjectSequence(服务器证书) as Data? {
            NSLog("[扩展-MITM] 证书解析成功：\(域名)，主题DER长度=\(主题.count)")
        } else {
            NSLog("[扩展-MITM] 证书解析失败：\(域名)")
        }

        // 验证证书的公钥
        if let 证书公钥 = SecCertificateCopyKey(服务器证书) {
            NSLog("[扩展-MITM] 证书公钥提取成功：\(域名)")
        } else {
            NSLog("[扩展-MITM] 证书公钥提取失败：\(域名)")
        }

        NSLog("[扩展-MITM] 域名证书签发成功：\(域名)，DER长度=\(证书DER.count)")

        // 4. 将服务器证书和私钥添加到钥匙串，创建 SecIdentity
        let 标签 = "com.newvpn.mitm.\(域名)"
        guard let 身份 = 创建身份(证书: 服务器证书, 私钥: 服务器私钥, 标签: 标签) else {
            NSLog("[扩展-MITM] 创建服务器身份失败：\(域名)")
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
            NSLog("[扩展-MITM] 添加私钥到钥匙串失败：\(私钥状态)")
        } else {
            NSLog("[扩展-MITM] 私钥添加成功：\(标签)")
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
            NSLog("[扩展-MITM] 添加证书到钥匙串失败：\(证书状态)")
        } else {
            NSLog("[扩展-MITM] 证书添加成功：\(标签)")
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
            NSLog("[扩展-MITM] SecIdentity 查询成功：\(标签)")
            return 身份
        }

        NSLog("[扩展-MITM] SecIdentity 查询失败：\(证书查询状态) (\(标签))")
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

    /// 解析 PEM 格式私钥为 SecKey
    private func 解析PEM私钥(_ pem: String) -> SecKey? {
        var 内容 = pem
        内容 = 内容.replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
        内容 = 内容.replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
        内容 = 内容.replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
        内容 = 内容.replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
        内容 = 内容.replacingOccurrences(of: "\n", with: "")
        内容 = 内容.replacingOccurrences(of: "\r", with: "")
        内容 = 内容.trimmingCharacters(in: .whitespaces)

        guard let 数据 = Data(base64Encoded: 内容) else { return nil }

        let 属性: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var 错误: Unmanaged<CFError>?
        return SecKeyCreateWithData(数据 as CFData, 属性 as CFDictionary, &错误)
    }

    // MARK: - 清空缓存

    /// 清空证书缓存
    func 清空缓存() {
        缓存队列.async {
            self.证书缓存.removeAll()
        }
    }
}
