# 11 - MITM 与 HTTP 重写模块

## 11.1 职责

- CA 根证书生成、导出、安装指引
- TLS 中间人解密
- HTTP 请求 / 响应重写规则管理
- 规则输出至 sing-box 配置

## 11.2 工作原理

```
TUN 捕获 HTTPS 流量
    → 路由匹配命中 MITM 规则
    → 客户端 MITM 引擎拦截 TLS 握手
    → 使用自签发证书与客户端握手
    → 同时向上游真实服务器建立 TLS 连接
    → 双向隧道建立，明文暴露
    → 执行重写规则
    → 修改后转发
```

## 11.3 前置条件

- 根 CA 证书必须安装到系统并标记信任
- 仅支持 TLS 1.2 / 1.3
- HSTS 站点会强制证书校验，MITM 失败
- 默认不全局开启 MITM，按需针对特定域名启用

## 11.4 CA 证书管理

- 首次启动自动生成自签名根 CA（持久化保存）
- 支持导出 `.crt` / `.pem`
- 多平台安装指引
- 支持重置 CA 证书
- 私钥加密存储，不明文保存

## 11.5 MITM 匹配控制

MITM 不是全局开关，由路由规则控制：

- 分流规则新增 `enableMitm` 标记
- 标记为 true 的域名启用 MITM
- 未标记的流量透传原始 TLS

## 11.6 重写动作类型

| 动作 | 说明 |
| --- | --- |
| requestHeaderAdd | 添加请求头 |
| requestHeaderRemove | 删除请求头 |
| responseHeaderAdd | 添加响应头 |
| responseHeaderRemove | 删除响应头 |
| pathReplace | 路径固定替换 |
| pathRegexReplace | 路径正则替换 |
| responseBodyRegex | 响应体正则替换 |
| redirect302 | 302 跳转 |
| localResponse | 直接返回自定义响应 |
| deny | 拒绝请求 |

## 11.7 数据模型

```swift
struct RewriteRule: Identifiable, Codable {
    let id: String
    var name: String
    var enable: Bool
    var match: RewriteMatch
    var actionType: String
    var regex: String?
    var replace: String?
    var remark: String
}

struct RewriteMatch: Codable {
    var domainSuffix: String?
    var pathRegex: String?
    var method: String?
}
```

## 11.8 性能保护

- 站点证书缓存，减少重复生成
- 仅命中域名启用 MITM
- 正则超时保护
- 明文日志开关
- 大文件跳过（图片 / 视频）

## 11.9 边界限制

- QUIC（UDP 443）无法 MITM
- HSTS + HPKP 站点失败
- HTTP/2 支持
- HTTP/3 不支持

## 11.10 核心 API

```swift
final class MITMManager {
    static let shared = MITMManager()

    func loadCA() throws
    func exportCACertificate() throws -> Data
    func resetCA() throws
    func addRewriteRule(_ rule: RewriteRule) throws
    func updateRewriteRule(_ rule: RewriteRule) throws
    func deleteRewriteRule(id: String) throws
    func renderConfig() throws -> [String: Any]
}
```
