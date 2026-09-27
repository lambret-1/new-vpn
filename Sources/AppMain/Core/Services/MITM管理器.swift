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
    /// 证书指纹（SHA-256）
    var 指纹: String
    /// 创建时间
    var 创建时间: Date
    /// 过期时间
    var 过期时间: Date
    /// 证书文件路径（沙盒内）
    var 文件路径: String
    /// 用户是否已确认安装描述文件
    var 用户确认已安装: Bool
    /// 用户是否已确认在设置中信任
    var 用户确认已信任: Bool

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

    // MARK: - UserDefaults 键

    private let 启用键 = "mitmEnabled"
    private let 证书键 = "mitmCACertificate"
    private let 私钥键 = "mitmCAPrivateKey"
    private let 元数据键 = "mitmCertificateMetadata"
    private let 日志键 = "mitmCertificateLogs"

    // MARK: - 证书文件路径

    /// 证书文件存储目录
    private var 证书目录: URL {
        let 文档目录 = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return 文档目录.appendingPathComponent("MITM证书", isDirectory: true)
    }

    /// 证书文件路径
    private var 证书文件URL: URL {
        证书目录.appendingPathComponent("ca_certificate.crt")
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

    // MARK: - MITM证书状态检测

    /// 检测证书状态（智能校验）
    /// - Returns: MITM证书状态
    @discardableResult
    func 检测证书状态() -> MITM证书状态 {
        // 1. 检查证书内容是否存在
        guard 证书已生成 else {
            当前状态 = .文件缺失
            添加证书日志(类型: "error", 消息: "MITM证书状态检测：证书内容缺失")
            return .文件缺失
        }

        // 2. 检查证书文件是否存在
        guard FileManager.default.fileExists(atPath: 证书文件URL.path) else {
            当前状态 = .文件缺失
            添加证书日志(类型: "error", 消息: "MITM证书状态检测：证书文件不存在")
            return .文件缺失
        }

        // 3. 检查元数据
        guard let 元数据 = 元数据 else {
            当前状态 = .文件损坏
            添加证书日志(类型: "error", 消息: "MITM证书状态检测：证书元数据缺失")
            return .文件损坏
        }

        // 4. 验证证书指纹是否匹配
        let 当前指纹 = 计算证书指纹(证书: CA证书)
        guard 当前指纹 == 元数据.指纹 else {
            当前状态 = .文件损坏
            添加证书日志(类型: "error", 消息: "MITM证书状态检测：指纹不匹配")
            return .文件损坏
        }

        // 5. 检查是否过期
        if 元数据.已过期 {
            当前状态 = .已过期
            添加证书日志(类型: "error", 消息: "MITM证书状态检测：证书已过期")
            return .已过期
        }

        // 6. 检查是否临近过期
        if 元数据.临近过期 {
            当前状态 = .临近过期(剩余天数: 元数据.剩余天数)
            添加证书日志(类型: "warning", 消息: "MITM证书状态检测：证书临近过期，剩余 \(元数据.剩余天数) 天")
            return .临近过期(剩余天数: 元数据.剩余天数)
        }

        // 7. 检查用户是否确认已安装
        guard 元数据.用户确认已安装 else {
            当前状态 = .未安装
            添加证书日志(类型: "info", 消息: "MITM证书状态检测：证书未安装")
            return .未安装
        }

        // 8. 检查用户是否确认已信任
        guard 元数据.用户确认已信任 else {
            当前状态 = .未信任
            添加证书日志(类型: "info", 消息: "MITM证书状态检测：证书未信任")
            return .未信任
        }

        // 全部通过
        当前状态 = .就绪
        添加证书日志(类型: "success", 消息: "MITM证书状态检测：证书就绪")
        return .就绪
    }

    /// 标记用户已安装证书
    func 标记已安装() {
        guard var 元数据 = 元数据 else { return }
        元数据.用户确认已安装 = true
        self.元数据 = 元数据
        保存证书元数据()
        检测证书状态()
        添加证书日志(类型: "info", 消息: "用户确认已安装证书")
    }

    /// 标记用户已信任证书
    func 标记已信任() {
        guard var 元数据 = 元数据 else { return }
        元数据.用户确认已信任 = true
        self.元数据 = 元数据
        保存证书元数据()
        检测证书状态()
        添加证书日志(类型: "info", 消息: "用户确认已信任证书")
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

        // 写入证书文件
        do {
            try FileManager.default.createDirectory(at: 证书目录, withIntermediateDirectories: true)
            try CA证书.write(to: 证书文件URL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("[MITM] 写入证书文件失败：\(error.localizedDescription)")
            添加证书日志(类型: "error", 消息: "写入证书文件失败：\(error.localizedDescription)")
            return false
        }

        // 计算指纹和元数据
        let 指纹 = 计算证书指纹(证书: CA证书)
        let 创建时间 = Date()
        // 预生成证书有效期 10 年
        let 过期时间 = Calendar.current.date(byAdding: .year, value: 10, to: 创建时间) ?? 创建时间

        元数据 = 证书元数据(
            指纹: 指纹,
            创建时间: 创建时间,
            过期时间: 过期时间,
            文件路径: 证书文件URL.path,
            用户确认已安装: false,
            用户确认已信任: false
        )
        保存证书元数据()

        NSLog("[MITM] CA 证书生成成功（预生成证书，RSA 2048，有效期10年）")
        添加证书日志(类型: "success", 消息: "CA 证书生成成功，指纹：\(String(指纹.prefix(16)))...")

        // 重新检测状态
        检测证书状态()
        return true
    }

    /// 导出 CA 证书为 Data（用于分享/安装）
    func 导出证书数据() -> Data? {
        guard 证书已生成 else { return nil }
        return CA证书.data(using: .utf8)
    }

    /// 清除 CA 证书（手动重置）
    func 清除证书() {
        CA证书 = ""
        CA私钥 = ""
        启用 = false
        元数据 = nil
        当前状态 = .文件缺失
        保存配置()

        // 删除证书文件
        try? FileManager.default.removeItem(at: 证书文件URL)

        // 清除元数据
        UserDefaults.standard.removeObject(forKey: 元数据键)

        添加证书日志(类型: "info", 消息: "证书已手动重置")
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
}
