# Sources 源码目录说明

## 目录结构

```
Sources/
├── AppMain/                  # 主 App 程序
│   ├── NewVPNApp.swift       # App 入口，注入全局状态
│   ├── ContentView.swift     # 三栏主界面（导航+列表+详情）
│   ├── Core/                 # 核心层
│   │   ├── UIConst.swift     # 设计令牌：颜色/字体/间距/圆角
│   │   ├── AppState.swift    # 全局状态 + Mock 数据
│   │   └── 数据模型.swift     # 全部数据模型定义
│   ├── UI/
│   │   ├── Components/       # 基础组件库
│   │   │   ├── AppCard.swift        # 卡片容器
│   │   │   ├── AppFormRow.swift     # 表单行
│   │   │   ├── AppButton.swift      # 按钮（三种样式）
│   │   │   ├── StateBadge.swift     # 状态标签
│   │   │   ├── EmptyStateView.swift # 空状态占位
│   │   │   ├── AppSearchBar.swift   # 搜索栏
│   │   │   └── 全局状态栏.swift      # 常驻顶部状态栏
│   │   └── Views/            # 页面视图（后续步骤填充）
│   ├── Modules/              # 业务模块（后续开发）
│   └── Utils/                # 工具类（后续开发）
└── TunnelExtension/          # VPN 隧道扩展（后续开发）
    └── PacketTunnelProvider.swift
```

## 一期第一次交付内容

- 全局设计令牌（UIConst）
- 7 个基础 UI 组件
- 完整数据模型定义
- AppState 全局状态管理
- Mock 假数据（5 节点、3 订阅、5 规则等）
- NavigationSplitView 三栏导航框架
- 隧道状态机 Mock（可点击启停，模拟状态流转和实时流量）

## 架构原则

- UI 与数据层通过 AppState 解耦
- 所有页面引用设计令牌，禁止硬编码样式
- 后续接入真实数据只需替换 AppState 数据源，View 层无需修改
