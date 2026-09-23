# Sources 源码目录说明

## 目录结构

```
Sources/
├── AppMain/                      # 主 App 程序
│   ├── NewVPNApp.swift           # App 入口，注入全局状态
│   ├── ContentView.swift         # 旧三栏主界面（已弃用，保留参考）
│   ├── Pages/                    # 页面视图
│   │   ├── DashboardView.swift   # 主控首页 Dashboard
│   │   └── 内容区/                # 顶部卡片对应内容区
│   │       ├── 节点内容区.swift       # 节点分组列表 + 展开节点
│   │       ├── 网络活动内容区.swift   # TCP/UDP统计 + 连接记录
│   │       └── 规则与日志内容区.swift # 重写规则/分流规则/日志
│   ├── Core/                     # 核心层
│   │   ├── UIConst.swift         # 设计令牌：颜色/字体/间距/圆角
│   │   ├── AppState.swift        # 全局状态 + Mock 数据
│   │   └── 数据模型.swift          # 全部数据模型定义
│   └── UI/
│       └── Components/           # 基础组件库
│           ├── AppCard.swift            # 卡片容器
│           ├── AppFormRow.swift         # 表单行
│           ├── AppButton.swift          # 按钮（三种样式）
│           ├── StateBadge.swift         # 状态标签
│           ├── EmptyStateView.swift     # 空状态占位
│           ├── AppSearchBar.swift       # 搜索栏
│           ├── 全局状态栏.swift          # 常驻顶部状态栏
│           ├── 顶部功能卡片栏.swift      # 横向滑动5卡片导航
│           ├── 底部工具栏.swift          # 底部5图标工具栏
│           └── 底部弹窗容器.swift        # 90%高度底部弹窗
└── TunnelExtension/              # VPN 隧道扩展
    └── PacketTunnelProvider.swift
```

## 一期第二次交付内容（Dashboard 重构）

### 主控首页 Dashboard
- 顶部状态区：左侧隧道状态文字 + 右侧电源开关
- 横向功能卡片栏：5 张可滑动卡片（节点/网络活动/重写规则/分流规则/日志）
- 主内容区：根据选中卡片切换对应内容
- 底部固定工具栏：5 个功能入口（编辑配置/DNS记录/JS脚本/TCP-UDP流量/设置）

### 精确尺寸规范（基于截图测量）
- 顶部卡片：宽 102pt × 高 74pt，间距 16pt，左边距 12pt，圆角 16pt
- 卡片颜色：节点 #3DC4D2、网络活动 #E75C33、重写规则 #FC54A1、分流规则 #5AC8FA、日志 #6B6B70
- 分组/节点行：左右边距 15pt，圆角 12pt
- 底部工具栏：高 56pt，毛玻璃背景

### 交互功能
- 顶部卡片点击切换内容区，选中卡片高亮
- 分组行点击展开/折叠节点列表（平滑动画）
- 分组左侧测速图标点击触发模拟批量测速
- 节点行展示协议标签、地址、测速下载速率和延迟
- 底部工具栏点击弹出 90% 高度底部 sheet
- 弹窗左上角向下箭头点击关闭，支持下滑手势关闭

### 底部弹窗内容
- 编辑配置文件：配置列表 + 导入/导出/编辑操作
- DNS 记录：DNS 查询记录列表
- JS 脚本记录：已执行脚本日志
- TCP/UDP 流量：连接数统计 + 实时速率
- 设置：通用/网络/关于设置项

## 架构原则

- UI 与数据层通过 AppState 解耦
- 所有页面引用设计令牌，禁止硬编码样式
- 后续接入真实数据只需替换 AppState 数据源，View 层无需修改
- Dashboard 采用单栏布局，适配 iPhone 竖屏
