# 05 - VPN 隧道模块

## 5.1 职责

- 封装 PacketTunnelProvider
- 管理 TUN 虚拟网卡、路由、DNS
- 组装 sing-box 完整配置
- 隧道状态机管理
- 自动重连
- 流量统计采集
- IPC 跨进程通信
- 内核日志转发

> 不处理协议解析，协议交给节点模块。

## 5.2 状态机

```
                    ┌──────────────────────────────┐
                    │                              │
                    ▼                              │
┌──────┐  start  ┌──────────┐  config  ┌───────────┐
│ idle │ ──────→ │ preparing │ ──────→ │ connecting │
└──────┘         └──────────┘         └─────┬─────┘
   ↑                  │                      │
   │                  │ error                │ tunnel up
   │                  ▼                      ▼
   │            ┌──────────┐         ┌──────────┐
   │            │  error    │         │ running  │
   │            └──────────┘         └────┬─────┘
   │                                     │
   │                          disconnect │ network change
   │                                     ▼
   │                               ┌─────────────┐
   │                               │ reconnecting │
   │                               └──────┬──────┘
   │                                      │
   │                            retry     │ retry exhausted
   │                            success   │
   │                                      ▼
   │                               ┌──────────┐
   └──────────────── stop ──────── │ stopped  │
                                   └──────────┘
```

### 状态枚举

```swift
enum TunnelStatus: String, Codable {
    case idle          // 空闲，未启动
    case preparing     // 准备中，生成配置
    case connecting    // 正在连接
    case running       // 正常运行
    case reconnecting  // 断连自动重连
    case stopped       // 已停止
    case error         // 异常失败
}
```

## 5.3 数据模型

```swift
struct TunnelStats: Codable {
    var upBytes: UInt64      // 累计上行字节
    var downBytes: UInt64    // 累计下行字节
    var upSpeed: Double       // 上行速率 B/s
    var downSpeed: Double     // 下行速率 B/s
}

final class TunnelState: ObservableObject {
    @Published var status: TunnelStatus = .idle
    @Published var activeNodeId: String?
    @Published var stats = TunnelStats(upBytes: 0, downBytes: 0, upSpeed: 0, downSpeed: 0)
    @Published var lastError: String?
    @Published var lastStartTime: Date?
}
```

## 5.4 核心 API

```swift
final class VPNManager {
    static let shared = VPNManager()

    /// 启动隧道
    /// - Parameter nodeId: 选中的节点 ID
    /// - Throws: 配置生成失败、Tunnel 启动失败
    func startTunnel(nodeId: String) async throws

    /// 停止隧道
    func stopTunnel() async

    /// 热重载配置（分流 / 重写规则变更时）
    /// - 不中断当前连接
    /// - 新连接使用新规则
    func reloadConfig() async throws

    /// 获取当前隧道状态
    func getState() -> TunnelState

    /// 状态变更回调
    var onStateChange: ((TunnelState) -> Void)?
}
```

## 5.5 启动流程

```
调用 startTunnel(nodeId)
    ↓ 校验 nodeId 存在
    ↓ 状态检查（当前 idle / stopped）
状态 → preparing
    ↓
节点模块：获取选中节点出站配置片段
    ↓
分流模块：获取规则配置片段
    ↓
MITM 模块：获取重写配置片段
    ↓
组装完整 sing-box JSON
    ↓
写入 App Group 共享目录
    ↓
唤起 PacketTunnel
    ↓
Tunnel 读取配置，启动 sing-box
    ↓
创建 TUN 网卡，配置路由、DNS
    ↓
状态 → connecting
    ↓
sing-box 内核就绪
    ↓
IPC 回传 running
    ↓
状态 → running
    ↓
开始采集流量统计
```

## 5.6 运行模式

### 全局代理模式

- 所有流量经过 TUN
- DNS 全部劫持到内核 DNS
- 不执行分流规则

### 规则分流模式（推荐）

- 域名 / IP 匹配分流规则
- 匹配走代理，其余直连
- 由 sing-box 内核执行匹配

### 全局直连模式

- 所有流量直连
- 仅自定义强制代理规则生效
- 调试用

## 5.7 自动重连

触发条件：

- 内核检测到节点断开
- 网络切换（Wi-Fi ↔ 蜂窝）
- TUN 网卡异常

重连策略：

```
检测到断连
    ↓
状态 → reconnecting
    ↓
等待 retryDelaySec 秒
    ↓
重试次数 < retryCount？
    ├─ 是 → 重新启动隧道
    │       ↓
    │     成功 → running
    │       ↓
    │     失败 → 重试次数 +1
    │
    └─ 否 → 状态 → error
             记录错误日志
             通知 UI
```

## 5.8 跨进程通信

主 App ↔ Tunnel 扩展通过 IPC 通道：

| 数据 | 方向 | 频率 |
| --- | --- | --- |
| 隧道状态变更 | Tunnel → 主 App | 事件触发 |
| 实时流量统计 | Tunnel → 主 App | 每 500ms |
| sing-box 内核日志 | Tunnel → 主 App | 实时 |
| 异常错误信息 | Tunnel → 主 App | 事件触发 |

## 5.9 配置项

```json
"vpn": {
  "mtu": 1500,
  "tunAddress": "10.0.0.2/30",
  "autoRoute": true,
  "autoDNS": true,
  "enableReconnect": true,
  "retryCount": 3,
  "retryDelaySec": 2,
  "statsIntervalMs": 500
}
```

## 5.10 容错策略

| 异常 | 处理 |
| --- | --- |
| 配置生成失败 | 不启动隧道，返回错误 |
| Tunnel 启动失败（权限） | 提示用户检查 VPN 权限设置 |
| sing-box 内核崩溃 | Tunnel 捕获崩溃，自动重连 |
| IPC 中断 | 不中断隧道，日志告警，等待恢复 |
| 重复启动请求 | 返回忙状态，防止多实例 |
| 路由注入失败 | 记录 WARN，隧道继续运行 |
| DNS 劫持失败 | 降级为系统 DNS，记录 WARN |

## 5.11 与其他模块交互

- **节点模块**：请求选中节点的出站配置
- **分流模块**：请求分流规则配置
- **MITM 模块**：请求 MITM 重写配置
- **配置模块**：读写 VPN 全局参数
- **日志模块**：转发内核日志
- **面板 UI**：监听状态变更，更新界面
