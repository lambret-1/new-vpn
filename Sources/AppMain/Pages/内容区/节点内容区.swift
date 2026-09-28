//
//  节点内容区.swift
//  NewVPN
//
//  重构版：双模式切换（节点模式/策略模式）+ 一行双卡片网格布局
//

import SwiftUI

/// 节点内容区视图
struct 节点内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器
    /// 隧道管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器

    /// 当前显示模式
    @State private var 当前模式: 显示模式 = .节点
    /// 模式持久化键
    private let 模式键 = "节点内容区显示模式"

    /// 显示模式枚举
    enum 显示模式: String {
        case 节点 = "节点模式"
        case 策略 = "策略模式"
    }

    init() {
        // 恢复用户上次选择的模式
        if let 保存的模式 = UserDefaults.standard.string(forKey: 模式键),
           let 模式 = 显示模式(rawValue: 保存的模式) {
            _当前模式 = State(initialValue: 模式)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // 顶部模式切换分段控制器
            模式切换器(当前模式: $当前模式)
                .padding(.horizontal, 15)
                .onChange(of: 当前模式) { 新模式 in
                    UserDefaults.standard.set(新模式.rawValue, forKey: 模式键)
                }

            // 内容区
            if 当前模式 == .节点 {
                节点模式视图()
            } else {
                策略模式视图()
            }
        }
    }
}

// MARK: - 模式切换器

/// 模式切换分段控制器
private struct 模式切换器: View {
    @Binding var 当前模式: 节点内容区.显示模式

    var body: some View {
        HStack(spacing: 0) {
            ForEach([节点内容区.显示模式.节点, .策略], id: \.self) { 模式 in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        当前模式 = 模式
                    }
                } label: {
                    Text(模式.rawValue)
                        .font(.system(size: 14, weight: 当前模式 == 模式 ? .semibold : .regular))
                        .foregroundColor(当前模式 == 模式 ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(当前模式 == 模式 ? Color.主题色 : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - 节点模式视图

/// 节点模式视图：分组列表 + 双卡片网格
private struct 节点模式视图: View {
    @EnvironmentObject private var 状态: AppState
    @EnvironmentObject private var 测速管理器: 测速管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器

    var body: some View {
        if 状态.节点分组列表.isEmpty {
            空状态视图()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach($状态.节点分组列表) { $分组 in
                        分组视图(分组: $分组)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - 分组视图

/// 分组视图
private struct 分组视图: View {
    @Binding var 分组: 节点分组模型
    @EnvironmentObject private var 状态: AppState
    @EnvironmentObject private var 测速管理器: 测速管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器

    /// 显示编辑订阅页面
    @State private var 显示编辑页面 = false
    /// 当前编辑的订阅
    @State private var 当前编辑订阅: 远程订阅模型?

    /// 双卡片网格列定义
    private let 网格列 = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 10) {
            // 分组标题行
            HStack(spacing: 12) {
                // 测速按钮
                Button {
                    执行分组测速()
                } label: {
                    ZStack {
                        if 测速管理器.是否测速中 {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                        } else {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.主题色)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(测速管理器.是否测速中)

                // 分组名称
                Text(分组.名称)
                    .font(.system(size: 15, weight: .medium))

                Spacer()

                // 节点数量 + 展开箭头
                HStack(spacing: 8) {
                    Text("\(分组.节点数量)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Image(systemName: 分组.是否展开 ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.卡片背景)
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    分组.是否展开.toggle()
                }
            }
            .contextMenu {
                节点分组上下文菜单
            }

            // 展开的节点双卡片网格
            if 分组.是否展开 {
                LazyVGrid(columns: 网格列, spacing: 10) {
                    ForEach(分组.节点列表) { 节点 in
                        节点双卡片(节点: 节点)
                            .id(节点.id)
                    }
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $显示编辑页面) {
            if let 订阅 = 当前编辑订阅 {
                编辑订阅页面(订阅: 订阅) { 新名称, 新地址 in
                    // 更新订阅信息
                    if let 索引 = 状态.远程订阅列表.firstIndex(where: { $0.id == 订阅.id }) {
                        状态.远程订阅列表[索引].名称 = 新名称
                        状态.远程订阅列表[索引].地址 = 新地址
                        状态.保存订阅列表()
                        // 更新节点分组名称
                        let 旧名称 = 订阅.名称
                        for 节点索引 in 状态.节点列表.indices {
                            if 状态.节点列表[节点索引].分组 == 旧名称 {
                                状态.节点列表[节点索引].分组 = 新名称
                            }
                        }
                        状态.节点分组列表 = Mock数据.生成节点分组(节点列表: 状态.节点列表)
                        状态.保存持久化节点()
                    }
                    显示编辑页面 = false
                }
            }
        }
    }

    /// 执行分组批量测速
    private func 执行分组测速() {
        guard !分组.节点列表.isEmpty else { return }

        测速管理器.批量测速(
            分组.节点列表,
            节点更新: { 节点, 结果 in
                if let 索引 = 分组.节点列表.firstIndex(where: { $0.id == 节点.id }) {
                    分组.节点列表[索引].测速数据 = 测速结果(
                        延迟毫秒: 结果.延迟毫秒,
                        抖动毫秒: 结果.抖动毫秒,
                        丢包率: 结果.丢包率,
                        测速时间: 结果.测速时间,
                        成功: 结果.成功
                    )
                }
            },
            全部完成: { _ in
                DispatchQueue.main.async {
                    // 测速完成后按延迟排序
                    分组.节点列表.sort { 节点1, 节点2 in
                        let 成功1 = 节点1.测速数据?.成功 ?? false
                        let 成功2 = 节点2.测速数据?.成功 ?? false
                        if 成功1 != 成功2 {
                            return 成功1 && !成功2
                        }
                        let 延迟1 = 节点1.测速数据?.延迟毫秒 ?? Int.max
                        let 延迟2 = 节点2.测速数据?.延迟毫秒 ?? Int.max
                        return 延迟1 < 延迟2
                    }
                }
            }
        )
    }

    // MARK: - 分组上下文菜单

    /// 节点分组上下文菜单
    @ViewBuilder
    private var 节点分组上下文菜单: some View {
        // 编辑分组
        Button {
            编辑分组()
        } label: {
            Label("编辑分组", systemImage: "pencil")
        }

        // 更新节点（重新订阅）
        Button {
            更新节点()
        } label: {
            Label("更新节点", systemImage: "arrow.clockwise")
        }

        // 分享二维码
        Button {
            分享二维码()
        } label: {
            Label("分享二维码", systemImage: "qrcode")
        }

        // 复制分组所有节点链接
        Button {
            复制分组所有链接()
        } label: {
            Label("复制全部节点链接", systemImage: "doc.on.doc")
        }

        // 展开/收起全部分组
        Button {
            分组.是否展开.toggle()
        } label: {
            Label(分组.是否展开 ? "收起分组" : "展开分组", systemImage: 分组.是否展开 ? "chevron.up" : "chevron.down")
        }

        // 删除分组（ destructive）
        Button(role: .destructive) {
            删除分组()
        } label: {
            Label("删除分组", systemImage: "trash")
        }
    }

    /// 编辑分组（完整编辑订阅信息）
    private func 编辑分组() {
        // 查找该分组对应的订阅
        let 分组名 = 分组.名称
        if let 订阅 = 状态.远程订阅列表.first(where: { $0.名称 == 分组名 }) {
            // 订阅分组，显示完整编辑页面
            当前编辑订阅 = 订阅
            显示编辑页面 = true
        } else {
            // 非订阅分组，仅支持重命名
            重命名分组()
        }
    }

    /// 重命名分组（非订阅分组）
    private func 重命名分组() {
        let 提示 = UIAlertController(title: "编辑分组", message: "输入新的分组名称", preferredStyle: .alert)
        提示.addTextField { 文本框 in
            文本框.text = 分组.名称
            文本框.placeholder = "分组名称"
        }
        提示.addAction(UIAlertAction(title: "取消", style: .cancel))
        提示.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            if let 新名称 = 提示.textFields?.first?.text, !新名称.isEmpty {
                let 旧名称 = 分组.名称
                for 索引 in 状态.节点列表.indices {
                    if 状态.节点列表[索引].分组 == 旧名称 {
                        状态.节点列表[索引].分组 = 新名称
                    }
                }
                状态.节点分组列表 = Mock数据.生成节点分组(节点列表: 状态.节点列表)
                状态.保存持久化节点()
            }
        })
        弹出视图控制器(提示)
    }

    /// 更新节点（重新订阅该分组）
    private func 更新节点() {
        let 分组名 = 分组.名称
        guard let 订阅 = 状态.远程订阅列表.first(where: { $0.名称 == 分组名 }) else {
            // 非订阅分组，提示无法更新
            提示信息("该分组不是订阅分组，无法更新")
            return
        }
        // 直接调用更新订阅方法
        状态.更新订阅(订阅ID: 订阅.id) { 结果 in
            DispatchQueue.main.async {
                switch 结果 {
                case .success:
                    提示信息("节点更新成功")
                case .failure(let 错误):
                    提示信息("更新失败：\(错误.localizedDescription)")
                }
            }
        }
    }

    /// 分享二维码（生成订阅地址二维码）
    private func 分享二维码() {
        let 分组名 = 分组.名称
        // 优先使用订阅地址生成二维码
        if let 订阅 = 状态.远程订阅列表.first(where: { $0.名称 == 分组名 }),
           !订阅.地址.isEmpty {
            生成并分享二维码(内容: 订阅.地址, 标题: "订阅地址")
        } else if let 第一个节点 = 分组.节点列表.first {
            // 非订阅分组，使用第一个节点链接生成二维码
            let 链接 = 生成节点链接(第一个节点)
            生成并分享二维码(内容: 链接, 标题: 第一个节点.名称)
        } else {
            提示信息("分组内无节点，无法生成二维码")
        }
    }

    /// 生成并分享二维码
    private func 生成并分享二维码(内容: String, 标题: String) {
        // 生成二维码图像
        guard let 二维码图像 = 生成二维码图像(内容: 内容) else {
            提示信息("二维码生成失败")
            return
        }

        // 保存到临时文件
        let 临时路径 = FileManager.default.temporaryDirectory.appendingPathComponent("\(标题).png")
        if let png数据 = 二维码图像.pngData() {
            try? png数据.write(to: 临时路径)
        }

        // 分享二维码
        let 活动控制器 = UIActivityViewController(
            activityItems: [二维码图像, 标题],
            applicationActivities: nil
        )

        // 获取最顶层视图控制器
        guard let 窗口 = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              var 顶层控制器 = 窗口.rootViewController else {
            return
        }
        while let 弹出的 = 顶层控制器.presentedViewController {
            顶层控制器 = 弹出的
        }

        // iPad 适配
        if let 弹出控制器 = 活动控制器.popoverPresentationController {
            弹出控制器.sourceView = 顶层控制器.view
            弹出控制器.sourceRect = CGRect(
                x: 顶层控制器.view.bounds.midX,
                y: 顶层控制器.view.bounds.midY,
                width: 0, height: 0
            )
            弹出控制器.permittedArrowDirections = []
        }

        顶层控制器.present(活动控制器, animated: true)
    }

    /// 生成二维码图像（带白色背景，确保可扫描）
    private func 生成二维码图像(内容: String) -> UIImage? {
        guard let 数据 = 内容.data(using: .utf8),
              let 滤镜 = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        滤镜.setValue(数据, forKey: "inputMessage")
        滤镜.setValue("M", forKey: "inputCorrectionLevel")

        guard let 输出图像 = 滤镜.outputImage else {
            return nil
        }

        // 缩放
        let 缩放比例: CGFloat = 20
        let 缩放图像 = 输出图像.transformed(by: CGAffineTransform(scaleX: 缩放比例, y: 缩放比例))

        // 转换为 CGImage
        let 上下文 = CIContext()
        guard let cg图像 = 上下文.createCGImage(缩放图像, from: 缩放图像.extent) else {
            return nil
        }

        // 添加白色背景，确保二维码可扫描
        let 尺寸 = CGSize(width: cg图像.width, height: cg图像.height)
        let 渲染器 = UIGraphicsImageRenderer(size: 尺寸)
        let 最终图像 = 渲染器.image { 上下文 in
            // 白色背景
            UIColor.white.setFill()
            上下文.fill(CGRect(origin: .zero, size: 尺寸))
            // 绘制二维码
            上下文.cgContext.draw(cg图像, in: CGRect(origin: .zero, size: 尺寸))
        }

        return 最终图像
    }

    /// 提示信息
    private func 提示信息(_ 消息: String) {
        let 提示 = UIAlertController(title: "提示", message: 消息, preferredStyle: .alert)
        提示.addAction(UIAlertAction(title: "确定", style: .default))
        弹出视图控制器(提示)
    }

    /// 弹出视图控制器
    private func 弹出视图控制器(_ 控制器: UIViewController) {
        guard let 窗口 = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              var 顶层控制器 = 窗口.rootViewController else {
            return
        }
        while let 弹出的 = 顶层控制器.presentedViewController {
            顶层控制器 = 弹出的
        }
        顶层控制器.present(控制器, animated: true)
    }

    /// 复制分组所有节点链接
    private func 复制分组所有链接() {
        let 链接列表 = 分组.节点列表.map { 节点 -> String in
            生成节点链接(节点)
        }
        let 全部链接 = 链接列表.joined(separator: "\n")
        UIPasteboard.general.string = 全部链接
    }

    /// 生成单个节点链接
    private func 生成节点链接(_ 节点: 节点模型) -> String {
        let 名称编码 = 节点.名称.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? 节点.名称

        switch 节点.协议 {
        case .vless:
            var 参数 = [String]()
            参数.append("encryption=none")
            参数.append("type=\(节点.传输类型 == .ws ? "ws" : "tcp")")
            if let 路径 = 节点.ws路径, !路径.isEmpty {
                参数.append("path=\(路径.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? 路径)")
            }
            if let 主机 = 节点.ws主机, !主机.isEmpty {
                参数.append("host=\(主机)")
            }
            if 节点.启用TLS {
                参数.append("security=tls")
                if let sni = 节点.服务器名称, !sni.isEmpty {
                    参数.append("sni=\(sni)")
                }
            } else {
                参数.append("security=none")
            }
            let uuid = 节点.用户标识 ?? ""
            return "vless://\(uuid)@\(节点.地址):\(节点.端口)?\(参数.joined(separator: "&"))#\(名称编码)"

        case .vmess:
            let vmess字典: [String: Any] = [
                "v": "2", "ps": 节点.名称, "add": 节点.地址,
                "port": "\(节点.端口)", "id": 节点.用户标识 ?? "",
                "aid": "0", "scy": "auto",
                "net": 节点.传输类型 == .ws ? "ws" : "tcp",
                "type": "none", "host": 节点.ws主机 ?? "",
                "path": 节点.ws路径 ?? "",
                "tls": 节点.启用TLS ? "tls" : "",
                "sni": 节点.服务器名称 ?? ""
            ]
            if let json数据 = try? JSONSerialization.data(withJSONObject: vmess字典),
               let json字符串 = String(data: json数据, encoding: .utf8) {
                let base64 = json字符串.data(using: .utf8)?.base64EncodedString() ?? ""
                return "vmess://\(base64)"
            }
            return "vmess://\(节点.地址):\(节点.端口)"

        case .trojan:
            var 参数 = [String]()
            参数.append("type=\(节点.传输类型 == .ws ? "ws" : "tcp")")
            if let 路径 = 节点.ws路径, !路径.isEmpty {
                参数.append("path=\(路径.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? 路径)")
            }
            if let 主机 = 节点.ws主机, !主机.isEmpty {
                参数.append("host=\(主机)")
            }
            if 节点.启用TLS {
                参数.append("security=tls")
                if let sni = 节点.服务器名称, !sni.isEmpty {
                    参数.append("sni=\(sni)")
                }
            }
            let 密码 = 节点.用户标识 ?? ""
            return "trojan://\(密码)@\(节点.地址):\(节点.端口)?\(参数.joined(separator: "&"))#\(名称编码)"

        case .shadowsocks:
            let 方法密码 = "\(节点.用户标识 ?? "")"
            let base64 = 方法密码.data(using: .utf8)?.base64EncodedString() ?? ""
            return "ss://\(base64)@\(节点.地址):\(节点.端口)#\(名称编码)"
        }
    }

    /// 删除分组（删除该分组所有节点）
    private func 删除分组() {
        let 分组名 = 分组.名称
        状态.节点列表.removeAll { $0.分组 == 分组名 }
        状态.节点分组列表 = Mock数据.生成节点分组(节点列表: 状态.节点列表)
        // 保存到持久化文件，避免删除后反复出现
        状态.保存持久化节点()
    }
}

// MARK: - 节点双卡片

/// 节点双卡片（一行两列）
private struct 节点双卡片: View {
    let 节点: 节点模型
    @EnvironmentObject private var 状态: AppState
    @EnvironmentObject private var 测速管理器: 测速管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器

    @State private var 显示删除确认 = false
    @State private var 显示移动分组 = false
    @State private var 显示编辑节点 = false
    @State private var 显示Toast = false
    @State private var Toast消息 = ""

    private var 是否选中: Bool {
        状态.当前节点ID == 节点.id
    }

    private var 延迟颜色: Color {
        guard let 延迟 = 节点.测速数据?.延迟毫秒, 节点.测速数据?.成功 == true else {
            return .secondary
        }
        if 延迟 < 100 { return .green }
        if 延迟 < 300 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：协议标签
            HStack(spacing: 4) {
                Text(节点.协议.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(是否选中 ? Color.主题色 : Color.主题色.opacity(0.7))
                    .cornerRadius(4)

                Spacer()

                if 是否选中 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.主题色)
                }
            }

            // 第二行：节点名称
            Text(节点.名称)
                .font(.system(size: 13, weight: 是否选中 ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(.primary)

            // 第三行：域名/IP + 端口
            Text("\(节点.地址):\(节点.端口)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // 第四行：延迟值
            HStack(spacing: 4) {
                if 测速管理器.节点测速状态[节点.id]?.是否测速中 == true {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .主题色))
                        .scaleEffect(0.7)
                    Text("测速中")
                        .font(.system(size: 11))
                        .foregroundColor(.主题色)
                } else if let 延迟 = 节点.测速数据?.延迟毫秒, 节点.测速数据?.成功 == true {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(延迟颜色)
                    Text("\(延迟)ms")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(延迟颜色)
                } else {
                    Image(systemName: "bolt.slash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("未测速")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(height: 100)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.卡片背景)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(是否选中 ? Color.主题色 : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            选中节点()
        }
        .contextMenu {
            上下文菜单内容
        }
        .alert("确认删除节点", isPresented: $显示删除确认) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                状态.删除节点(节点.id)
            }
        } message: {
            Text("确定要删除节点「\(节点.名称)」吗？此操作不可恢复。")
        }
        .sheet(isPresented: $显示移动分组) {
            移动分组页面(节点: 节点)
                .environmentObject(状态)
        }
        .sheet(isPresented: $显示编辑节点) {
            编辑节点页面(节点: 节点)
                .environmentObject(状态)
        }
        .overlay(
            Group {
                if 显示Toast {
                    小型Toast视图(消息: Toast消息)
                }
            }
        )
    }

    // MARK: - 上下文菜单

    @ViewBuilder
    private var 上下文菜单内容: some View {
        Button {
            测速管理器.测速节点(节点) { _ in }
        } label: {
            Label("节点测试", systemImage: "gauge")
        }

        Button {
            复制节点链接()
        } label: {
            Label("复制节点链接", systemImage: "doc.on.doc")
        }

        Button {
            显示编辑节点 = true
        } label: {
            Label("编辑节点", systemImage: "pencil")
        }

        Button {
            显示移动分组 = true
        } label: {
            Label("移动至其他分组", systemImage: "folder")
        }

        Button(role: .destructive) {
            显示删除确认 = true
        } label: {
            Label("删除节点", systemImage: "trash")
        }
    }

    /// 复制节点链接
    private func 复制节点链接() {
        let 链接 = 生成标准节点链接()
        UIPasteboard.general.string = 链接
        显示Toast消息("节点链接已复制")
    }

    /// 生成标准节点分享链接
    private func 生成标准节点链接() -> String {
        let 名称编码 = 节点.名称.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? 节点.名称

        switch 节点.协议 {
        case .vless:
            var 参数 = [String]()
            参数.append("encryption=none")
            参数.append("type=\(节点.传输类型 == .ws ? "ws" : "tcp")")
            if let 路径 = 节点.ws路径, !路径.isEmpty {
                参数.append("path=\(路径.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? 路径)")
            }
            if let 主机 = 节点.ws主机, !主机.isEmpty {
                参数.append("host=\(主机)")
            }
            if 节点.启用TLS {
                参数.append("security=tls")
                if let sni = 节点.服务器名称, !sni.isEmpty {
                    参数.append("sni=\(sni)")
                }
            } else {
                参数.append("security=none")
            }
            let uuid = 节点.用户标识 ?? ""
            return "vless://\(uuid)@\(节点.地址):\(节点.端口)?\(参数.joined(separator: "&"))#\(名称编码)"

        case .vmess:
            let vmess字典: [String: Any] = [
                "v": "2", "ps": 节点.名称, "add": 节点.地址,
                "port": "\(节点.端口)", "id": 节点.用户标识 ?? "",
                "aid": "0", "scy": "auto",
                "net": 节点.传输类型 == .ws ? "ws" : "tcp",
                "type": "none", "host": 节点.ws主机 ?? "",
                "path": 节点.ws路径 ?? "",
                "tls": 节点.启用TLS ? "tls" : "",
                "sni": 节点.服务器名称 ?? ""
            ]
            if let json数据 = try? JSONSerialization.data(withJSONObject: vmess字典),
               let json字符串 = String(data: json数据, encoding: .utf8) {
                let base64 = json字符串.data(using: .utf8)?.base64EncodedString() ?? ""
                return "vmess://\(base64)"
            }
            return "vmess://\(节点.地址):\(节点.端口)"

        case .trojan:
            var 参数 = [String]()
            参数.append("type=\(节点.传输类型 == .ws ? "ws" : "tcp")")
            if let 路径 = 节点.ws路径, !路径.isEmpty {
                参数.append("path=\(路径.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? 路径)")
            }
            if let 主机 = 节点.ws主机, !主机.isEmpty {
                参数.append("host=\(主机)")
            }
            if 节点.启用TLS {
                参数.append("security=tls")
                if let sni = 节点.服务器名称, !sni.isEmpty {
                    参数.append("sni=\(sni)")
                }
            }
            let 密码 = 节点.用户标识 ?? ""
            return "trojan://\(密码)@\(节点.地址):\(节点.端口)?\(参数.joined(separator: "&"))#\(名称编码)"

        case .shadowsocks:
            let 方法密码 = "\(节点.用户标识 ?? "")"
            let base64 = 方法密码.data(using: .utf8)?.base64EncodedString() ?? ""
            return "ss://\(base64)@\(节点.地址):\(节点.端口)#\(名称编码)"
        }
    }

    /// 显示 Toast
    private func 显示Toast消息(_ 消息: String) {
        Toast消息 = 消息
        withAnimation(.easeInOut(duration: 0.2)) {
            显示Toast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                显示Toast = false
            }
        }
    }

    /// 选中节点
    private func 选中节点() {
        状态.当前节点ID = 节点.id
        隧道管理.切换节点并重载(节点ID: 节点.id, 节点名称: 节点.名称)
    }
}

// MARK: - 策略模式视图

/// 策略模式视图：sing-box 策略组列表
private struct 策略模式视图: View {
    @EnvironmentObject private var 状态: AppState
    @EnvironmentObject private var 测速管理器: 测速管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器

    /// 双卡片网格列定义
    private let 网格列 = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
                Text("策略组")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    全部测速()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                        Text("全部测速")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.主题色)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)

            if 状态.策略组列表.isEmpty {
                策略空状态视图()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach($状态.策略组列表) { $策略组 in
                            策略组视图(策略组: $策略组)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    /// 全部测速
    private func 全部测速() {
        for 策略组 in 状态.策略组列表 {
            策略组管理器.共享.测速(组名: 策略组.名称) { _ in }
        }
    }
}

// MARK: - 策略组视图

/// 策略组视图
private struct 策略组视图: View {
    @Binding var 策略组: 策略组模型
    @EnvironmentObject private var 状态: AppState
    @EnvironmentObject private var 测速管理器: 测速管理器
    @EnvironmentObject private var 隧道管理: 隧道管理器

    /// 双卡片网格列定义
    private let 网格列 = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    /// 策略类型颜色
    private var 类型颜色: Color {
        switch 策略组.类型 {
        case "selector": return .blue
        case "urltest": return .green
        case "fallback": return .orange
        case "loadbalance": return .purple
        default: return .gray
        }
    }

    /// 是否可手动切换
    private var 可手动切换: Bool {
        策略组.类型 == "selector"
    }

    var body: some View {
        VStack(spacing: 10) {
            // 策略组标题行
            HStack(spacing: 10) {
                // 类型标签
                Text(策略组.类型.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(类型颜色)
                    .cornerRadius(4)

                // 组名
                Text(策略组.名称)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Spacer()

                // 当前节点 + 延迟
                VStack(alignment: .trailing, spacing: 2) {
                    Text(策略组.当前节点 ?? "未选择")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    if let 延迟 = 策略组.最低延迟 {
                        Text("\(延迟)ms")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(延迟 < 100 ? .green : (延迟 < 300 ? .orange : .red))
                    }
                }

                // 展开箭头
                Image(systemName: 策略组.是否展开 ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.卡片背景)
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    策略组.是否展开.toggle()
                }
            }
            .contextMenu {
                策略分组上下文菜单
            }

            // 展开的节点双卡片网格
            if 策略组.是否展开 {
                LazyVGrid(columns: 网格列, spacing: 10) {
                    ForEach(策略组.节点列表, id: \.self) { 节点名 in
                        策略节点卡片(
                            节点名: 节点名,
                            组名: 策略组.名称,
                            是否当前: 策略组.当前节点 == 节点名,
                            可手动切换: 可手动切换,
                            延迟: 策略组.节点延迟[节点名]
                        )
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - 策略分组上下文菜单

    /// 策略分组上下文菜单
    @ViewBuilder
    private var 策略分组上下文菜单: some View {
        // 组内测速
        Button {
            策略组管理器.共享.测速(组名: 策略组.名称) { _ in }
        } label: {
            Label("组内测速", systemImage: "gauge")
        }

        // 复制当前节点
        Button {
            if let 当前节点 = 策略组.当前节点 {
                UIPasteboard.general.string = 当前节点
            }
        } label: {
            Label("复制当前节点", systemImage: "doc.on.doc")
        }

        // 复制组名
        Button {
            UIPasteboard.general.string = 策略组.名称
        } label: {
            Label("复制组名", systemImage: "textformat")
        }

        // 展开/收起
        Button {
            策略组.是否展开.toggle()
        } label: {
            Label(策略组.是否展开 ? "收起分组" : "展开分组", systemImage: 策略组.是否展开 ? "chevron.up" : "chevron.down")
        }

        // 类型说明
        Button {
            // 类型说明通过 Toast 或 Alert 展示
        } label: {
            Label("类型说明：\(策略组.类型标题)", systemImage: "info.circle")
        }
    }
}

// MARK: - 策略节点卡片

/// 策略组内节点卡片
private struct 策略节点卡片: View {
    let 节点名: String
    let 组名: String
    let 是否当前: Bool
    let 可手动切换: Bool
    let 延迟: Int?

    @State private var 显示Toast = false
    @State private var Toast消息 = ""

    private var 延迟颜色: Color {
        guard let 延迟 = 延迟 else { return .secondary }
        if 延迟 < 100 { return .green }
        if 延迟 < 300 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 节点名称
            Text(节点名)
                .font(.system(size: 13, weight: 是否当前 ? .semibold : .regular))
                .lineLimit(2)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // 底部：延迟 + 状态
            HStack(spacing: 4) {
                if let 延迟 = 延迟 {
                    Text("\(延迟)ms")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(延迟颜色)
                } else {
                    Text("未测速")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if 是否当前 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.主题色)
                } else if !可手动切换 {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(height: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(是否当前 ? Color.主题色.opacity(0.12) : Color.卡片背景)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(是否当前 ? Color.主题色.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if 可手动切换 && !是否当前 {
                切换节点()
            }
        }
        .opacity(可手动切换 ? 1.0 : 0.8)
        .overlay(
            Group {
                if 显示Toast {
                    小型Toast视图(消息: Toast消息)
                }
            }
        )
    }

    /// 切换节点
    private func 切换节点() {
        策略组管理器.共享.切换节点(组名: 组名, 节点名: 节点名) { 成功 in
            DispatchQueue.main.async {
                if 成功 {
                    显示Toast消息("已切换到 \(节点名)")
                } else {
                    显示Toast消息("切换失败")
                }
            }
        }
    }

    /// 显示 Toast
    private func 显示Toast消息(_ 消息: String) {
        Toast消息 = 消息
        withAnimation(.easeInOut(duration: 0.2)) {
            显示Toast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                显示Toast = false
            }
        }
    }
}

// MARK: - 空状态视图

/// 节点空状态视图
private struct 空状态视图: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无节点")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text("请在「编辑配置文件」中添加远程订阅并更新")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// 策略空状态视图
private struct 策略空状态视图: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无策略组")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text("连接 VPN 后自动加载策略组数据")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - 小型 Toast 视图

/// 小型 Toast 提示（用于卡片内）
private struct 小型Toast视图: View {
    let 消息: String

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                Text(消息)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - 编辑节点页面

/// 编辑节点信息页面
private struct 编辑节点页面: View {
    let 节点: 节点模型
    @EnvironmentObject private var 状态: AppState
    @Environment(\.dismiss) private var 关闭

    @State private var 名称: String
    @State private var 地址: String
    @State private var 端口: String
    @State private var 用户标识: String
    @State private var 选中传输类型: 传输类型
    @State private var 启用TLS: Bool
    @State private var 服务器名称: String
    @State private var ws路径: String
    @State private var ws主机: String
    @State private var 分组: String
    @State private var 备注: String

    @State private var 名称错误: String?
    @State private var 地址错误: String?
    @State private var 端口错误: String?
    @State private var UUID错误: String?

    @State private var 显示Toast = false
    @State private var Toast消息 = ""
    @State private var Toast成功 = true

    init(节点: 节点模型) {
        self.节点 = 节点
        _名称 = State(initialValue: 节点.名称)
        _地址 = State(initialValue: 节点.地址)
        _端口 = State(initialValue: "\(节点.端口)")
        _用户标识 = State(initialValue: 节点.用户标识 ?? "")
        _选中传输类型 = State(initialValue: 节点.传输类型)
        _启用TLS = State(initialValue: 节点.启用TLS)
        _服务器名称 = State(initialValue: 节点.服务器名称 ?? "")
        _ws路径 = State(initialValue: 节点.ws路径 ?? "")
        _ws主机 = State(initialValue: 节点.ws主机 ?? "")
        _分组 = State(initialValue: 节点.分组)
        _备注 = State(initialValue: 节点.备注 ?? "")
    }

    private var 有修改: Bool {
        名称 != 节点.名称 || 地址 != 节点.地址 || 端口 != "\(节点.端口)" ||
        用户标识 != (节点.用户标识 ?? "") || 选中传输类型 != 节点.传输类型 ||
        启用TLS != 节点.启用TLS || 服务器名称 != (节点.服务器名称 ?? "") ||
        ws路径 != (节点.ws路径 ?? "") || ws主机 != (节点.ws主机 ?? "") ||
        分组 != 节点.分组 || 备注 != (节点.备注 ?? "")
    }

    private var 需要UUID: Bool {
        节点.协议 == .vless || 节点.协议 == .vmess || 节点.协议 == .trojan
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section("基本信息") {
                        标签文本行(标签: "协议", 内容: 节点.协议.rawValue)
                        标签输入行(标签: "节点名称", 占位: "请输入节点名称", 文本: $名称, 错误: $名称错误)
                        标签输入行(标签: "地址", 占位: "域名/IP", 文本: $地址, 错误: $地址错误, 键盘类型: .URL)
                        标签输入行(标签: "端口", 占位: "1~65535", 文本: $端口, 错误: $端口错误, 键盘类型: .numberPad)
                        if 需要UUID {
                            标签输入行(标签: "UUID", 占位: 节点.协议 == .trojan ? "Trojan密码" : "VLESS UUID", 文本: $用户标识, 错误: $UUID错误)
                        }
                    }

                    Section("传输设置") {
                        Picker("传输类型", selection: $选中传输类型) {
                            ForEach(传输类型.allCases, id: \.self) { 类型 in
                                Text(类型.rawValue).tag(类型)
                            }
                        }
                    }

                    if 启用TLS {
                        Section("TLS 设置") {
                            标签输入行(标签: "SNI", 占位: "TLS服务器名称", 文本: $服务器名称, 错误: .constant(nil), 键盘类型: .URL)
                        }
                    }

                    if 选中传输类型 == .ws {
                        Section("WebSocket 设置") {
                            标签输入行(标签: "路径", 占位: "WebSocket路径，如 /ws", 文本: $ws路径, 错误: .constant(nil), 键盘类型: .URL)
                            标签输入行(标签: "Host", 占位: "WebSocket Host头", 文本: $ws主机, 错误: .constant(nil), 键盘类型: .URL)
                        }
                    }

                    Section("安全设置") {
                        Toggle("启用 TLS", isOn: $启用TLS)
                            .tint(.主题色)
                    }

                    Section("分组与备注") {
                        标签输入行(标签: "分组", 占位: "分组名称", 文本: $分组, 错误: .constant(nil))
                        标签输入行(标签: "备注", 占位: "可选备注信息", 文本: $备注, 错误: .constant(nil))
                    }
                }

                if 显示Toast {
                    带状态Toast视图(消息: Toast消息, 成功: Toast成功)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .zIndex(100)
                }
            }
            .navigationTitle("编辑节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 关闭() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { 保存节点() }
                        .disabled(!有修改)
                }
            }
        }
    }

    private func 校验字段() -> Bool {
        var 校验通过 = true

        if 名称.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            名称错误 = "节点名称不能为空"; 校验通过 = false
        } else { 名称错误 = nil }

        if 地址.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            地址错误 = "地址不能为空"; 校验通过 = false
        } else { 地址错误 = nil }

        if let 端口号 = Int(端口), 端口号 >= 1, 端口号 <= 65535 {
            端口错误 = nil
        } else {
            端口错误 = "端口必须为1~65535的数字"; 校验通过 = false
        }

        if 需要UUID {
            if 节点.协议 == .vless || 节点.协议 == .vmess {
                let uuid正则 = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
                if 用户标识.range(of: uuid正则, options: .regularExpression) == nil {
                    UUID错误 = "UUID格式不正确"; 校验通过 = false
                } else { UUID错误 = nil }
            } else if 节点.协议 == .trojan {
                if 用户标识.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    UUID错误 = "密码不能为空"; 校验通过 = false
                } else { UUID错误 = nil }
            }
        }

        return 校验通过
    }

    private func 保存节点() {
        guard 校验字段() else {
            显示Toast消息("请修正标红的字段", 成功: false)
            return
        }

        guard let 端口号 = Int(端口) else {
            显示Toast消息("端口格式错误", 成功: false)
            return
        }

        var 修改后节点 = 节点
        修改后节点.名称 = 名称.trimmingCharacters(in: .whitespacesAndNewlines)
        修改后节点.地址 = 地址.trimmingCharacters(in: .whitespacesAndNewlines)
        修改后节点.端口 = 端口号
        修改后节点.用户标识 = 用户标识.isEmpty ? nil : 用户标识
        修改后节点.传输类型 = 选中传输类型
        修改后节点.启用TLS = 启用TLS
        修改后节点.服务器名称 = 服务器名称.isEmpty ? nil : 服务器名称
        修改后节点.ws路径 = ws路径.isEmpty ? nil : ws路径
        修改后节点.ws主机 = ws主机.isEmpty ? nil : ws主机
        修改后节点.分组 = 分组.isEmpty ? "默认分组" : 分组
        修改后节点.备注 = 备注.isEmpty ? nil : 备注

        状态.更新节点(修改后节点)
        显示Toast消息("节点保存成功", 成功: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            关闭()
        }
    }

    private func 显示Toast消息(_ 消息: String, 成功: Bool) {
        Toast消息 = 消息
        Toast成功 = 成功
        withAnimation(.easeInOut(duration: 0.2)) { 显示Toast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) { 显示Toast = false }
        }
    }
}

// MARK: - 标签输入行组件

private struct 标签输入行: View {
    let 标签: String
    let 占位: String
    @Binding var 文本: String
    @Binding var 错误: String?
    var 键盘类型: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(标签)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .leading)
                TextField(占位, text: $文本)
                    .font(.system(size: 14))
                    .autocapitalization(.none)
                    .keyboardType(键盘类型)
            }
            .padding(.vertical, 6)

            if let 错误 = 错误, !错误.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.危险色)
                    Text(错误)
                        .font(.system(size: 11))
                        .foregroundColor(.危险色)
                }
                .padding(.leading, 82)
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct 标签文本行: View {
    let 标签: String
    let 内容: String

    var body: some View {
        HStack(spacing: 12) {
            Text(标签)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 70, alignment: .leading)
            Text(内容)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

private struct 带状态Toast视图: View {
    let 消息: String
    let 成功: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: 成功 ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                Text(消息)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(成功 ? Color.green.opacity(0.9) : Color.危险色.opacity(0.9))
            .cornerRadius(20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - 移动分组页面

private struct 移动分组页面: View {
    let 节点: 节点模型
    @EnvironmentObject private var 状态: AppState
    @Environment(\.dismiss) private var 关闭
    @State private var 新分组名称 = ""
    @State private var 显示错误提示 = false
    @State private var 错误消息 = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("当前分组") {
                    HStack {
                        Text(节点.分组)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "location.fill")
                            .foregroundColor(.主题色)
                            .font(.system(size: 12))
                    }
                }

                Section("选择目标分组") {
                    ForEach(状态.获取所有分组名称(), id: \.self) { 分组名 in
                        Button {
                            选择分组(分组名)
                        } label: {
                            HStack {
                                Text(分组名)
                                    .foregroundColor(.primary)
                                Spacer()
                                if 分组名 == 节点.分组 {
                                    Text("当前")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(4)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("或创建新分组") {
                    TextField("新分组名称", text: $新分组名称)
                    Button {
                        if !新分组名称.isEmpty {
                            if 新分组名称 == 节点.分组 {
                                显示错误("不能移动至当前分组")
                            } else {
                                执行移动(目标分组: 新分组名称)
                            }
                        }
                    } label: {
                        Text("移动到新分组")
                            .foregroundColor(.主题色)
                    }
                    .disabled(新分组名称.isEmpty)
                }
            }
            .navigationTitle("移动节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 关闭() }
                }
            }
            .alert("提示", isPresented: $显示错误提示) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(错误消息)
            }
        }
    }

    private func 选择分组(_ 分组名: String) {
        if 分组名 == 节点.分组 {
            显示错误("不能移动至当前分组")
            return
        }
        执行移动(目标分组: 分组名)
    }

    private func 执行移动(目标分组: String) {
        状态.移动节点(节点.id, 到目标分组: 目标分组)
        关闭()
    }

    private func 显示错误(_ 消息: String) {
        错误消息 = 消息
        显示错误提示 = true
    }
}

// MARK: - 编辑订阅页面（SwiftUI 精致实现）

/// 编辑订阅页面
private struct 编辑订阅页面: View {
    /// 原始订阅
    let 订阅: 远程订阅模型
    /// 完成回调（新名称，新地址）
    let 完成: (String, String) -> Void

    /// 订阅名称
    @State private var 名称: String
    /// 订阅地址
    @State private var 地址: String
    /// 显示错误提示
    @State private var 显示错误 = false
    /// 错误消息
    @State private var 错误消息 = ""
    /// 环境
    @Environment(\.dismiss) private var 关闭

    init(订阅: 远程订阅模型, 完成: @escaping (String, String) -> Void) {
        self.订阅 = 订阅
        self.完成 = 完成
        _名称 = State(initialValue: 订阅.名称)
        _地址 = State(initialValue: 订阅.地址)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 订阅信息卡片
                    VStack(alignment: .leading, spacing: 16) {
                        // 标题
                        HStack {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.主题色)
                            Text("编辑订阅")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
                        }

                        // 订阅名称
                        VStack(alignment: .leading, spacing: 8) {
                            Text("订阅名称")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("请输入订阅名称", text: $名称)
                                .font(.system(size: 15))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .autocapitalization(.none)
                        }

                        // 资源网址
                        VStack(alignment: .leading, spacing: 8) {
                            Text("资源网址")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("请输入订阅地址 URL", text: $地址, axis: .vertical)
                                .font(.system(size: 15))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                                .lineLimit(3...5)
                        }

                        // 订阅信息
                        VStack(alignment: .leading, spacing: 8) {
                            信息行(标签: "节点数量", 值: "\(订阅.节点数量) 个")
                            信息行(标签: "上次更新", 值: 订阅.上次更新显示)
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                    .background(Color.卡片背景)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                    // 保存按钮
                    Button {
                        保存()
                    } label: {
                        HStack {
                            Spacer()
                            Text("保存")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(Color.主题色)
                        .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color.页面背景.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        关闭()
                    }
                    .foregroundColor(.主题色)
                }
            }
            .alert("错误", isPresented: $显示错误) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(错误消息)
            }
        }
    }

    /// 信息行
    private struct 信息行: View {
        let 标签: String
        let 值: String

        var body: some View {
            HStack {
                Text(标签)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Text(值)
                    .font(.system(size: 13, weight: .medium))
            }
        }
    }

    /// 保存
    private func 保存() {
        let 新名称 = 名称.trimmingCharacters(in: .whitespacesAndNewlines)
        let 新地址 = 地址.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !新名称.isEmpty else {
            错误消息 = "订阅名称不能为空"
            显示错误 = true
            return
        }
        guard !新地址.isEmpty else {
            错误消息 = "订阅地址不能为空"
            显示错误 = true
            return
        }

        完成(新名称, 新地址)
    }
}

// MARK: - 预览

#Preview {
    节点内容区()
        .environmentObject(AppState.共享)
        .environmentObject(测速管理器.共享)
        .environmentObject(隧道管理器.共享)
        .background(Color.页面背景)
}
