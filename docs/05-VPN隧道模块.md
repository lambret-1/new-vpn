# 05 - VPN 隧道模块

## 5.1 职责

- 封装 PacketTunnelProvider
- 管理 TUN 虚拟网卡、路由、DNS
- 组装 sing-box 完整配置
- 隧道状态机
- 自动重连
- 流量统计
- IPC 跨进程通信
- 内核日志转发

> 不处理协议解析，协议交给节点模块。

## 5.2 状态机

```swift
enum TunnelStatus: String, Codable {
    case idle          // 空闲，未启动
    case preparing     // 准备中，生成配置
    case connecting    // 正在连接
    case running       // 正常运行
    case reconnecting  // 断连自动重连
    case stopped        // 已停止
    case error         // 异常失败
}
```

### 状态流转

```
idle → preparing → connecting → running
                    ↑              │
                    └── reconnecting ↘
                           │
                           └→ error
running → stopped → idle
```

## 5.3 数据模型

```swift
struct TunnelStats: Codable {
    var upBytes: UInt64      // 累计上行
    var downBytes: UInt64    // 累计下行
    var upSpeed: Double      // 上行速率 B/s
    var downSpeed: Double    // 下行速率 B/s
}

final class TunnelState: ObservableObject {
    @Published var status: TunnelStatus = .idle
    @Published var activeNodeId: String?
    @Published var stats = TunnelStats(upBytes: 0, downBytes: 0, upSpeed: 0, downSpeed: 0)
    @Published var lastError: String?
}
```

## 5.4 核心 API

```swift
final class VPNManager {
    static let shared = VPNManager()

    /// 启动隧道，指定节点 ID
    func startTunnel(nodeId: String) async throws

    /// 停止隧道
    func stopTunnel() async

    /// 热重载配置（分流 / 重写规则变更时使用）
    func reloadConfig() async throws

    /// 获取当前隧道状态
    func getState() -> TunnelState

    /// 状态变更回调
    var onStateChange: ((TunnelState) -> Void)?
}
```

## 5.5 启动流程

1. 校验节点 ID 是否存在
2. 从节点模块获取出站配置片段
3. 从分流模块获取规则配置片段
4. 从 MITM 模块获取重写配置片段
5. 组装完整 sing-box JSON
6. 写入 App Group 共享目录
7. 唤起 PacketTunnel
8. Tunnel 读取配置，启动 sing-box
9. IPC 回传运行状态
10. 状态更新为 running

## 5.6 运行模式

### 全局模式

- 所有流量经过 TUN
- DNS 全部劫持到内核 DNS

### 规则分流模式

- 域名 / IP 匹配分流规则
- 匹配走代理，其余直连
- 由 sing-box 内核执行匹配

## 5.7 自动重连

- 网络变化（Wi-Fi ↔ 蜂窝）触发重连
- 节点断开检测
- 重试次数可配置（默认 3 次）
- 重试间隔可配置（默认 2 秒）
- 重试耗尽进入 error 状态

## 5.8 跨进程通信

主 App ↔ Tunnel 扩展通过 IPC：

| 数据 | 方向 |
| --- | --- |
| 隧道状态 | Tunnel → 主 App |
| 实时流量统计 | Tunnel → 主 App |
| sing-box 内核日志 | Tunnel → 主 App |
| 异常错误信息 | Tunnel → 主 App |

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

## 5.10 容错

- 配置生成失败：不启动隧道，返回错误
- Tunnel 启动失败（权限）：提示用户检查 VPN 权限
- sing-box 崩溃：捕获崩溃，自动重连
- IPC 中断：不中断隧道，日志告警
- 重复启动：返回忙状态，防止多实例
