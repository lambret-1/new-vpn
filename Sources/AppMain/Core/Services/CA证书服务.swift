//
//  CA证书服务.swift
//  NewVPN
//
//  CA 证书服务
//  负责证书导入、解析、保存、安装、删除、指纹计算
//

import Foundation
import CryptoKit

/// CA 证书服务
final class CA证书服务 {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = CA证书服务()

    // MARK: - 属性

    /// 文件管理器
    private let 文件管理 = FileManager.default

    /// 证书目录 URL
    private var 证书目录: URL? {
        guard let 文档目录 = 文件管理.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let 目录 = 文档目录.appendingPathComponent("certificates", isDirectory: true)
        if !文件管理.fileExists(atPath: 目录.path) {
            try? 文件管理.createDirectory(at: 目录, withIntermediateDirectories: true)
        }
        return 目录
    }

    /// 元数据文件路径
    private var 元数据路径: URL? {
        证书目录?.appendingPathComponent("certificates.json")
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 证书列表管理

    /// 加载证书列表
    func 加载证书列表() -> [CA证书模型] {
        guard let 路径 = 元数据路径,
              let 数据 = try? Data(contentsOf: 路径),
              let 列表 = try? JSONDecoder().decode([CA证书模型].self, from: 数据) else {
            return []
        }
        return 列表
    }

    /// 保存证书列表
    func 保存证书列表(_ 列表: [CA证书模型]) -> Bool {
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

    // MARK: - 证书导入

    /// 从 PEM 字符串导入证书
    func 从PEM导入证书(_ pem字符串: String, 名称: String? = nil) -> 证书导入结果 {
        // 清理 PEM 字符串
        let 清理后 = pem字符串
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let 证书数据 = Data(base64Encoded: 清理后) else {
            return .失败(错误: "无效的 Base64 编码")
        }

        return 从数据导入证书(证书数据, 格式: .der, 名称: 名称)
    }

    /// 从文件 URL 导入证书
    func 从文件导入证书(文件URL: URL, 名称: String? = nil) -> 证书导入结果 {
        guard 文件管理.fileExists(atPath: 文件URL.path) else {
            return .失败(错误: "文件不存在")
        }

        guard let 数据 = try? Data(contentsOf: 文件URL) else {
            return .失败(错误: "无法读取文件")
        }

        let 扩展名 = 文件URL.pathExtension.lowercased()
        let 格式: 证书格式
        switch 扩展名 {
        case "pem", "crt":
            格式 = .pem
        case "cer", "der":
            格式 = .der
        case "p12", "pfx":
            格式 = .p12
        default:
            格式 = .pem
        }

        if 格式 == .pem, let 字符串 = String(data: 数据, encoding: .utf8) {
            return 从PEM导入证书(字符串, 名称: 名称)
        }

        return 从数据导入证书(数据, 格式: 格式, 名称: 名称)
    }

    /// 从数据导入证书
    func 从数据导入证书(_ 数据: Data, 格式: 证书格式, 名称: String? = nil) -> 证书导入结果 {
        // 解析证书信息
        let 信息 = 解析证书信息(数据)

        // 计算指纹
        let sha1 = 计算SHA1指纹(数据)
        let sha256 = 计算SHA256指纹(数据)

        // 确定证书名称
        let 证书名称 = 名称 ?? 信息.主题.isEmpty ? "未命名证书" : 信息.主题

        // 创建证书模型
        let 证书 = CA证书模型(
            id: UUID(),
            名称: 证书名称,
            类型: 信息.类型,
            格式: 格式,
            状态: .未安装,
            证书数据: 数据.base64EncodedString(),
            颁发者: 信息.颁发者,
            主题: 信息.主题,
            序列号: 信息.序列号,
            生效日期: 信息.生效日期,
            过期日期: 信息.过期日期,
            SHA1指纹: sha1,
            SHA256指纹: sha256,
            公钥算法: 信息.公钥算法,
            公钥长度: 信息.公钥长度,
            签名算法: 信息.签名算法,
            用于MITM: false,
            用于TLS验证: false,
            导入时间: Date(),
            安装时间: nil,
            备注: nil,
            标签: ["导入"]
        )

        // 保存证书文件
        guard 保存证书文件(证书) else {
            return .失败(错误: "保存证书文件失败")
        }

        return .成功(证书: 证书)
    }

    // MARK: - 证书文件管理

    /// 保存证书文件
    func 保存证书文件(_ 证书: CA证书模型) -> Bool {
        guard let 目录 = 证书目录 else { return false }
        let 文件URL = 目录.appendingPathComponent("\(证书.id.uuidString).\(证书.格式.文件扩展名)")

        guard let 数据 = Data(base64Encoded: 证书.证书数据) else { return false }

        do {
            try 数据.write(to: 文件URL)
            return true
        } catch {
            return false
        }
    }

    /// 加载证书文件数据
    func 加载证书数据(_ 证书: CA证书模型) -> Data? {
        guard let 目录 = 证书目录 else { return nil }
        let 文件URL = 目录.appendingPathComponent("\(证书.id.uuidString).\(证书.格式.文件扩展名)")
        return try? Data(contentsOf: 文件URL)
    }

    /// 删除证书文件
    func 删除证书文件(_ 证书: CA证书模型) -> Bool {
        guard let 目录 = 证书目录 else { return true }
        let 文件URL = 目录.appendingPathComponent("\(证书.id.uuidString).\(证书.格式.文件扩展名)")
        guard 文件管理.fileExists(atPath: 文件URL.path) else { return true }
        do {
            try 文件管理.removeItem(at: 文件URL)
            return true
        } catch {
            return false
        }
    }

    /// 导出证书为 PEM 格式
    func 导出为PEM(_ 证书: CA证书模型) -> String? {
        guard let 数据 = 加载证书数据(证书) else { return nil }
        let base64 = 数据.base64EncodedString(options: .lineLength64Characters)
        return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----"
    }

    // MARK: - 证书安装

    /// 生成包含证书的 .mobileconfig 描述文件
    func 生成证书描述文件(_ 证书: CA证书模型) -> String? {
        guard let 证书数据 = 加载证书数据(证书) else { return nil }

        let base64证书 = 证书数据.base64EncodedString()
        let UUID字符串 = UUID().uuidString

        // 生成简单的 .mobileconfig XML
        let mobileconfig = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadCertificateFileName</key>
                    <string>\(证书.名称).cer</string>
                    <key>PayloadContent</key>
                    <data>\(base64证书)</data>
                    <key>PayloadDescription</key>
                    <string>添加 CA 根证书</string>
                    <key>PayloadDisplayName</key>
                    <string>\(证书.名称)</string>
                    <key>PayloadIdentifier</key>
                    <string>com.apple.security.root.\(UUID字符串)</string>
                    <key>PayloadType</key>
                    <string>com.apple.security.root</string>
                    <key>PayloadUUID</key>
                    <string>\(UUID字符串)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>PayloadDescription</key>
            <string>安装 \(证书.名称) 证书</string>
            <key>PayloadDisplayName</key>
            <string>\(证书.名称)</string>
            <key>PayloadIdentifier</key>
            <string>com.newvpn.app.certificate.\(UUID字符串)</string>
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

    /// 保存描述文件到临时目录并返回 URL
    func 保存描述文件到临时目录(_ 证书: CA证书模型) -> URL? {
        guard let 描述文件内容 = 生成证书描述文件(证书) else { return nil }
        guard let 临时目录 = 文件管理.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let 文件URL = 临时目录.appendingPathComponent("\(证书.名称).mobileconfig")
        do {
            try 描述文件内容.write(to: 文件URL, atomically: true, encoding: .utf8)
            return 文件URL
        } catch {
            return nil
        }
    }

    // MARK: - 证书信息解析

    /// 证书信息
    private struct 证书信息 {
        var 类型: 证书类型 = .根证书
        var 颁发者: String = ""
        var 主题: String = ""
        var 序列号: String = ""
        var 生效日期: Date = Date()
        var 过期日期: Date = Date()
        var 公钥算法: String = "RSA"
        var 公钥长度: Int = 2048
        var 签名算法: String = "SHA256WithRSA"
    }

    /// 解析证书信息（简化实现，实际应使用 Security framework）
    private func 解析证书信息(_ 数据: Data) -> 证书信息 {
        var 信息 = 证书信息()

        // 使用 Security framework 解析证书
        if let 证书 = SecCertificateCreateWithData(nil, 数据 as CFData) {
            // 获取证书摘要
            if let 摘要 = SecCertificateCopySubjectSummary(证书) as String? {
                信息.主题 = 摘要
            }

            // 获取证书属性
            var 错误: Unmanaged<CFError>?
            if let 属性 = SecCertificateCopyValues(证书, [kSecOIDX509V1SubjectName, kSecOIDX509V1IssuerName, kSecOIDX509V1SerialNumber, kSecOIDX509V1ValidityNotBefore, kSecOIDX509V1ValidityNotAfter] as CFArray, &错误) as? [String: Any] {
                // 解析主题
                if let 主题字典 = 属性[kSecOIDX509V1SubjectName as String] as? [String: Any],
                   let 主题值 = 主题字典[kSecPropertyKeyValue as String] as? String {
                    信息.主题 = 主题值
                }

                // 解析颁发者
                if let 颁发者字典 = 属性[kSecOIDX509V1IssuerName as String] as? [String: Any],
                   let 颁发者值 = 颁发者字典[kSecPropertyKeyValue as String] as? String {
                    信息.颁发者 = 颁发者值
                }

                // 解析序列号
                if let 序列号字典 = 属性[kSecOIDX509V1SerialNumber as String] as? [String: Any],
                   let 序列号值 = 序列号字典[kSecPropertyKeyValue as String] as? String {
                    信息.序列号 = 序列号值
                }

                // 解析有效期
                if let 生效字典 = 属性[kSecOIDX509V1ValidityNotBefore as String] as? [String: Any],
                   let 生效值 = 生效字典[kSecPropertyKeyValue as String] as? Double {
                    信息.生效日期 = Date(timeIntervalSinceReferenceDate: 生效值)
                }

                if let 过期字典 = 属性[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
                   let 过期值 = 过期字典[kSecPropertyKeyValue as String] as? Double {
                    信息.过期日期 = Date(timeIntervalSinceReferenceDate: 过期值)
                }
            }

            // 判断证书类型（根证书：颁发者 == 主题）
            if 信息.颁发者 == 信息.主题 && !信息.主题.isEmpty {
                信息.类型 = .根证书
            } else {
                信息.类型 = .中间证书
            }
        }

        return 信息
    }

    // MARK: - 指纹计算

    /// 计算 SHA1 指纹
    func 计算SHA1指纹(_ 数据: Data) -> String {
        let 摘要 = Insecure.SHA1.hash(data: 数据)
        return 摘要.map { String(format: "%02x", $0) }.joined(separator: ":").uppercased()
    }

    /// 计算 SHA256 指纹
    func 计算SHA256指纹(_ 数据: Data) -> String {
        let 摘要 = SHA256.hash(data: 数据)
        return 摘要.map { String(format: "%02x", $0) }.joined(separator: ":").uppercased()
    }

    // MARK: - 证书验证

    /// 验证证书是否有效
    func 验证证书有效性(_ 证书: CA证书模型) -> (有效: Bool, 原因: String?) {
        // 检查是否过期
        if 证书.是否已过期 {
            return (false, "证书已过期")
        }

        // 检查是否在有效期内
        if Date() < 证书.生效日期 {
            return (false, "证书尚未生效")
        }

        return (true, nil)
    }

    /// 验证证书链
    func 验证证书链(_ 证书: CA证书模型, 根证书列表: [CA证书模型]) -> (有效: Bool, 原因: String?) {
        // 简化实现：检查证书是否由列表中的某个根证书颁发
        for 根证书 in 根证书列表 {
            if 根证书.主题 == 证书.颁发者 {
                return (true, nil)
            }
        }
        return (false, "未找到匹配的根证书")
    }
}
