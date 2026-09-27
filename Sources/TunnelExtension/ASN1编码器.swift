//
//  ASN1编码器.swift
//  NewVPN-Tunnel
//
//  轻量级 ASN.1 DER 编码器，用于动态构造 X.509 证书
//  仅实现证书签发所需的最小子集
//

import Foundation

/// ASN.1 DER 编码器
final class ASN1编码器 {
    // MARK: - ASN.1 标签

    enum 标签: UInt8 {
        case boolean = 0x01
        case integer = 0x02
        case bitString = 0x03
        case octetString = 0x04
        case null = 0x05
        case objectIdentifier = 0x06
        case sequence = 0x30
        case set = 0x31
        case printableString = 0x13
        case utf8String = 0x0C
        case ia5String = 0x16
        case utcTime = 0x17
        case generalizedTime = 0x18
        case contextSpecific0 = 0xA0
        case contextSpecific1 = 0xA1
        case contextSpecific2 = 0xA2
        case contextSpecific3 = 0xA3
    }

    // MARK: - 编码方法

    /// 编码一个 TLV（标签-长度-值）
    static func 编码(标签: 标签, 值: Data) -> Data {
        var 结果 = Data()
        结果.append(标签.rawValue)
        结果.append(内容: 编码长度(值.count))
        结果.append(值)
        return 结果
    }

    /// 编码长度（DER 格式）
    static func 编码长度(_ 长度: Int) -> Data {
        if 长度 < 0x80 {
            return Data([UInt8(长度)])
        }
        // 长形式：第一个字节的高位为1，低7位表示后续长度字节数
        var 字节 = [UInt8]()
        var 值 = 长度
        while 值 > 0 {
            字节.insert(UInt8(值 & 0xFF), at: 0)
            值 >>= 8
        }
        字节.insert(UInt8(0x80 | 字节.count), at: 0)
        return Data(字节)
    }

    /// 编码 SEQUENCE
    static func 序列(_ 元素: [Data]) -> Data {
        let 内容 = 元素.reduce(Data()) { $0 + $1 }
        return 编码(标签: .sequence, 值: 内容)
    }

    /// 编码 SET
    static func 集合(_ 元素: [Data]) -> Data {
        let 内容 = 元素.reduce(Data()) { $0 + $1 }
        return 编码(标签: .set, 值: 内容)
    }

    /// 编码 INTEGER
    static func 整数(_ 值: Data) -> Data {
        return 编码(标签: .integer, 值: 值)
    }

    /// 编码 INTEGER（从 UInt64）
    static func 整数(_ 值: UInt64) -> Data {
        var 字节 = [UInt8]()
        var 数值 = 值
        repeat {
            字节.insert(UInt8(数值 & 0xFF), at: 0)
            数值 >>= 8
        } while 数值 > 0
        // 确保正数（最高位为0）
        if let 首字节 = 字节.first, 首字节 & 0x80 != 0 {
            字节.insert(0x00, at: 0)
        }
        return 编码(标签: .integer, 值: Data(字节))
    }

    /// 编码 BIT STRING
    static func 位串(_ 值: Data, 未使用位: UInt8 = 0) -> Data {
        var 内容 = Data([未使用位])
        内容.append(值)
        return 编码(标签: .bitString, 值: 内容)
    }

    /// 编码 OCTET STRING
    static func 八位组串(_ 值: Data) -> Data {
        return 编码(标签: .octetString, 值: 值)
    }

    /// 编码 NULL
    static func 空() -> Data {
        return 编码(标签: .null, 值: Data())
    }

    /// 编码 OBJECT IDENTIFIER
    static func 对象标识符(_ oid: [UInt8]) -> Data {
        return 编码(标签: .objectIdentifier, 值: Data(oid))
    }

    /// 编码 UTF8String
    static func utf8字符串(_ 值: String) -> Data {
        return 编码(标签: .utf8String, 值: 值.data(using: .utf8) ?? Data())
    }

    /// 编码 PrintableString
    static func 可打印字符串(_ 值: String) -> Data {
        return 编码(标签: .printableString, 值: 值.data(using: .ascii) ?? Data())
    }

    /// 编码 IA5String
    static func ia5字符串(_ 值: String) -> Data {
        return 编码(标签: .ia5String, 值: 值.data(using: .ascii) ?? Data())
    }

    /// 编码 UTCTime（YYMMDDHHMMSSZ）
    static func utc时间(_ 日期: Date) -> Data {
        let 格式器 = DateFormatter()
        格式器.dateFormat = "yyMMddHHmmss'Z'"
        格式器.timeZone = TimeZone(abbreviation: "UTC")
        let 字符串 = 格式器.string(from: 日期)
        return 编码(标签: .utcTime, 值: 字符串.data(using: .ascii) ?? Data())
    }

    /// 编码 GeneralizedTime（YYYYMMDDHHMMSSZ）
    static func 通用时间(_ 日期: Date) -> Data {
        let 格式器 = DateFormatter()
        格式器.dateFormat = "yyyyMMddHHmmss'Z'"
        格式器.timeZone = TimeZone(abbreviation: "UTC")
        let 字符串 = 格式器.string(from: 日期)
        return 编码(标签: .generalizedTime, 值: 字符串.data(using: .ascii) ?? Data())
    }

    /// 编码上下文特定标签 [0]、[1] 等
    static func 上下文特定(_ 标签: 标签, 值: Data) -> Data {
        return 编码(标签: 标签, 值: 值)
    }

    // MARK: - 常用 OID

    /// 常用 OID 定义
    enum OID {
        /// rsaEncryption (1.2.840.113549.1.1.1)
        static let rsaEncryption: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
        /// sha256WithRSAEncryption (1.2.840.113549.1.1.11)
        static let sha256WithRSAEncryption: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B]
        /// commonName (2.5.4.3)
        static let commonName: [UInt8] = [0x55, 0x04, 0x03]
        /// organizationName (2.5.4.10)
        static let organizationName: [UInt8] = [0x55, 0x04, 0x0A]
        /// organizationalUnitName (2.5.4.11)
        static let organizationalUnitName: [UInt8] = [0x55, 0x04, 0x0B]
        /// countryName (2.5.4.6)
        static let countryName: [UInt8] = [0x55, 0x04, 0x06]
        /// stateOrProvinceName (2.5.4.8)
        static let stateOrProvinceName: [UInt8] = [0x55, 0x04, 0x08]
        /// localityName (2.5.4.7)
        static let localityName: [UInt8] = [0x55, 0x04, 0x07]
        /// subjectAltName (2.5.29.17)
        static let subjectAltName: [UInt8] = [0x55, 0x1D, 0x11]
        /// basicConstraints (2.5.29.19)
        static let basicConstraints: [UInt8] = [0x55, 0x1D, 0x13]
        /// keyUsage (2.5.29.15)
        static let keyUsage: [UInt8] = [0x55, 0x1D, 0x0F]
        /// extendedKeyUsage (2.5.29.37)
        static let extendedKeyUsage: [UInt8] = [0x55, 0x1D, 0x25]
        /// serverAuth (1.3.6.1.5.5.7.3.1)
        static let serverAuth: [UInt8] = [0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x01]
        /// clientAuth (1.3.6.1.5.5.7.3.2)
        static let clientAuth: [UInt8] = [0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x02]
    }
}
