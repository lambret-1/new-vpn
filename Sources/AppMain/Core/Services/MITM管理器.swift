//
//  MITM管理器.swift
//  NewVPN
//
//  MITM（HTTPS 中间人解密）功能管理
//  负责 CA 证书管理、配置持久化、MITM证书状态智能检测
//  CA 证书为预生成的自签名根证书，有效期 10 年
//

import Foundation
import CommonCrypto

// MARK: - MITM证书状态枚举

/// CA 证书状态
enum MITM证书状态: Equatable {
    /// 证书完全就绪（文件存在 + 未过期 + 用户确认已安装信任）
    case 就绪
    /// 证书文件存在但未安装
    case 未安装
    /// 证书已安装但未在设置中信任
    case 未信任
    /// 证书文件缺失
    case 文件缺失
    /// 证书已过期
    case 已过期
    /// 证书文件损坏
    case 文件损坏
    /// 临近过期（30天内）
    case 临近过期(剩余天数: Int)

    /// 状态描述
    var 描述: String {
        switch self {
        case .就绪: return "证书就绪，MITM 可正常使用"
        case .未安装: return "证书已生成，请安装描述文件"
        case .未信任: return "证书已安装，请在设置中完全信任"
        case .文件缺失: return "证书文件缺失，请重新生成"
        case .已过期: return "证书已过期，请重新生成"
        case .文件损坏: return "证书文件损坏，请重新生成"
        case .临近过期(let 天数): return "证书将在 \(天数) 天后过期，请提前更新"
        }
    }

    /// 是否可以直接使用
    var 可使用: Bool {
        if case .就绪 = self { return true }
        return false
    }
}

// MARK: - 证书元数据

/// CA 证书元数据（持久化存储）
struct 证书元数据: Codable, Equatable {
    /// 证书文件是否存在（物理文件检测标记）
    var 文件存在: Bool
    /// 证书指纹（SHA-256）
    var 指纹: String
    /// 创建时间
    var 创建时间: Date
    /// 过期时间
    var 过期时间: Date
    /// 证书文件路径（沙盒内）
    var 文件路径: String
    /// 系统探测是否失败（失败时启用手动确认兜底）
    var 系统探测失败: Bool
    /// 手动兜底确认已安装（仅系统探测失败时使用）
    var 手动确认已安装: Bool
    /// 手动兜底确认已信任（仅系统探测失败时使用）
    var 手动确认已信任: Bool

    /// 剩余有效天数
    var 剩余天数: Int {
        let 日历 = Calendar.current
        let 组件 = 日历.dateComponents([.day], from: Date(), to: 过期时间)
        return 组件.day ?? 0
    }

    /// 是否已过期
    var 已过期: Bool {
        Date() >= 过期时间
    }

    /// 是否临近过期（30天内）
    var 临近过期: Bool {
        剩余天数 <= 30 && 剩余天数 > 0
    }
}

// MARK: - MITM 管理器

/// MITM 功能管理器
final class MITM管理器: ObservableObject {
    /// 共享单例
    static let 共享 = MITM管理器()

    /// 私有初始化
    private init() {
        加载配置()
        加载证书元数据()
    }

    // MARK: - 预生成 CA 证书和私钥

    /// 预生成的自签名 CA 证书（PEM 格式，RSA 2048，有效期 10 年）
    /// 颁发者：C=CN, ST=Guangdong, L=Dongguan, O=NewVPN, OU=MITM, CN=NewVPN MITM CA
    private static let 预生成CA证书 = """
-----BEGIN CERTIFICATE-----
MIIDuzCCAqOgAwIBAgIUPse4zPDlPWZCRUNE5DN98+ihzlswDQYJKoZIhvcNAQEL
BQAwbTELMAkGA1UEBhMCQ04xEjAQBgNVBAgMCUd1YW5nZG9uZzERMA8GA1UEBwwI
RG9uZ2d1YW4xDzANBgNVBAoMBk5ld1ZQTjENMAsGA1UECwwETUlUTTEXMBUGA1UE
AwwOTmV3VlBOIE1JVE0gQ0EwHhcNMjYwOTI3MDUyMTAxWhcNMzYwOTI0MDUyMTAx
WjBtMQswCQYDVQQGEwJDTjESMBAGA1UECAwJR3Vhbmdkb25nMREwDwYDVQQHDAhE
b25nZ3VhbjEPMA0GA1UECgwGTmV3VlBOMQ0wCwYDVQQLDARNSVRNMRcwFQYDVQQD
DA5OZXdWUE4gTUlUTSBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AM8pq8n3d6ocmbJAnHBg82Usr7zJDaxch4BKEQYjZ+rXF5NCjvrej7OLrzA624ME
EHzkWvM4lHrPFcwBDeNpm4KShdh3mr5fLf/qs1Yk4ar2sIKL5OwE6uRPpjwC53L9
xShMxn26Wu+m3i5iYpW/GM63JIDNR2DDDBhU0TbwJIleD94/9wDCtCqQJUCKn1nK
TJ4M9NCd7Le4yfqfWxyAl5elHJQIUiEp8c27ktVew2FiRJMLxqlvLzLb0M16P1kw
DRtC7u7gTt2/SLYxAyLz8OCR3ep9EVzTGYWfszhCZu3MMnh1NgZnWdEQn9zAqAyJ
q8TFMmEdFfaf6xMbLu/0z2MCAwEAAaNTMFEwHQYDVR0OBBYEFHIM5TzRO29Noehn
N7zh3Ir1pue+MB8GA1UdIwQYMBaAFHIM5TzRO29NoehnN7zh3Ir1pue+MA8GA1Ud
EwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBABU5Bsjr6tR/b0hKV3SdX245
G5fwLZ/EUa+j6SDtzgx3mvjaZ1bNGZbGRFuTGqTkLAF6QSS5aZRfse4RILRs4nnx
1hrWl7oFjlniHtwDskcAfsCu0JrtACpLhQk/Qu9XteORzeJMiY5HUo+FPF03ja/V
y214yyOHcp68iytOvesorZcYn1ucqeNYTpzhAr2wIuT4VgV8cWRssVJ+OWDgT7xr
QKBw/dSbFUbUDZcFmxa4S49UPLwH4Fo40am4WLxV/+RGGQmhipacSxF3l4H4We/m
HyLugfYN59l4OCPjUplaSIifgDd9/131N0OPyi0gJFFD4+4pASgCCUQCsIflqjk=
-----END CERTIFICATE-----
"""

    /// 预生成的 CA 私钥（PEM 格式，PKCS#8）
    private static let 预生成CA私钥 = """
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDPKavJ93eqHJmy
QJxwYPNlLK+8yQ2sXIeAShEGI2fq1xeTQo763o+zi68wOtuDBBB85FrzOJR6zxXM
AQ3jaZuCkoXYd5q+Xy3/6rNWJOGq9rCCi+TsBOrkT6Y8Audy/cUoTMZ9ulrvpt4u
YmKVvxjOtySAzUdgwwwYVNE28CSJXg/eP/cAwrQqkCVAip9ZykyeDPTQney3uMn6
n1scgJeXpRyUCFIhKfHNu5LVXsNhYkSTC8apby8y29DNej9ZMA0bQu7u4E7dv0i2
MQMi8/Dgkd3qfRFc0xmFn7M4QmbtzDJ4dTYGZ1nREJ/cwKgMiavExTJhHRX2n+sT
Gy7v9M9jAgMBAAECggEAGOt21kM1+lkZZfdeuif3b166PxfiVK8Gv7hpJtdgez/n
fpfdkjDukVcGumMCH9b/0r43cJWISuOZSCKCVK5R/hl5D0qH60mQw32sl/q0yLeH
ERUZ8wg+ZztrkEF7LPp42nmt0Nb3dGeax3KfUEseBVPDiNjosquTy2N8jULC6mEW
WPNhLlNVj7oL9Ze6jqBbK8uoyLTYS7ZPGODKgKZjgl2b+8Ut367H4Pg3iHmT5ivt
KqvjQ0q9vgf5maMA9zHnhcGAnZrgvPDLMQFEZzRurwvmKOmJxbh8eoksh39ot0xZ
NcjYZnygX+EqFlacJoWTfq6bU69amnOQMIX8m+z+JQKBgQDlkG/92O2SLrXJpHoi
/hEC5uv53wMXs3c52+KWrEKXeEOmj5/DIZo6xEh7ObNYMmTqpu7dxSaWpGsyIO6W
q3Y+Dcqw1FroDBRbYScr+XcTPgvJHUphPsrM+QvL491IKfltTlhbct/RlQUkvdqR
eRogekoLHNrQXAznPbJL85YaNQKBgQDnBNakZQsfYk0o4ehP2+F+90jWj/A8V+9x
+qnjYxP1i12NjDiTQbhJsUx/g90GbabZRx3ODAvnKhd2FEsEryBZ4p70VoPU8MJq
u5bTEkZlZ5lY4xgzSHt5T/IncRpge7s+SLdzg0aflRWQmfbxJYpEzNcVdkcJOg84
HLbmAjY2NwKBgQDbXvpWRw1Hi1F2nrGEbOuOrWNFBWLsLDi71q8iMvzzyB5FtawD
CUJb9CQbdVk35/hd8CYFURf+DqLNZYD6BGHbDMzrzBIO+zQc2qtXL24luj4C8vWY
FiwwUbF/JoHYKxxK4vo2cYEGw3QF11Ndfq+D57iIBAvp3n0KIQAX6m8/HQKBgFIi
6UG33zWAWNixQUyra8gdmZsXwB1kUnDe42pCPsVtkIyUD0Vj92bUD9PCiWIQuGLG
IzWwGMdOstq7qlR3A3SR21waKnMaSrVyDtTqyXaiV+Y/j8oj+iqOnxUg5HTraQ5j
Aj6irQhuFCW+aAsjAr8laU9rJySDrQeRRgIPRUEPAoGAEc9OXlRTOlRyXKM7i0u5
Dak44bGFA7IMTWg4S8WrOfcDKhQl2s3OUyl/eLeFE1ip6DUTzzPqzCAONIFBfPF0
jK+8aP0c5duJvLOAsAuioD2+bqXEDVXK4FhX9IzgYxO7oKsTTE2VKNhNie49SFeK
FxBzaz833X+KGgOv4VBtDcY=
-----END PRIVATE KEY-----
"""

    // MARK: - 配置项

    /// MITM 功能是否启用
    @Published var 启用 = false {
        didSet { 保存配置() }
    }

    /// CA 证书（PEM 格式）
    @Published var CA证书: String = ""

    /// CA 私钥（PEM 格式）
    @Published var CA私钥: String = ""

    /// 证书元数据
    @Published var 元数据: 证书元数据?

    /// 当前MITM证书状态（缓存）
    @Published var 当前状态: MITM证书状态 = .文件缺失

    /// CA 证书是否已生成
    var 证书已生成: Bool {
        !CA证书.isEmpty && !CA私钥.isEmpty
    }

    /// 证书文件是否物理存在于沙盒
    var 证书文件存在: Bool {
        FileManager.default.fileExists(atPath: 证书文件URL.path)
    }

    /// MITM 功能是否可启用（证书文件存在且未过期）
    var 证书可启用: Bool {
        guard 证书文件存在, let 元数据 = 元数据 else { return false }
        return !元数据.已过期
    }

    // MARK: - 自动探测状态

    /// 自动探测：证书是否已安装到系统（nil表示探测失败）
    private(set) var 探测已安装: Bool?

    /// 自动探测：证书是否已在系统中完全信任（nil表示探测失败）
    private(set) var 探测已信任: Bool?

    /// 综合安装状态（自动探测优先，失败时用手动兜底）
    var 综合已安装: Bool {
        if let 探测 = 探测已安装 {
            return 探测
        }
        return 元数据?.手动确认已安装 ?? false
    }

    /// 综合信任状态（自动探测优先，失败时用手动兜底）
    var 综合已信任: Bool {
        if let 探测 = 探测已信任 {
            return 探测
        }
        return 元数据?.手动确认已信任 ?? false
    }

    /// 是否使用手动兜底模式（系统探测失败）
    var 使用手动兜底: Bool {
        探测已安装 == nil || 探测已信任 == nil
    }

    // MARK: - UserDefaults 键

    private let 启用键 = "mitmEnabled"
    private let 证书键 = "mitmCACertificate"
    private let 私钥键 = "mitmCAPrivateKey"
    private let 元数据键 = "mitmCertificateMetadata"
    private let 日志键 = "mitmCertificateLogs"

    // MARK: - 证书文件路径（动态读取，禁止硬编码）

    /// 动态获取 Documents 根目录
    private var 文档目录: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 证书文件存储目录（动态拼接，不硬编码完整路径）
    private var 证书目录: URL {
        文档目录.appendingPathComponent("MITM证书", isDirectory: true)
    }

    /// 证书文件路径（crt）
    private var 证书文件URL: URL {
        证书目录.appendingPathComponent("ca_certificate.crt")
    }

    /// 私钥文件路径（key）
    private var 私钥文件URL: URL {
        证书目录.appendingPathComponent("ca_private.key")
    }

    /// 确保证书目录存在，并设置不加入 iCloud 备份
    private func 确保证书目录() -> Bool {
        let 文件管理 = FileManager.default
        do {
            if !文件管理.fileExists(atPath: 证书目录.path) {
                try 文件管理.createDirectory(at: 证书目录, withIntermediateDirectories: true)
                添加证书日志(类型: "info", 消息: "证书目录已创建：\(证书目录.lastPathComponent)")
            }
            // 设置不加入 iCloud 备份，规避系统清理
            var 目录URL = 证书目录
            var 资源值 = URLResourceValues()
            资源值.isExcludedFromBackup = true
            try 目录URL.setResourceValues(资源值)
            return true
        } catch {
            添加证书日志(类型: "error", 消息: "证书目录创建/设置失败：\(error.localizedDescription)")
            return false
        }
    }

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

    /// 加载证书元数据
    private func 加载证书元数据() {
        let 默认 = UserDefaults.standard
        if let 数据 = 默认.data(forKey: 元数据键),
           let 元数据 = try? JSONDecoder().decode(证书元数据.self, from: 数据) {
            self.元数据 = 元数据
        }
        // 初始化时检测证书状态
        检测证书状态()
    }

    /// 保存证书元数据
    private func 保存证书元数据() {
        guard let 元数据 = 元数据 else { return }
        let 默认 = UserDefaults.standard
        if let 数据 = try? JSONEncoder().encode(元数据) {
            默认.set(数据, forKey: 元数据键)
        }
    }

    // MARK: - 证书自动探测

    /// 检测是否已完成（用于UI等待渲染）
    @Published private(set) var 检测完成 = false

    /// 实时从磁盘读取证书文件内容
    private func 读取磁盘证书() -> String? {
        guard FileManager.default.fileExists(atPath: 证书文件URL.path) else {
            return nil
        }
        return try? String(contentsOf: 证书文件URL, encoding: .utf8)
    }

    /// 实时从磁盘读取私钥文件内容
    private func 读取磁盘私钥() -> String? {
        guard FileManager.default.fileExists(atPath: 私钥文件URL.path) else {
            return nil
        }
        return try? String(contentsOf: 私钥文件URL, encoding: .utf8)
    }

    /// 获取文件大小
    private func 文件大小(_ 路径: String) -> Int {
        guard let 属性 = try? FileManager.default.attributesOfItem(atPath: 路径),
              let 大小 = 属性[.size] as? Int else {
            return 0
        }
        return 大小
    }

    /// 解析 PEM 证书为 Security framework 证书对象
    /// - Parameter 证书内容: PEM 格式证书字符串
    /// - Returns: SecCertificate?，解析失败返回 nil
    private func 解析PEM证书(证书内容: String) -> SecCertificate? {
        guard !证书内容.isEmpty else {
            return nil
        }

        // 移除 PEM 头尾，获取 Base64 内容
        let 内容 = 证书内容
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let 数据 = Data(base64Encoded: 内容) else {
            return nil
        }

        return SecCertificateCreateWithData(nil, 数据 as CFData)
    }

    /// 实时解析证书获取元数据（指纹、创建时间、过期时间）
    /// 预生成证书有效期固定10年，iOS 上 SecCertificateCopyValues 不可用，使用固定有效期
    /// - Returns: (指纹, 创建时间, 过期时间)?，解析失败返回 nil
    private func 实时解析证书元数据() -> (指纹: String, 创建时间: Date, 过期时间: Date)? {
        guard let 证书内容 = 读取磁盘证书(),
              解析PEM证书(证书内容: 证书内容) != nil else {
            return nil
        }

        // 计算指纹
        let 指纹 = 计算证书指纹(证书: 证书内容)

        // 预生成证书有效期固定10年，从文件创建时间计算
        let 文件属性 = try? FileManager.default.attributesOfItem(atPath: 证书文件URL.path)
        let 创建时间 = (文件属性?[.creationDate] as? Date) ?? Date()
        let 过期时间 = Calendar.current.date(byAdding: .year, value: 10, to: 创建时间) ?? 创建时间

        return (指纹, 创建时间, 过期时间)
    }

    /// 证书文件状态检测结果
    struct 证书文件状态 {
        let crt存在: Bool
        let key存在: Bool
        let crt大小: Int
        let key大小: Int
        let crt解析成功: Bool
        let key解析成功: Bool
        let 目录存在: Bool

        /// 双文件都存在且都能解析
        var 完全有效: Bool {
            crt存在 && key存在 && crt解析成功 && key解析成功
        }
    }

    /// 检测证书文件状态（同时检测 crt 和 key）
    private func 检测证书文件状态() -> 证书文件状态 {
        let 文件管理 = FileManager.default
        var 是目录: ObjCBool = false
        let 目录存在 = 文件管理.fileExists(atPath: 证书目录.path, isDirectory: &是目录) && 是目录.boolValue

        let crt存在 = 文件管理.fileExists(atPath: 证书文件URL.path)
        let key存在 = 文件管理.fileExists(atPath: 私钥文件URL.path)
        let crt大小 = 文件大小(证书文件URL.path)
        let key大小 = 文件大小(私钥文件URL.path)

        // 解析 crt
        let crt内容 = 读取磁盘证书()
        let crt解析成功 = crt内容 != nil && 解析PEM证书(证书内容: crt内容!) != nil

        // 解析 key（简单检查 PEM 格式）
        let key内容 = 读取磁盘私钥()
        let key解析成功 = key内容 != nil && key内容!.contains("PRIVATE KEY")

        return 证书文件状态(
            crt存在: crt存在,
            key存在: key存在,
            crt大小: crt大小,
            key大小: key大小,
            crt解析成功: crt解析成功,
            key解析成功: key解析成功,
            目录存在: 目录存在
        )
    }

    /// 探测证书是否已安装到系统描述文件
    /// iOS沙盒限制：无法直接读取系统描述文件列表，通过钥匙串查询间接判断
    /// - Returns: true=已安装，false=未安装，nil=探测失败（权限限制）
    private func 探测证书安装状态() -> Bool? {
        guard let 证书内容 = 读取磁盘证书(),
              let 证书 = 解析PEM证书(证书内容: 证书内容) else {
            添加证书日志(类型: "warning", 消息: "安装状态探测：从磁盘读取/解析证书失败，无法探测")
            return nil
        }

        // 通过钥匙串查询是否存在该证书（间接判断是否已安装）
        let 查询: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecMatchItemList as String: [证书],
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var 结果: AnyObject?
        let 状态 = SecItemCopyMatching(查询 as CFDictionary, &结果)

        if 状态 == errSecSuccess {
            添加证书日志(类型: "success", 消息: "安装状态探测：钥匙串中找到匹配证书，判定已安装")
            return true
        } else if 状态 == errSecItemNotFound {
            // 注意：iOS应用无法访问系统全局钥匙串，这里可能误判
            // 应用自己导入的证书才能在钥匙串中找到
            添加证书日志(类型: "info", 消息: "安装状态探测：钥匙串中未找到证书（iOS沙盒限制，可能误判）")
            return false
        } else {
            添加证书日志(类型: "warning", 消息: "安装状态探测：SecItemCopyMatching失败，错误码=\(状态)")
            return nil
        }
    }

    /// 探测证书是否已在系统中完全信任
    /// iOS沙盒限制：无法读取用户在设置中手动开启的根证书信任状态
    /// 通过 SecTrustEvaluate 评估证书链信任（仅能评估系统默认信任策略）
    /// - Returns: true=已信任，false=未信任，nil=探测失败（权限限制）
    private func 探测证书信任状态() -> Bool? {
        guard let 证书内容 = 读取磁盘证书(),
              let 证书 = 解析PEM证书(证书内容: 证书内容) else {
            添加证书日志(类型: "warning", 消息: "信任状态探测：从磁盘读取/解析证书失败，无法探测")
            return nil
        }

        // 构造信任对象进行评估
        var 信任: SecTrust?
        let 策略 = SecPolicyCreateBasicX509()
        let 创建状态 = SecTrustCreateWithCertificates([证书] as CFArray, 策略, &信任)

        guard 创建状态 == errSecSuccess, let 信任对象 = 信任 else {
            添加证书日志(类型: "warning", 消息: "信任状态探测：SecTrustCreateWithCertificates失败，错误码=\(创建状态)")
            return nil
        }

        // 评估信任（注意：这只能评估系统默认策略，无法检测用户手动开启的完全信任）
        var 错误: CFError?
        let 可信 = SecTrustEvaluateWithError(信任对象, &错误)

        if 可信 {
            添加证书日志(类型: "success", 消息: "信任状态探测：SecTrust评估通过，证书受系统信任")
            return true
        } else {
            let 错误描述 = 错误?.localizedDescription ?? "未知错误"
            添加证书日志(类型: "info", 消息: "信任状态探测：SecTrust评估未通过（iOS沙盒限制，无法检测用户手动完全信任设置），错误=\(错误描述)")
            // iOS限制：自签名根证书默认不受系统信任，需要用户在设置中手动开启
            // 这里返回nil表示无法确定，启用手动兜底
            return nil
        }
    }

    /// 执行全部自动探测（安装+信任）
    func 执行自动探测() {
        添加证书日志(类型: "info", 消息: "===== 开始证书状态自动探测 =====")

        // 探测安装状态
        探测已安装 = 探测证书安装状态()
        if 探测已安装 == nil {
            添加证书日志(类型: "warning", 消息: "安装状态探测失败，将启用手动确认兜底")
        }

        // 探测信任状态
        探测已信任 = 探测证书信任状态()
        if 探测已信任 == nil {
            添加证书日志(类型: "warning", 消息: "信任状态探测失败（iOS沙盒限制），将启用手动确认兜底")
        }

        // 更新元数据中的探测失败标记
        if var 元数据 = 元数据 {
            元数据.系统探测失败 = 使用手动兜底
            self.元数据 = 元数据
            保存证书元数据()
        }

        添加证书日志(类型: "info", 消息: "自动探测结果：已安装=\(探测已安装 == nil ? "未知" : (探测已安装! ? "是" : "否"))，已信任=\(探测已信任 == nil ? "未知" : (探测已信任! ? "是" : "否"))，使用手动兜底=\(使用手动兜底 ? "是" : "否")")
        添加证书日志(类型: "info", 消息: "===== 证书状态自动探测完成 =====")
    }

    // MARK: - MITM证书状态检测

    /// 检测证书状态（实时从磁盘检测，不依赖缓存元数据）
    /// 优先级：目录存在 > crt+key双文件存在 > PEM解析 > 指纹 > 过期 > 安装 > 信任
    /// - Returns: MITM证书状态
    @discardableResult
    func 检测证书状态() -> MITM证书状态 {
        // 1. 实时检测证书文件状态（同时检测 crt 和 key）
        let 文件状态 = 检测证书文件状态()
        添加证书日志(类型: "info", 消息: "文件状态：目录=\(文件状态.目录存在 ? "存在" : "丢失")，crt=\(文件状态.crt存在 ? "存在(\(文件状态.crt大小)B)" : "丢失")，key=\(文件状态.key存在 ? "存在(\(文件状态.key大小)B)" : "丢失")，crt解析=\(文件状态.crt解析成功 ? "成功" : "失败")，key解析=\(文件状态.key解析成功 ? "成功" : "失败")")

        // 2. 检查目录是否存在
        guard 文件状态.目录存在 else {
            if 元数据 != nil { 完全重置证书元数据() }
            if 启用 { 启用 = false }
            当前状态 = .文件缺失
            添加证书日志(类型: "error", 消息: "检测结果：证书目录丢失")
            return .文件缺失
        }

        // 3. 检查 crt 和 key 是否都存在
        guard 文件状态.crt存在 && 文件状态.key存在 else {
            if 元数据 != nil { 完全重置证书元数据() }
            if 启用 { 启用 = false }
            if !文件状态.crt存在 {
                添加证书日志(类型: "error", 消息: "检测结果：crt证书文件缺失")
            } else {
                添加证书日志(类型: "error", 消息: "检测结果：key私钥文件缺失")
            }
            当前状态 = .文件缺失
            return .文件缺失
        }

        // 4. 检查 crt 和 key 是否都能正常解析
        guard 文件状态.crt解析成功 && 文件状态.key解析成功 else {
            if 元数据 != nil { 完全重置证书元数据() }
            if 启用 { 启用 = false }
            添加证书日志(类型: "error", 消息: "检测结果：证书文件损坏或私钥丢失（PEM解析失败）")
            当前状态 = .文件损坏
            return .文件损坏
        }

        // 5. 实时解析证书元数据（指纹、创建时间、过期时间）
        guard let 实时元数据 = 实时解析证书元数据() else {
            添加证书日志(类型: "error", 消息: "检测结果：实时解析证书元数据失败")
            当前状态 = .文件损坏
            return .文件损坏
        }

        // 6. 同步内存中的证书内容（从磁盘读取）
        if let 磁盘证书 = 读取磁盘证书() {
            CA证书 = 磁盘证书
        }
        if let 磁盘私钥 = 读取磁盘私钥() {
            CA私钥 = 磁盘私钥
        }

        // 7. 更新元数据（实时解析结果，不使用缓存）
        元数据 = 证书元数据(
            文件存在: true,
            指纹: 实时元数据.指纹,
            创建时间: 实时元数据.创建时间,
            过期时间: 实时元数据.过期时间,
            文件路径: 证书文件URL.path,
            系统探测失败: 使用手动兜底,
            手动确认已安装: 元数据?.手动确认已安装 ?? false,
            手动确认已信任: 元数据?.手动确认已信任 ?? false
        )
        保存证书元数据()

        // 8. 检查是否过期
        let 剩余天数 = 日历_剩余天数(过期时间: 实时元数据.过期时间)
        if 剩余天数 <= 0 {
            当前状态 = .已过期
            添加证书日志(类型: "error", 消息: "检测结果：证书已过期")
            return .已过期
        }

        // 9. 检查是否临近过期
        if 剩余天数 <= 30 {
            当前状态 = .临近过期(剩余天数: 剩余天数)
            添加证书日志(类型: "warning", 消息: "检测结果：证书临近过期，剩余 \(剩余天数) 天")
            return .临近过期(剩余天数: 剩余天数)
        }

        // 10. 检查证书是否已安装（自动探测优先，失败时用手动兜底）
        guard 综合已安装 else {
            当前状态 = .未安装
            添加证书日志(类型: "info", 消息: "检测结果：未安装")
            return .未安装
        }

        // 11. 检查证书是否已信任（自动探测优先，失败时用手动兜底）
        guard 综合已信任 else {
            当前状态 = .未信任
            添加证书日志(类型: "info", 消息: "检测结果：未信任")
            return .未信任
        }

        // 全部通过
        当前状态 = .就绪
        添加证书日志(类型: "success", 消息: "检测结果：就绪，指纹=\(String(实时元数据.指纹.prefix(16)))...，剩余\(剩余天数)天")
        return .就绪
    }

    /// 计算剩余天数
    private func 日历_剩余天数(过期时间: Date) -> Int {
        let 日历 = Calendar.current
        let 组件 = 日历.dateComponents([.day], from: Date(), to: 过期时间)
        return 组件.day ?? 0
    }

    /// 页面出现时执行完整检测（等待文件读取+PEM解析完成后再渲染UI）
    func 页面出现时检测() {
        检测完成 = false
        添加证书日志(类型: "info", 消息: "===== 页面加载，开始证书状态检测 =====")
        // 执行自动探测（安装+信任状态）
        执行自动探测()
        // 实时检测证书状态（从磁盘读取+PEM解析）
        检测证书状态()
        检测完成 = true
        添加证书日志(类型: "info", 消息: "===== 检测完成，最终状态：\(当前状态.描述) =====")
    }

    /// 完全重置证书元数据（文件丢失时调用）
    /// 清除内存中元数据 + 删除 UserDefaults 持久化记录
    private func 完全重置证书元数据() {
        元数据 = nil
        UserDefaults.standard.removeObject(forKey: 元数据键)
        添加证书日志(类型: "info", 消息: "已完全重置证书元数据（内存+持久化）")
    }

    /// 手动兜底确认已安装（仅系统探测失败时使用）
    func 标记已安装() {
        guard var 元数据 = 元数据 else { return }
        元数据.手动确认已安装 = true
        self.元数据 = 元数据
        保存证书元数据()
        检测证书状态()
        添加证书日志(类型: "info", 消息: "手动兜底确认：已安装证书（系统探测失败备用方案）")
    }

    /// 手动兜底确认已信任（仅系统探测失败时使用）
    func 标记已信任() {
        guard var 元数据 = 元数据 else { return }
        元数据.手动确认已信任 = true
        self.元数据 = 元数据
        保存证书元数据()
        检测证书状态()
        添加证书日志(类型: "info", 消息: "手动兜底确认：已信任证书（系统探测失败备用方案）")
    }

    // MARK: - CA 证书管理

    /// 生成 CA 证书（使用预生成的证书，确保格式正确可被 iOS 识别）
    /// 证书已存在且有效时跳过生成
    /// - Returns: 是否生成成功
    @discardableResult
    func 生成CA证书() -> Bool {
        // 智能检测：证书已存在且有效时跳过生成
        if 检测证书状态().可使用 {
            NSLog("[MITM] 证书已就绪，跳过生成")
            添加证书日志(类型: "info", 消息: "证书已就绪，跳过生成")
            return true
        }

        CA证书 = MITM管理器.预生成CA证书
        CA私钥 = MITM管理器.预生成CA私钥
        保存配置()

        // 确保证书目录存在（设置不加入iCloud备份）
        guard 确保证书目录() else {
            添加证书日志(类型: "error", 消息: "证书目录创建失败")
            return false
        }

        // 成对原子写入 crt + key，缺少任意一个判定生成失败
        do {
            try CA证书.write(to: 证书文件URL, atomically: true, encoding: .utf8)
            try CA私钥.write(to: 私钥文件URL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("[MITM] 写入证书文件失败：\(error.localizedDescription)")
            添加证书日志(类型: "error", 消息: "成对写入crt+key失败：\(error.localizedDescription)")
            // 写入失败时清理部分文件
            try? FileManager.default.removeItem(at: 证书文件URL)
            try? FileManager.default.removeItem(at: 私钥文件URL)
            return false
        }

        // 验证双文件都写入成功
        let 文件状态 = 检测证书文件状态()
        guard 文件状态.完全有效 else {
            添加证书日志(类型: "error", 消息: "写入验证失败：crt=\(文件状态.crt存在 ? "存在" : "丢失")，key=\(文件状态.key存在 ? "存在" : "丢失")，crt解析=\(文件状态.crt解析成功 ? "成功" : "失败")，key解析=\(文件状态.key解析成功 ? "成功" : "失败")")
            return false
        }

        // 实时解析证书元数据
        guard let 实时元数据 = 实时解析证书元数据() else {
            添加证书日志(类型: "error", 消息: "生成后实时解析证书元数据失败")
            return false
        }

        元数据 = 证书元数据(
            文件存在: true,
            指纹: 实时元数据.指纹,
            创建时间: 实时元数据.创建时间,
            过期时间: 实时元数据.过期时间,
            文件路径: 证书文件URL.path,
            系统探测失败: false,
            手动确认已安装: false,
            手动确认已信任: false
        )
        保存证书元数据()

        NSLog("[MITM] CA 证书生成成功（crt+key成对原子写入，RSA 2048，有效期10年）")
        添加证书日志(类型: "success", 消息: "CA证书生成成功，crt+key成对写入并验证通过，指纹：\(String(实时元数据.指纹.prefix(16)))...")

        // 重新检测状态
        检测证书状态()
        return true
    }

    /// 导出 CA 证书为 Data（用于分享/安装）
    func 导出证书数据() -> Data? {
        guard 证书已生成 else { return nil }
        return CA证书.data(using: .utf8)
    }

    /// 清除 CA 证书（手动重置，同时删除 crt 和 key 文件）
    func 清除证书() {
        CA证书 = ""
        CA私钥 = ""
        启用 = false
        元数据 = nil
        当前状态 = .文件缺失
        保存配置()

        // 同时删除 crt 和 key 文件
        try? FileManager.default.removeItem(at: 证书文件URL)
        try? FileManager.default.removeItem(at: 私钥文件URL)

        // 清除元数据
        UserDefaults.standard.removeObject(forKey: 元数据键)

        添加证书日志(类型: "info", 消息: "证书已手动重置（crt+key已删除）")
        NSLog("[MITM] CA 证书已清除")
    }

    /// 检查是否需要提示临近过期
    /// - Returns: 是否需要提示
    func 需要提示临近过期() -> Bool {
        guard let 元数据 = 元数据 else { return false }
        return 元数据.临近过期
    }

    // MARK: - 配置获取

    /// 获取 MITM 出站配置（供 sing-box 配置生成器使用）
    /// 证书有效时直接复用，不重复生成
    func 获取MITM出站配置() -> (证书: String, 私钥: String)? {
        guard 启用, 证书已生成 else { return nil }

        // 内核加载前校验证书
        let 状态 = 检测证书状态()
        guard 状态.可使用 || 状态 == .未安装 || 状态 == .未信任 else {
            NSLog("[MITM] MITM证书状态异常(\(状态.描述))，无法启用 MITM")
            添加证书日志(类型: "error", 消息: "内核加载 MITM 失败：\(状态.描述)")
            return nil
        }

        添加证书日志(类型: "info", 消息: "内核加载 MITM 出站配置，证书复用")
        return (CA证书, CA私钥)
    }

    // MARK: - 证书指纹计算

    /// 计算证书 SHA-256 指纹
    private func 计算证书指纹(证书: String) -> String {
        // 移除 PEM 头尾和换行，获取 Base64 内容
        var 内容 = 证书
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let 数据 = Data(base64Encoded: 内容) else {
            return ""
        }

        // 计算 SHA-256
        var 哈希 = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        数据.withUnsafeBytes { 缓冲区 in
            _ = CC_SHA256(缓冲区.baseAddress, CC_LONG(数据.count), &哈希)
        }

        // 转换为十六进制字符串
        return 哈希.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 证书日志

    /// 证书日志条目
    struct 证书日志: Codable, Identifiable {
        let id: UUID
        let 时间: Date
        let 类型: String  // info/success/warning/error
        let 消息: String

        init(类型: String, 消息: String) {
            self.id = UUID()
            self.时间 = Date()
            self.类型 = 类型
            self.消息 = 消息
        }
    }

    /// 添加证书日志
    func 添加证书日志(类型: String, 消息: String) {
        var 日志列表 = 获取证书日志()
        日志列表.insert(证书日志(类型: 类型, 消息: 消息), at: 0)
        // 最多保留 100 条
        if 日志列表.count > 100 {
            日志列表 = Array(日志列表.prefix(100))
        }

        let 默认 = UserDefaults.standard
        if let 数据 = try? JSONEncoder().encode(日志列表) {
            默认.set(数据, forKey: 日志键)
        }
    }

    /// 获取证书日志
    func 获取证书日志() -> [证书日志] {
        let 默认 = UserDefaults.standard
        guard let 数据 = 默认.data(forKey: 日志键),
              let 日志 = try? JSONDecoder().decode([证书日志].self, from: 数据) else {
            return []
        }
        return 日志
    }

    /// 清空证书日志
    func 清空证书日志() {
        UserDefaults.standard.removeObject(forKey: 日志键)
    }

    // MARK: - 辅助方法

    /// 格式化日期为 yyyy-MM-dd
    private func 格式化日期(_ 日期: Date) -> String {
        let 格式化器 = DateFormatter()
        格式化器.dateFormat = "yyyy-MM-dd"
        return 格式化器.string(from: 日期)
    }
}
