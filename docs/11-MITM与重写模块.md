# 11 - MITM 与 HTTP 重写模块

## 11.1 职责

- CA 根证书生成、导出、安装指引
- TLS 中间人解密
- HTTP 请求 / 响应重写规则管理
- 规则输出至 sing-box 配置
- 与抓包模块联动

## 11.2 工作原理

```
TUN 捕获 HTTPS 流量（443 端口）
    ↓
路由匹配命中 MITM 规则（enableMitm = true）
    ↓
MITM 引擎拦截 TLS 握手
    ↓
使用自签发证书与客户端握手（伪装成目标网站）
    ↓
同时向上游真实服务器建立 TLS 连接
    ↓
双向隧道建立，明文暴露
    ↓
执行重写规则链
    ↓
修改后的数据转发给对端
```

## 11.3 前置条件

| 条件 | 说明 |
| --- | --- |
| 根证书信任 | 必须安装到系统并标记为信任 |
| TLS 版本 | 仅支持 TLS 1.2 / 1.3 |
| HSTS 站点 | 会强制证书校验，MITM 失败 |
| 启用范围 | 默认不全局开启，按需针对特定域名 |

## 11.4 CA 证书管理

| 操作 | 说明 |
| --- | --- |
| 生成 | 首次启动自动生成自签名根 CA |
| 持久化 | 私钥加密存储，不明文保存 |
| 导出 | 支持 `.crt` / `.pem` 格式 |
| 安装指引 | 分平台图文指引弹窗 |
| 重置 | 重新生成 CA，需重新安装信任 |

## 11.5 MITM 匹配控制

MITM 不是全局开关，由分流规则控制：

- 分流规则新增 `enableMitm` 标记
- 标记为 true 的域名启用 MITM
- 未标记的流量透传原始 TLS
- 可同时作用于代理出站和直连出站

## 11.6 重写动作类型

| 动作 | 说明 | 示例 |
| --- | --- | --- |
| `requestHeaderAdd` | 添加请求头 | 添加 `X-Custom: value` |
| `requestHeaderRemove` | 删除请求头 | 删除 `Cookie` |
| `responseHeaderAdd` | 添加响应头 | 添加 `Access-Control-Allow-Origin: *` |
| `responseHeaderRemove` | 删除响应头 | 删除 `Content-Security-Policy` |
| `pathReplace` | 路径固定替换 | `/old` → `/new` |
| `pathRegexReplace` | 路径正则替换 | `^/api/(.*)` → `/v2/api/$1` |
| `responseBodyRegex` | 响应体正则替换 | 替换广告脚本 |
| `redirect302` | 302 跳转 | 重定向到新地址 |
| `localResponse` | 直接返回自定义响应 | 本地模拟返回 |
| `deny` | 拒绝请求 | 返回 403 |

## 11.7 数据模型

```swift
struct RewriteRule: Identifiable, Codable {
    let id: String
    var name: String
    var enable: Bool
    var match: RewriteMatch
    var actionType: RewriteActionType
    var regex: String?
    var replace: String?
    var remark: String
    var priority: Int
}

struct RewriteMatch: Codable {
    var domainSuffix: String?
    var pathRegex: String?
    var method: String?
    var requestHeader: [String: String]?
}

enum RewriteActionType: String, Codable {
    case requestHeaderAdd
    case requestHeaderRemove
    case responseHeaderAdd
    case responseHeaderRemove
    case pathReplace
    case pathRegexReplace
    case responseBodyRegex
    case redirect302
    case localResponse
    case deny
}
```

## 11.8 执行顺序

```
MITM 解密完成
    ↓
按 priority 排序重写规则
    ↓
逐条匹配：
    ├─ 匹配域名条件
    ├─ 匹配路径条件
    ├─ 匹配方法条件
    └─ 命中 → 执行动作
    ↓
请求阶段规则执行
    ↓
转发到上游服务器
    ↓
响应阶段规则执行
    ↓
返回给客户端
```

## 11.9 性能保护

| 策略 | 说明 |
| --- | --- |
| 站点证书缓存 | 减少重复证书生成开销 |
| 按需启用 | 仅命中域名启用 MITM |
| 正则超时 | 防止恶意正则阻塞 |
| 大文件跳过 | 图片 / 视频 / 二进制不执行 Body 重写 |
| 明文日志开关 | 默认关闭，按需开启 |

## 11.10 边界限制

| 限制 | 说明 |
| --- | --- |
| QUIC（UDP 443） | 无法 MITM，规则阻断降级 HTTP/1.1 |
| HSTS + HPKP | 站点强制证书校验，MITM 失败 |
| HTTP/2 | 支持 |
| HTTP/3（QUIC） | 不支持 |

## 11.11 核心 API

```swift
final class MITMManager {
    static let shared = MITMManager()

    func loadCA() throws
    func exportCACertificate() throws -> Data
    func resetCA() throws

    func loadRewriteRules() throws
    func addRewriteRule(_ rule: RewriteRule) throws
    func updateRewriteRule(_ rule: RewriteRule) throws
    func deleteRewriteRule(id: String) throws

    func renderConfig() throws -> [String: Any]
}
```

## 11.12 容错策略

| 异常 | 处理 |
| --- | --- |
| 证书未信任 | MITM 握手失败，记录日志，走透传 |
| HSTS 站点 | 握手失败，记录 WARN，走透传 |
| 正则语法错误 | 跳过该规则，记录 ERROR |
| 重写执行异常 | 捕获异常，走原始响应 |
| CA 私钥读取失败 | MITM 功能不可用，记录 ERROR |
