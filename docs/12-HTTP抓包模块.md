# 12 - HTTP 抓包模块

## 12.1 职责

- 捕获 MITM 解密后的 HTTP/HTTPS 会话
- 会话列表、请求 / 响应头 / Body 查看
- JSON 格式化
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
}
```

## 12.3 内存策略

- 环形缓冲区，默认 500 条
- 可配置 200-2000
- FIFO 淘汰旧记录
- Body Base64 存储
- 二进制资源默认截断

### Body 截断

| 类型 | 策略 |
| --- | --- |
| 文本 | 默认最多 256KB |
| 二进制（图片 / 视频） | 默认不保存 Body，仅记录大小 |

## 12.4 抓取范围

两种模式：

1. **跟随 MITM（默认）**：只抓取 MITM 命中域名
2. **自定义白名单**：独立抓取规则

## 12.5 导出格式

| 格式 | 说明 |
| --- | --- |
| HAR | HTTP Archive，可导入 Chrome / Charles |
| JSON | 结构化数据 |
| TXT | 简易文本日志 |

支持：
- 导出全部
- 导出选中
- 导出过滤结果

## 12.6 UI 面板

### 顶部控制栏

- 总开关
- 暂停 / 继续
- 清空
- 导出
- 搜索

### 会话列表

字段：时间、方法、URL、状态码、大小、耗时

### 详情弹窗

- 概览：URL、五元组、耗时
- 请求：请求头 + Body
- 响应：响应头 + Body
- 原始数据：Base64

## 12.7 配置项

```json
"httpCapture": {
  "globalEnable": false,
  "maxSessionCount": 500,
  "bodyMaxTextBytes": 262144,
  "saveBinaryBody": false,
  "mode": "followMitm"
}
```

## 12.8 性能保护

- 独立旁路回调，不阻塞主链路
- UI 每 200ms 批量刷新
- 测速隧道默认不抓包
- 高并发时关闭抓包避免性能下降
