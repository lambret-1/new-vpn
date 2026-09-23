# 12 - HTTP 抓包模块

## 12.1 职责

- 捕获 MITM 解密后的 HTTP / HTTPS 会话
- 会话列表、请求 / 响应头 / Body 查看
- JSON 自动格式化
- 会话过滤、清空
- HAR 导出

> 依赖 MITM。未开启 MITM 的 TLS 连接只能记录五元组，无法获取明文。

## 12.2 数据模型

```swift
struct HttpSession: Identifiable {
    let id: String
    let timestamp: Date
    let method: String
    let host: String
    let path: String
    let fullUrl: String
    let statusCode: Int
    let sourceIP: String
    let sourcePort: Int
    let destIP: String
    let destPort: Int
    let requestHeaders: [String: String]
    let requestBody: String        // Base64
    let responseHeaders: [String: String]
    let responseBody: String       // Base64
    let requestBodySize: Int
    let responseBodySize: Int
    let costMs: Int
    let isBinary: Bool              // Body 是否为二进制
}
```

## 12.3 内存策略

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| 最大会话数 | 500 | 环形缓冲区，FIFO 淘汰 |
| 文本 Body 截断 | 256KB | 超出截断 |
| 二进制 Body | 不保存 | 仅记录大小 |

### Body 截断规则

| Content-Type | 处理方式 |
| --- | --- |
| text/*, application/json, application/javascript | 保存文本，截断到 256KB |
| image/*, video/*, audio/* | 不保存 Body，仅记录大小 |
| application/octet-stream | 不保存 Body |
| 其他 | 默认按文本处理 |

## 12.4 抓取范围

两种模式：

### 跟随 MITM（默认）

- 只抓取 MITM 命中域名
- 未开启 MITM 的连接不捕获

### 自定义白名单

- 独立抓取规则
- 按域名匹配
- 不依赖 MITM 启用状态

## 12.5 导出格式

| 格式 | 说明 | 用途 |
| --- | --- | --- |
| HAR | HTTP Archive | 导入 Chrome / Charles |
| JSON | 结构化数据 | 脚本二次处理 |
| TXT | 简易文本日志 | 快速查阅 |

导出范围选项：

- 导出全部会话
- 导出选中会话
- 导出过滤后会话

## 12.6 数据流转

```
MITM 解密 HTTP 流
    ↓
旁路钩子（只读，不阻塞主链路）
    ↓
解析请求 / 响应
    ↓
Base64 编码 Body
    ↓
写入环形缓冲区
    ↓
UI 每 200ms 批量刷新列表
```

## 12.7 核心 API

```swift
final class HttpCaptureManager {
    static let shared = HttpCaptureManager()

    /// 总开关
    var isEnabled: Bool { get set }

    /// 暂停 / 继续
    func pause()
    func resume()

    /// 清空会话
    func clearSessions()

    /// 获取会话列表
    func getSessions(filter: CaptureFilter?) -> [HttpSession]

    /// 导出会话
    func exportSessions(format: ExportFormat, sessions: [HttpSession]) throws -> URL
}

struct CaptureFilter {
    var keyword: String?
    var methods: [String]?
    var statusCodes: [Int]?
    var hasRequestBody: Bool?
    var hasResponseBody: Bool?
}

enum ExportFormat {
    case har
    case json
    case txt
}
```

## 12.8 配置项

```json
"httpCapture": {
  "globalEnable": false,
  "maxSessionCount": 500,
  "bodyMaxTextBytes": 262144,
  "saveBinaryBody": false,
  "mode": "followMitm"
}
```

## 12.9 性能保护

| 策略 | 说明 |
| --- | --- |
| 旁路钩子 | 只读，不阻塞主链路 |
| UI 节流 | 每 200ms 批量刷新 |
| 测速隔离 | 测速隧道默认不抓包 |
| 大 Body 截断 | 防止内存暴涨 |
| 关闭后零开销 | 总开关关闭时不注册钩子 |

## 12.10 容错策略

| 异常 | 处理 |
| --- | --- |
| HTTP 解析失败 | 跳过该会话，记录 WARN |
| Body 编码失败 | 不保存 Body，记录大小 |
| 缓冲区满 | FIFO 淘汰最旧会话 |
| 导出文件失败 | 提示错误，不影响运行 |
