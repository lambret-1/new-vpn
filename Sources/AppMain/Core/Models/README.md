# Models 数据模型目录说明

## 目录职责

本目录包含 App 所有的数据模型定义，全部使用 Swift struct/enum，支持 Codable 序列化。

## 出站链路相关模型

### 隧道模型.swift

**隧道状态**：已断开/准备中/正在连接/已连接/正在断开/重新加载中/重连中/连接失败/配置无效

**隧道配置模型**：
- 隧道名称、描述、服务器地址
- 按需连接、蜂窝/WiFi 连接策略
- Kill Switch、包含所有网络
- SSID 包含/排除列表
- DNS 服务器、代理设置、MTU
- 日志级别、流量统计开关
- **运行模式**：规则分流 / 全局代理 / 全局直连（v0.1.1 新增）

**隧道运行模式**（v0.1.1 新增）：
- `规则分流`：按分流规则匹配，国内直连、国外代理（默认）
- `全局代理`：所有流量全部走代理服务器
- `全局直连`：所有流量直接连接，不经过代理

**隧道流量统计**：上下行字节、速率、连接时长

**隧道错误**：配置无效/权限被拒绝/连接超时/服务器无响应/认证失败/网络不可用/扩展未安装/未知错误

**隧道常量**：扩展 Bundle ID、App Group ID、通知名、统计间隔

### SingBox模型.swift

sing-box 完整配置的 Swift 映射，包含：
- **SingBox配置**：顶层配置，log/dns/inbounds/outbounds/route/experimental
- **SingBoxDNS配置/服务器/规则**：DNS 模块配置
- **SingBox入站配置**：tun/mixed/socks/http/api 入站
- **SingBox出站配置**：vless/vmess/trojan/shadowsocks/direct/block/selector/urltest 出站
- **SingBoxTLS配置**：标准 TLS / Reality / uTLS 指纹
- **SingBox传输配置**：ws/grpc/httpupgrade/meek 传输层
- **SingBox路由配置/规则**：路由引擎和匹配规则
- **SingBox实验配置**：缓存文件/Clash API/V2Ray API

## 其他模型

| 模型文件 | 内容 |
|----------|------|
| DNS模型.swift | DNS 配置、服务器、查询记录、过滤规则、泄漏检测结果 |
| 分流规则项.swift | 分流规则数据模型（匹配类型/动作/优先级） |
| 测速模型.swift | 测速结果（延迟/抖动/丢包/带宽） |
| 解析结果模型.swift | 节点链接解析结果 |
| 订阅模型.swift | 订阅源、流量信息、下载结果 |
| 证书与描述文件模型.swift | 证书、描述文件模型 |
| 配置描述文件模型.swift | 配置描述文件模型 |
