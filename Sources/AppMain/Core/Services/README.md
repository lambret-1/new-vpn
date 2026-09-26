# Services 业务服务目录说明

## 目录职责

本目录包含主 App 的所有业务服务层，负责数据处理、网络请求、配置管理等核心逻辑。
所有服务均为单例模式，通过 `静态.共享` 属性访问。

## 出站链路相关核心服务

### SingBox配置生成器.swift

**职责**：将节点、分流规则、DNS 配置转换为 sing-box 可识别的 JSON 配置。

**生成的配置结构**：
- **log**：日志级别和时间戳
- **dns**：DNS 服务器列表、规则、默认服务器
- **inbounds**：TUN 入站（gvisor 栈，启用协议嗅探）+ Mixed 入站（127.0.0.1:7890）
- **outbounds**：当前节点（proxy）+ 所有节点（node-N）+ urltest + selector + DIRECT + REJECT
- **route**：分流规则 + 最终出站
- **experimental**：缓存文件

**运行模式支持**：
- 规则分流：DNS 默认走 dns_proxy，路由 final 走 proxy，用户分流规则生效
- 全局代理：DNS 默认走 dns_proxy，路由 final 走 proxy，忽略用户分流规则
- 全局直连：DNS 默认走 dns_resolver（国内直连），路由 final 走 DIRECT

**防死锁设计**：
- 代理服务器域名强制走 dns_resolver 直连解析
- 代理服务器 IP/域名强制加入路由直连规则
- DNS 服务器 IP（223.5.5.5/8.8.8.8/1.1.1.1）强制直连

### 隧道管理器.swift

**职责**：VPN 隧道的全局管理，包括配置加载、启停连接、状态监控、流量统计。

**关键流程**：
1. `启动连接()` → 加载 VPN 配置 → 生成 sing-box 配置 → 写入 App Group → 启动 PacketTunnel
2. 监听 `NEVPNStatusDidChange` 通知更新状态
3. 每秒定时器从 App Group 读取扩展回传的流量统计

### SingBox内核管理器.swift

**职责**：sing-box 内核的生命周期管理（主 App 侧），与扩展进程的桥接层配合。

## 其他服务

| 服务 | 职责 |
|------|------|
| DNS管理器.swift | DNS 配置管理、查询记录、服务器测速、泄漏检测 |
| DNS服务.swift | DNS 解析底层实现，支持 UDP/TLS/HTTPS 协议 |
| 分流规则管理器.swift | 分流规则的增删改查和持久化 |
| 分流规则服务.swift | 分流规则匹配引擎 |
| 测速管理器.swift | 节点延迟/抖动/丢包/带宽测速；已连接时经 XPC 委托扩展进程绑定物理接口测速（避免被 TUN 截获的假延迟），未连接时本地直连 |
| 测速服务.swift | 测速底层实现（TCP 握手/HTTP 请求） |
| 节点链接解析器.swift | vmess/vless/trojan/shadowsocks 链接解析 |
| 订阅下载服务.swift | 订阅源 HTTP 拉取 |
| 订阅解释器.swift | 订阅内容 Base64 解码和节点提取 |
| Clash解释器.swift | Clash 订阅格式解析 |
| 网络活动管理器.swift | TCP/UDP 连接监控和轮询 |
| CA证书服务.swift | MITM 根证书生成/导出/信任 |
| VPN描述文件服务.swift | .mobileconfig 描述文件生成 |
| 证书与描述文件管理器.swift | 证书和描述文件统一管理 |
| 配置描述文件服务.swift | 配置描述文件读写 |
| 配置描述文件管理器.swift | 配置描述文件管理 |
| 调试日志管理器.swift | 分级日志、环形缓冲、落盘滚动 |
