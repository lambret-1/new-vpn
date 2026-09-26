# TunnelExtension 隧道扩展目录说明

## 目录职责

本目录是 VPN 的 Network Extension 扩展进程，独立于主 App 运行，负责：
- 接收系统路由过来的所有 IP 数据包
- 启动 sing-box 内核处理流量
- 管理隧道生命周期（启动/停止/重载）
- 采集流量统计并通过 App Group 共享给主 App
- 转发内核日志到主 App 调试面板

## 文件清单

| 文件 | 职责 |
|------|------|
| `PacketTunnelProvider.swift` | NEPacketTunnelProvider 子类，隧道入口，管理网络配置、内核启停、统计定时 |
| `SingBox内核桥接.swift` | libbox Objective-C API 的 Swift 封装，负责内核启动/停止/重载/统计同步 |
| `Libbox平台接口OC.h` | libbox 平台接口的 Objective-C 声明 |
| `Libbox平台接口OC.m` | libbox 平台接口实现，重写 `openTun` 返回 TUN fd，枚举系统网络接口 |
| `NewVPN-Tunnel-Bridging-Header.h` | OC-Swift 桥接头，暴露 `Libbox平台接口OC` 给 Swift 调用 |

## 出站链路数据流

```
系统所有 App 的网络请求
    ↓ 系统路由表（默认路由指向 TUN）
NEPacketTunnelFlow（packetFlow）
    ↓ TUN 文件描述符（通过 KVC 从 packetFlow 提取）
sing-box 内核 TUN 入站（gvisor 用户态协议栈）
    ↓ 解析 IP/TCP/UDP
DNS 模块（拦截发往 10.0.0.2:53 的查询）
    ↓ 按规则选择 dns_resolver（直连）或 dns_proxy（代理隧道）
路由引擎（按域名/IP/端口匹配分流规则）
    ↓
出站处理器
    ├─ DIRECT → 系统 socket → 物理网卡 → 目标服务器
    └─ proxy → 代理协议封装 → TLS → 物理网卡 → 代理服务器 → 目标
```

## 关键实现要点

### TUN 文件描述符获取

不使用 `LibboxGetTunnelFileDescriptor()` 全局函数（iOS 上不可靠），而是通过
`Libbox平台接口OC.安全获取文件描述符(packetFlow)` 利用 Objective-C 运行时反射，
枚举 `NEPacketTunnelFlow` 的所有属性和无参数方法，匹配包含 fd/socket/file/desc/tun/interface
的名称，返回第一个有效的文件描述符。

### 平台接口 openTun

sing-box 内核启动时会调用 `LibboxPlatformInterface` 协议的 `openTun` 方法，
`Libbox平台接口OC` 重写该方法，返回外部设置的 `tun文件描述符`。
这是内核能直接读写系统 VPN 数据包的关键。

### 网络配置

- TUN 地址：`10.0.0.2/24`
- DNS 服务器：`10.0.0.2`（指向 TUN 接口，由 sing-box 拦截处理）
- 默认路由：全部走 TUN（`includedRoutes = [.default()]`）
- 排除路由：局域网段（10/8、172.16/12、192.168/16、127/8）
- MTU：1500

### 流量统计

桥接层 `更新统计()` 方法通过 KVC 探测 libbox 服务对象的统计属性
（uploadBytes/downloadBytes 等多种命名），同步真实上下行字节数。
PacketTunnelProvider 的每秒定时器在保存统计前调用此方法。

## 与主 App 通信

- **配置传递**：主 App 生成 sing-box JSON 配置写入 App Group 共享目录，扩展启动时读取。
- **统计回传**：扩展每秒将上下行字节写入 App Group UserDefaults，主 App 读取展示。
- **日志回传**：扩展将内核日志和自身日志写入 App Group UserDefaults（环形缓冲，最多 300 条）。
- **IPC 消息**：主 App 通过 `sendProviderMessage` 向扩展发送 getVersion/getStats/reloadConfig/getLogs/testLatency 指令。

## 节点延迟测速（testLatency）

VPN 已连接时，主 App 进程的 TCP 连接会被全局 TUN 截获（测到的是到本地 TUN 的握手，
表现为假 5ms），因此改由扩展进程完成真实测速：

- 主 App 通过 XPC 发送 `testLatency`（address/port），扩展在自己进程内发起一次到
  节点服务器的 TCP 握手，回传 `latency`(ms) 或 `error`。
- **关键**：扩展进程里未绑定出接口的 socket 同样会被路由进 TUN，且因扩展进程的
  socket 带“绕过 VPN”标记，TUN 回包无法匹配，连接必然超时。因此测速 socket 必须用
  `SO_BINDTODEVICE` 钉在物理网卡（`getifaddrs` 枚举跳过 lo0/utun/ipsec/tap/bridge
  后取第一个物理接口，通常是 en0 / pdp_ip0），让 SYN 从物理网卡直连节点服务器，
  测到真实 RTT。这与 sing-box 内核 `auto_detect_interface=true` 绑定物理接口出墙是同一机制。
- 实现为非阻塞 `connect` + `DispatchSource` 监听可写，5 秒超时；失败回 `{"error":"timeout"}`，
  主 App 侧会读取该错误字段并展示，不再静默判定失败。
