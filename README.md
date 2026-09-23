# New VPN

> 自用 iOS 代理工具，SwiftUI 原生开发，基于 sing-box 内核，最低支持 iOS 16，**不上架 App Store**。
> 版本规则：三段式语义版本 `vX.Y.Z`，补丁号自动进位；CI 产物为**未签名 IPA**，命名规范：`newVPN-vX.Y.Z.ipa`。

## 项目简介

纯原生 Swift + SwiftUI 网络代理客户端，采用 sing-box 作为 TUN 隧道内核，使用 `PacketTunnelProvider` 实现系统 VPN 隧道。
支持节点管理、订阅解析、分流路由、MITM 中间人、HTTP 抓包、网络连接监控、JS 脚本扩展、分级调试日志。
整套 UI 使用 SwiftUI 三栏 `NavigationSplitView`，全中文本地化，统一简洁组件库。

> ⚠️ 本项目仅供个人学习、自用；不提供任何签名证书，IPA 需自行使用开发者账号签名安装。

## ✨ 功能清单

- **TUN 隧道管理**：启动 / 停止、断开自动重连、实时上下行流量统计
- **节点管理**：手动新增、分组标签、vmess / vless 链接解析
- **订阅源管理**：拉取订阅、Base64 解码、流量 / 过期元信息解析、增量同步
- **测速中心**：节点延迟、抖动、丢包、带宽测速，测速结果持久化
- **分流路由**：自定义域名 / IP 规则，支持代理 / 直连 / 拒绝策略，热重载
- **MITM & HTTP 重写**：根证书生成导出，请求 / 响应 Header、Body、状态码修改
- **HTTP 抓包**：MITM 流量捕获，会话查看、JSON 格式化、HAR 导出
- **网络活动**：四层 TCP / UDP 连接监控，IP 地理位置解析，CSV 导出
- **JS 脚本引擎**：JavaScriptCore 沙箱脚本，多事件钩子，自定义自动逻辑
- **调试日志**：分级日志、环形内存缓冲区、日志落盘滚动、敏感信息脱敏、日志导出
- **系统设置**：内核参数、日志配置、UI 主题、配置导入导出、一键重置
- **关于页面**：版本信息、内核版本、环境检测、项目仓库链接

## 🧱 技术栈

- 语言：Swift
- UI 框架：SwiftUI
- 最低系统：iOS 16+
- 内核：sing-box
- 工程生成：XcodeGen（`project.yml`）
- CI/CD：GitHub Actions，自动构建未签名 IPA
- 跨进程通信：App Group + IPC（主 App ↔ PacketTunnel 扩展）
- JS 引擎：JavaScriptCore
- 构建工具：Xcode 15.4+

## 📁 目录结构

```
.
├── project.yml                  # XcodeGen 工程描述文件
├── .github/workflows/ci.yml     # GitHub Actions CI 流水线配置
├── Sources
│   ├── AppMain                  # SwiftUI 主 App 入口
│   │   ├── UIComponents         # 全局 UI 基础组件库
│   │   ├── Pages                # 所有业务页面
│   │   └── AppState.swift       # 全局状态
│   ├── Business                 # 业务逻辑模块
│   │   ├── ConfigManager       # 配置读写、导入导出、版本迁移
│   │   ├── Logger               # 调试日志模块
│   │   ├── NodeManager          # 节点管理模块
│   │   ├── SubscriptionManager  # 订阅管理器
│   │   ├── SubscriptionParser   # 订阅解释器
│   │   ├── SpeedTest            # 测速模块
│   │   ├── RouteRule            # 分流路由模块
│   │   ├── MITMRewrite          # MITM 与 HTTP 重写模块
│   │   ├── HttpCapture          # HTTP 抓包模块
│   │   ├── NetworkActivity      # 网络活动监控模块
│   │   ├── ScriptEngine         # JS 脚本模块与解释器
│   │   └── VPNManager           # VPN 隧道管理模块
│   └── TunnelExtension          # PacketTunnelProvider 扩展进程
├── Resources
│   ├── ConfigTemplates          # sing-box 配置模板
│   └── Assets                   # 图片、资源
├── Tests                        # 单元测试
├── docs                         # 设计文档
└── README.md
```

## 📚 设计文档

详细设计文档位于 [`docs/`](./docs/) 目录：

| 文档 | 说明 |
| ---- | ---- |
| [01-项目总览](./docs/01-项目总览.md) | 项目目标、范围、技术约束 |
| [02-系统架构](./docs/02-系统架构.md) | 分层架构、模块依赖、数据流 |
| [03-配置管理模块](./docs/03-配置管理模块.md) | 配置读写、版本迁移、导入导出 |
| [04-调试日志模块](./docs/04-调试日志模块.md) | 分级日志、环形缓冲、滚动文件 |
| [05-VPN隧道模块](./docs/05-VPN隧道模块.md) | PacketTunnel、TUN、状态机、IPC |
| [06-节点模块](./docs/06-节点模块.md) | 节点 CRUD、链接解析、增量同步 |
| [07-订阅管理模块](./docs/07-订阅管理模块.md) | 订阅源 CRUD、定时更新 |
| [08-订阅解释器](./docs/08-订阅解释器.md) | Base64 解码、vmess/vless 解析 |
| [09-测速模块](./docs/09-测速模块.md) | 延迟、抖动、丢包、带宽测试 |
| [10-分流路由模块](./docs/10-分流路由模块.md) | 规则匹配、热重载 |
| [11-MITM与重写模块](./docs/11-MITM与重写模块.md) | 中间人、根证书、HTTP 重写 |
| [12-HTTP抓包模块](./docs/12-HTTP抓包模块.md) | 会话捕获、HAR 导出 |
| [13-网络活动模块](./docs/13-网络活动模块.md) | 四层连接监控、IP 地理 |
| [14-JS脚本模块](./docs/14-JS脚本模块.md) | 脚本管理、事件钩子 |
| [15-JS解释器](./docs/15-JS解释器.md) | JavaScriptCore 沙箱、原生桥 |
| [16-UI面板模块](./docs/16-UI面板模块.md) | 三栏布局、页面清单 |
| [17-UI组件库规范](./docs/17-UI组件库规范.md) | 设计令牌、组件复用 |
| [18-设置与关于模块](./docs/18-设置与关于模块.md) | 设置表单、关于页面 |
| [19-配置文件规范](./docs/19-配置文件规范.md) | 全部 JSON 配置样例 |
| [20-开发里程碑](./docs/20-开发里程碑.md) | 阶段划分、交付物 |
| [21-风险清单](./docs/21-风险清单.md) | 风险识别与应对 |

## 📦 配置文件说明

所有配置以 JSON 格式独立存储，便于版本管理与备份：

- `config.json`：全局应用设置（VPN、日志、订阅、UI 外观）
- `nodes.json`：节点列表、分组、标签、测速缓存
- `subscriptions.json`：订阅源列表、元信息、过滤规则
- `rules.json`：分流路由规则
- `rewrite.json`：MITM HTTP 重写规则
- `scripts.json`：JS 脚本列表与内容
- `logs/`：日志持久化目录

## 🚀 构建与 CI

1. 依赖 XcodeGen，通过 `project.yml` 生成 `.xcworkspace`
2. 提交代码触发 GitHub Actions CI 流水线
3. CI 输出产物：`newVPN-vX.Y.Z.ipa`，**未签名**
4. 版本号遵循 `vX.Y.Z`，补丁版本自动递增

> CI 仅编译打包，**不执行代码签名**，安装需自备开发者证书。

### 本地编译步骤

```bash
# 安装 XcodeGen
brew install xcodegen

# 生成工程
xcodegen generate

# 打开工程
open App.xcworkspace
```

## 🖥️ UI 设计规范

- 布局：`NavigationSplitView` 三栏布局（侧边导航栏 / 内容列表 / 详情面板）
- 弹窗：所有编辑弹窗使用 `fullScreenCover`，左上角返回按钮 + 边缘左滑手势关闭，独立导航栈，不污染主页面
- 组件：统一封装全局 UI 组件 `AppCard` / `AppFormRow` / `AppButton` 等，禁止业务页面硬编码样式
- 配色：语义化颜色，支持浅色 / 深色 / 跟随系统
- 文案：全中文，统一术语词表，克制动画，减少多余装饰元素

## ⚠️ 重要注意事项

1. 项目仅自用，不支持 App Store 上架，无公开分发
2. iOS 系统需要开启「VPN」权限（NetworkExtension 能力，需要 Apple 开发者账号）
3. IPA 未签名，普通用户无法直接安装，需要开发者证书签名
4. 本项目仅做学习开发，使用请遵守所在地区网络相关法规
5. 导出配置支持密钥脱敏选项，导出前建议开启，保护隐私

## 📝 开发规范

1. 全部代码注释、日志、提示文案、变量名、文件名**全中文**
2. 新增弹窗必须使用 `fullScreenCover`，满足返回 + 左滑关闭
3. 列表统一使用 `LazyList` 懒加载，处理大量日志 / 抓包数据
4. 配置读写加锁，防止并发损坏 JSON
5. 模块单向依赖，禁止循环依赖
6. 提交代码前本地编译自检；提交等待 CI 流水线完成，确认构建产物

## 📜 开源声明

项目使用第三方组件：

- sing-box
- JavaScriptCore（系统原生）

> 开源协议见项目内 LICENSE 文件。
