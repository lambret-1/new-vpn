//
//  ASN1解码器.swift
//  NewVPN-Tunnel
//
//  轻量级 ASN.1 DER 解码器，用于解析 PKCS#8 格式私钥等场景
//

import Foundation

/// ASN.1 DER 解码器
final class ASN1解码器 {
    // MARK: - ASN.1 标签

    enum 标签: UInt8 {
        case integer = 0x02
        case bitString = 0x03
        case octetString = 0x04
        case null = 0x05
        case objectIdentifier = 0x06
        case sequence = 0x30
        case set = 0x31
    }

    /// 解析后的 ASN.1 元素
    struct ASN1元素 {
        let 标签: UInt8
        let 数据: Data  // 内容数据（不含标签和长度）
        let 完整数据: Data  // 完整数据（含标签和长度）
        let 子元素: [ASN1元素]?  // 如果是 SEQUENCE/SET，解析子元素
    }

    // MARK: - 解码方法

    /// 解码 DER 数据为 ASN.1 元素
    static func 解码(_ 数据: Data) -> ASN1元素? {
        guard !数据.isEmpty else { return nil }
        var 偏移 = 0
        return 解析元素(数据, 偏移: &偏移)
    }

    /// 解析单个 ASN.1 元素
    private static func 解析元素(_ 数据: Data, 偏移: inout Int) -> ASN1元素? {
        guard 偏移 < 数据.count else { return nil }

        let 起始偏移 = 偏移
        let 标签字节 = 数据[偏移]
        偏移 += 1

        // 解析长度
        guard 偏移 < 数据.count else { return nil }
        let 长度首字节 = 数据[偏移]
        偏移 += 1

        var 内容长度: Int
        if 长度首字节 & 0x80 == 0 {
            // 短形式：长度直接在首字节
            内容长度 = Int(长度首字节)
        } else {
            // 长形式：低7位表示后续长度字节数
            let 长度字节数 = Int(长度首字节 & 0x7F)
            guard 偏移 + 长度字节数 <= 数据.count else { return nil }
            内容长度 = 0
            for _ in 0..<长度字节数 {
                内容长度 = (内容长度 << 8) | Int(数据[偏移])
                偏移 += 1
            }
        }

        guard 偏移 + 内容长度 <= 数据.count else { return nil }
        let 内容数据 = 数据.subdata(in: 偏移..<偏移 + 内容长度)
        偏移 += 内容长度

        let 完整数据 = 数据.subdata(in: 起始偏移..<偏移)

        // 如果是 SEQUENCE 或 SET，递归解析子元素
        var 子元素: [ASN1元素]? = nil
        if 标签字节 == 标签.sequence.rawValue || 标签字节 == 标签.set.rawValue {
            子元素 = 解析子元素(内容数据)
        }

        return ASN1元素(标签: 标签字节, 数据: 内容数据, 完整数据: 完整数据, 子元素: 子元素)
    }

    /// 解析 SEQUENCE/SET 中的所有子元素
    private static func 解析子元素(_ 数据: Data) -> [ASN1元素] {
        var 子元素列表: [ASN1元素] = []
        var 偏移 = 0
        while 偏移 < 数据.count {
            if let 元素 = 解析元素(数据, 偏移: &偏移) {
                子元素列表.append(元素)
            } else {
                break
            }
        }
        return 子元素列表
    }

    // MARK: - PKCS#8 私钥解析

    /// 从 PKCS#8 格式私钥中提取 PKCS#1 格式 RSA 私钥
    /// - Parameter pkcs8数据: PKCS#8 格式的 DER 数据
    /// - Returns: PKCS#1 格式的 RSA 私钥 DER 数据，失败返回 nil
    static func 提取PKCS1私钥(fromPKCS8 pkcs8数据: Data) -> Data? {
        // PKCS#8 PrivateKeyInfo 结构：
        // SEQUENCE {
        //   version INTEGER,
        //   privateKeyAlgorithm SEQUENCE { OID, NULL },
        //   privateKey OCTET STRING  -- 这里面是 PKCS#1 RSAPrivateKey
        // }

        guard let 根元素 = 解码(pkcs8数据),
              根元素.标签 == 标签.sequence.rawValue,
              let 子元素 = 根元素.子元素,
              子元素.count >= 3 else {
            return nil
        }

        // 第三个元素应该是 privateKey OCTET STRING
        let privateKey元素 = 子元素[2]
        guard privateKey元素.标签 == 标签.octetString.rawValue else {
            return nil
        }

        // OCTET STRING 的内容就是 PKCS#1 格式的 RSAPrivateKey
        return privateKey元素.数据
    }

    /// 从 PEM 字符串解析 PKCS#8 私钥并转换为 PKCS#1 格式
    /// - Parameter pem: PEM 格式的私钥字符串
    /// - Returns: PKCS#1 格式的 DER 数据，失败返回 nil
    static func 解析PKCS8PEM并转换为PKCS1(_ pem: String) -> Data? {
        var 内容 = pem
        内容 = 内容.replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
        内容 = 内容.replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
        内容 = 内容.replacingOccurrences(of: "\n", with: "")
        内容 = 内容.replacingOccurrences(of: "\r", with: "")
        内容 = 内容.trimmingCharacters(in: .whitespaces)

        guard let der数据 = Data(base64Encoded: 内容) else { return nil }
        return 提取PKCS1私钥(fromPKCS8: der数据)
    }

    /// 检测 PEM 私钥是否为 PKCS#8 格式
    static func 是PKCS8格式(_ pem: String) -> Bool {
        return pem.contains("-----BEGIN PRIVATE KEY-----")
    }

    /// 检测 PEM 私钥是否为 PKCS#1 格式
    static func 是PKCS1格式(_ pem: String) -> Bool {
        return pem.contains("-----BEGIN RSA PRIVATE KEY-----")
    }
}
