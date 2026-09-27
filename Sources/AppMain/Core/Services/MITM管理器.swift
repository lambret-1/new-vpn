//
//  MITM管理器.swift
//  NewVPN
//
//  MITM（HTTPS 中间人解密）功能管理
//  负责 CA 证书管理、配置持久化
//  CA 证书为预生成的自签名根证书，有效期 10 年
//

import Foundation

// MARK: - MITM 管理器

/// MITM 功能管理器
final class MITM管理器: ObservableObject {
    /// 共享单例
    static let 共享 = MITM管理器()

    /// 私有初始化
    private init() {
        加载配置()
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

    // MARK: - CA 证书管理

    /// 生成 CA 证书（使用预生成的证书，确保格式正确可被 iOS 识别）
    /// - Returns: 是否生成成功
    @discardableResult
    func 生成CA证书() -> Bool {
        CA证书 = MITM管理器.预生成CA证书
        CA私钥 = MITM管理器.预生成CA私钥
        保存配置()
        NSLog("[MITM] CA 证书加载成功（预生成证书，RSA 2048，有效期10年）")
        return true
    }

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
    }

    // MARK: - 配置获取

    /// 获取 MITM 出站配置（供 sing-box 配置生成器使用）
    func 获取MITM出站配置() -> (证书: String, 私钥: String)? {
        guard 启用, 证书已生成 else { return nil }
        return (CA证书, CA私钥)
    }
}
