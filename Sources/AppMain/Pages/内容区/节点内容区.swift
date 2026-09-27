//
//  节点内容区.swift
//  NewVPN
//
//  节点卡片对应的内容区：分组列表 + 展开节点详情
//  右滑卡片露出测速按钮
//

import SwiftUI

/// 节点内容区视图
struct 节点内容区: View {
    /// 全局应用状态
    @EnvironmentObject private var 状态: AppState
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    var body: some View {
        VStack(spacing: 10) {
            if 状态.节点分组列表.isEmpty {
                // 空状态：无节点时提示添加远程订阅
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
            } else {
                // 分组列表（远程订阅导入的节点按订阅名称分组常驻显示）
                VStack(spacing: 10) {
                    ForEach($状态.节点分组列表) { $分组 in
                        分组行视图(分组: $分组)
                    }
                }
                .padding(.horizontal, 15)
            }
        }
    }
}

// MARK: - 分组行视图

/// 节点分组行视图
private struct 分组行视图: View {
    /// 分组数据绑定
    @Binding var 分组: 节点分组模型
    /// 全局状态
    @EnvironmentObject private var 状态: AppState
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    var body: some View {
        VStack(spacing: 0) {
            // 分组标题行
            HStack(spacing: 12) {
                // 左侧测速图标按钮
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
                Button {
                    复制分组JSON()
                } label: {
                    Label("复制 JSON", systemImage: "doc.on.doc")
                }
                Button {
                    分享分组JSON()
                } label: {
                    Label("分享 JSON", systemImage: "square.and.arrow.up")
                }
            }

            // 展开的节点列表
            if 分组.是否展开 {
                VStack(spacing: 8) {
                    ForEach(分组.节点列表) { 节点 in
                        可滑动节点行视图(节点: 节点)
                            .id(节点.id)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
    }

    /// 执行分组批量测速（完成后按延迟排序）
    private func 执行分组测速() {
        guard !分组.节点列表.isEmpty else { return }

        测速管理器.批量测速(
            分组.节点列表,
            节点更新: { 节点, 结果 in
                // 更新节点测速数据
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
                // 测速完成后按延迟排序（成功的在前，失败的在后）
                DispatchQueue.main.async {
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

    // MARK: - 分组 JSON 导出

    /// 生成分组内所有节点的 sing-box 出站配置 JSON 字符串
    private func 生成分组JSON() -> String {
        let 出站列表 = 分组.节点列表.compactMap { 节点 in
            SingBox配置生成器.共享.节点转换为出站(节点, 标签: 节点.名称)
        }
        let 编码器 = JSONEncoder()
        编码器.keyEncodingStrategy = .convertToSnakeCase
        编码器.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let 数据 = try? 编码器.encode(出站列表) else { return "" }
        return String(data: 数据, encoding: .utf8) ?? ""
    }

    /// 复制分组 JSON 到剪贴板
    private func 复制分组JSON() {
        let json = 生成分组JSON()
        guard !json.isEmpty else { return }
        UIPasteboard.general.string = json
    }

    /// 分享分组 JSON（弹出 iOS 系统分享面板）
    private func 分享分组JSON() {
        let json = 生成分组JSON()
        guard !json.isEmpty else { return }

        let 活动控制器 = UIActivityViewController(
            activityItems: [json],
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
}

// MARK: - 可滑动节点行视图

/// 可滑动节点行视图（右滑露出测速按钮）
private struct 可滑动节点行视图: View {
    /// 节点数据
    let 节点: 节点模型
    /// 全局状态
    @EnvironmentObject private var 状态: AppState
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器
    /// 隧道管理器（连接状态下实时切换节点）
    @EnvironmentObject private var 隧道管理: 隧道管理器

    /// 滑动偏移量
    @State private var 偏移量: CGFloat = 0
    /// 拖拽起始偏移量
    @State private var 拖拽起始偏移: CGFloat = 0
    /// 显示删除确认弹窗
    @State private var 显示删除确认 = false
    /// 显示移动分组弹窗
    @State private var 显示移动分组 = false
    /// 显示编辑节点
    @State private var 显示编辑节点 = false
    /// Toast 提示
    @State private var 显示Toast = false
    @State private var Toast消息 = ""

    /// 展开宽度（测速按钮宽度）
    private let 展开宽度: CGFloat = 70

    /// 是否为当前选中节点
    private var 是否选中: Bool {
        状态.当前节点ID == 节点.id
    }

    /// 节点是否有效（非空、地址端口有效）
    private var 节点有效: Bool {
        !节点.名称.isEmpty && !节点.地址.isEmpty && 节点.端口 > 0 && 节点.端口 <= 65535
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // 底层：测速按钮（仅在滑动时显示，避免幻影）
            HStack(spacing: 0) {
                Button {
                    测速管理器.测速节点(节点) { _ in }
                    // 测速后自动收起
                    withAnimation(.easeOut(duration: 0.2)) {
                        偏移量 = 0
                    }
                } label: {
                    VStack(spacing: 4) {
                        if 测速管理器.节点测速状态[节点.id]?.是否测速中 == true {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text("测速")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 展开宽度, height: 60)
                    .background(Color.测速绿色)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .opacity(偏移量 > 5 ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: 偏移量)

            // 上层：节点卡片内容
            节点卡片内容(节点: 节点, 是否选中: 是否选中)
                .offset(x: 偏移量)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { 值 in
                            if 拖拽起始偏移 == 0 {
                                拖拽起始偏移 = 偏移量
                            }
                            let 目标偏移 = 拖拽起始偏移 + 值.translation.width
                            // 限制滑动范围，添加阻尼效果
                            if 目标偏移 < 0 {
                                偏移量 = 目标偏移 * 0.3
                            } else if 目标偏移 > 展开宽度 {
                                偏移量 = 展开宽度 + (目标偏移 - 展开宽度) * 0.3
                            } else {
                                偏移量 = 目标偏移
                            }
                        }
                        .onEnded { 值 in
                            let 最终速度 = 值.predictedEndTranslation.width - 值.translation.width
                            withAnimation(.easeOut(duration: 0.25)) {
                                if 偏移量 > 展开宽度 / 2 || 最终速度 > 50 {
                                    偏移量 = 展开宽度
                                } else {
                                    偏移量 = 0
                                }
                            }
                            拖拽起始偏移 = 0
                        }
                )
                .onTapGesture {
                    if 偏移量 > 0 {
                        // 已展开时点击收起
                        withAnimation(.easeOut(duration: 0.2)) {
                            偏移量 = 0
                        }
                    } else {
                        选中节点()
                    }
                }
                // 长按上下文菜单（所有正常节点均启用，不移除无效节点前置判断但菜单内做校验）
                .contextMenu {
                    上下文菜单内容
                }

            // Toast 提示层
            if 显示Toast {
                Toast视图(消息: Toast消息)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(100)
            }
        }
        .frame(height: 60)
        .clipped()
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
    }

    // MARK: - 上下文菜单内容

    @ViewBuilder
    private var 上下文菜单内容: some View {
        // 节点测试
        Button {
            测速管理器.测速节点(节点) { _ in }
        } label: {
            Label("节点测试", systemImage: "gauge")
        }

        // 复制节点链接
        Button {
            复制节点链接()
        } label: {
            Label("复制节点链接", systemImage: "doc.on.doc")
        }

        // 编辑节点（所有正常节点均启用）
        Button {
            显示编辑节点 = true
        } label: {
            Label("编辑节点", systemImage: "pencil")
        }

        // 移动至其他分组
        Button {
            显示移动分组 = true
        } label: {
            Label("移动至其他分组", systemImage: "folder")
        }

        // 删除节点
        Button(role: .destructive) {
            显示删除确认 = true
        } label: {
            Label("删除节点", systemImage: "trash")
        }
    }

    /// 复制节点链接到剪贴板（生成完整标准节点分享链接）
    private func 复制节点链接() {
        let 链接 = 生成标准节点链接()
        UIPasteboard.general.string = 链接
        显示Toast消息("节点链接已复制")
    }

    /// 生成完整标准节点分享链接
    private func 生成标准节点链接() -> String {
        let 名称编码 = 节点.名称.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? 节点.名称

        switch 节点.协议 {
        case .vless:
            // vless://uuid@address:port?encryption=none&type=ws&path=...&host=...&security=tls&sni=...#name
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
            // vmess://base64(json)
            let vmess字典: [String: Any] = [
                "v": "2",
                "ps": 节点.名称,
                "add": 节点.地址,
                "port": "\(节点.端口)",
                "id": 节点.用户标识 ?? "",
                "aid": "0",
                "scy": "auto",
                "net": 节点.传输类型 == .ws ? "ws" : "tcp",
                "type": "none",
                "host": 节点.ws主机 ?? "",
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
            // trojan://password@address:port?type=ws&path=...&host=...&security=tls&sni=...#name
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
            // ss://base64(method:password)@address:port#name
            let 方法密码 = "\(节点.用户标识 ?? "")"
            let base64 = 方法密码.data(using: .utf8)?.base64EncodedString() ?? ""
            return "ss://\(base64)@\(节点.地址):\(节点.端口)#\(名称编码)"
        }
    }

    /// 显示 Toast 消息
    private func 显示Toast消息(_ 消息: String) {
        Toast消息 = 消息
        withAnimation(.easeInOut(duration: 0.2)) {
            显示Toast = true
        }
        // 2秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                显示Toast = false
            }
        }
    }

    /// 选中节点
    private func 选中节点() {
        withAnimation(.easeInOut(duration: 0.2)) {
            状态.保存选中节点(节点ID: 节点.id)
        }
        // VPN连接状态下实时切换节点：重新生成配置并通知扩展重载
        隧道管理.切换节点并重载(节点ID: 节点.id, 节点名称: 节点.名称)
    }
}

// MARK: - 节点卡片内容

/// 节点卡片内容
private struct 节点卡片内容: View {
    /// 节点数据
    let 节点: 节点模型
    /// 是否选中
    let 是否选中: Bool
    /// 测速管理器
    @EnvironmentObject private var 测速管理器: 测速管理器

    var body: some View {
        HStack(spacing: 10) {
            // 选中指示器
            if 是否选中 {
                Capsule()
                    .fill(Color.主题色)
                    .frame(width: 3, height: 28)
            }

            // 左侧：协议 + 节点名称(tag) + 地址/标签
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(节点.协议.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(是否选中 ? Color.主题色 : Color.主题色.opacity(0.7))
                        .cornerRadius(4)
                    Text(节点.名称)
                        .font(.system(size: 14, weight: 是否选中 ? .medium : .regular))
                        .lineLimit(1)
                }
                Text("\(节点.地址):\(节点.端口) · \(节点.标签.joined(separator: " · "))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧：选中标记 + 测速结果
            HStack(spacing: 8) {
                // 选中标记
                if 是否选中 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.主题色)
                }

                // 测速结果展示
                测速结果展示(节点ID: 节点.id)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 60)
        .background(是否选中 ? Color.主题色.opacity(0.12) : Color.卡片背景)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(是否选中 ? Color.主题色.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Toast 视图

/// 轻量 Toast 提示视图
private struct Toast视图: View {
    let 消息: String

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                Text(消息)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.75))
            .cornerRadius(20)
            .padding(.bottom, 20)
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

    // 输入字段
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

    // 校验错误
    @State private var 名称错误: String?
    @State private var 地址错误: String?
    @State private var 端口错误: String?
    @State private var UUID错误: String?

    // Toast
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

    /// 是否有修改
    private var 有修改: Bool {
        名称 != 节点.名称 ||
        地址 != 节点.地址 ||
        端口 != "\(节点.端口)" ||
        用户标识 != (节点.用户标识 ?? "") ||
        选中传输类型 != 节点.传输类型 ||
        启用TLS != 节点.启用TLS ||
        服务器名称 != (节点.服务器名称 ?? "") ||
        ws路径 != (节点.ws路径 ?? "") ||
        ws主机 != (节点.ws主机 ?? "") ||
        分组 != 节点.分组 ||
        备注 != (节点.备注 ?? "")
    }

    /// 是否需要UUID字段
    private var 需要UUID: Bool {
        节点.协议 == .vless || 节点.协议 == .vmess || 节点.协议 == .trojan
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // 基本信息模块
                    Section {
                        标签文本行(标签: "协议", 内容: 节点.协议.rawValue)
                        标签输入行(标签: "节点名称", 占位: "请输入节点名称", 文本: $名称, 错误: $名称错误)
                        标签输入行(标签: "地址", 占位: "域名/IP", 文本: $地址, 错误: $地址错误, 键盘类型: .URL)
                        标签输入行(标签: "端口", 占位: "1~65535", 文本: $端口, 错误: $端口错误, 键盘类型: .numberPad)
                        if 需要UUID {
                            标签输入行(标签: "UUID", 占位: 节点.协议 == .trojan ? "Trojan密码" : "VLESS UUID", 文本: $用户标识, 错误: $UUID错误)
                        }
                    } header: {
                        Text("基本信息")
                    }

                    // 传输设置模块
                    Section {
                        Picker("传输类型", selection: $选中传输类型) {
                            ForEach(传输类型.allCases, id: \.self) { 类型 in
                                Text(类型.rawValue).tag(类型)
                            }
                        }
                    } header: {
                        Text("传输设置")
                    }

                    // TLS 设置模块（仅启用TLS时显示）
                    if 启用TLS {
                        Section {
                            标签输入行(标签: "SNI", 占位: "TLS服务器名称", 文本: $服务器名称, 错误: .constant(nil), 键盘类型: .URL)
                        } header: {
                            Text("TLS 设置")
                        }
                    }

                    // WebSocket 设置模块（仅ws传输时显示）
                    if 选中传输类型 == .ws {
                        Section {
                            标签输入行(标签: "路径", 占位: "WebSocket路径，如 /ws", 文本: $ws路径, 错误: .constant(nil), 键盘类型: .URL)
                            标签输入行(标签: "Host", 占位: "WebSocket Host头", 文本: $ws主机, 错误: .constant(nil), 键盘类型: .URL)
                        } header: {
                            Text("WebSocket 设置")
                        }
                    }

                    // TLS 开关（独立模块）
                    Section {
                        Toggle("启用 TLS", isOn: $启用TLS)
                            .tint(.主题色)
                    } header: {
                        Text("安全设置")
                    }

                    // 分组与备注模块
                    Section {
                        标签输入行(标签: "分组", 占位: "分组名称", 文本: $分组, 错误: .constant(nil))
                        标签输入行(标签: "备注", 占位: "可选备注信息", 文本: $备注, 错误: .constant(nil))
                    } header: {
                        Text("分组与备注")
                    }
                }

                // Toast 层
                if 显示Toast {
                    Toast视图(消息: Toast消息, 成功: Toast成功)
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
                    Button("保存") {
                        保存节点()
                    }
                    .disabled(!有修改)
                }
            }
        }
    }

    // MARK: - 校验与保存

    /// 校验所有字段
    private func 校验字段() -> Bool {
        var 校验通过 = true

        // 名称校验
        if 名称.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            名称错误 = "节点名称不能为空"
            校验通过 = false
        } else {
            名称错误 = nil
        }

        // 地址校验
        if 地址.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            地址错误 = "地址不能为空"
            校验通过 = false
        } else {
            地址错误 = nil
        }

        // 端口校验
        if let 端口号 = Int(端口), 端口号 >= 1, 端口号 <= 65535 {
            端口错误 = nil
        } else {
            端口错误 = "端口必须为1~65535的数字"
            校验通过 = false
        }

        // UUID校验（仅需要时）
        if 需要UUID {
            if 节点.协议 == .vless || 节点.协议 == .vmess {
                // UUID格式校验：8-4-4-4-12
                let uuid正则 = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
                if 用户标识.range(of: uuid正则, options: .regularExpression) == nil {
                    UUID错误 = "UUID格式不正确"
                    校验通过 = false
                } else {
                    UUID错误 = nil
                }
            } else if 节点.协议 == .trojan {
                if 用户标识.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    UUID错误 = "密码不能为空"
                    校验通过 = false
                } else {
                    UUID错误 = nil
                }
            }
        }

        return 校验通过
    }

    /// 保存节点修改
    private func 保存节点() {
        // 先校验
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

        // 延迟关闭，让用户看到Toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            关闭()
        }
    }

    /// 显示 Toast 消息
    private func 显示Toast消息(_ 消息: String, 成功: Bool) {
        Toast消息 = 消息
        Toast成功 = 成功
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

// MARK: - 标签输入行组件

/// 标签+输入框成行组件（带错误提示）
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
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 6)

            // 错误提示
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

// MARK: - 标签文本行组件（只读）

private struct 标签文本行: View {
    let 标签: String
    let 内容: String

    var body: some View {
        HStack(spacing: 12) {
            Text(标签)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 70, alignment: .leading)
            Text(内容)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Toast 视图（带成功/失败样式）

private struct Toast视图: View {
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

/// 移动节点到其他分组页面
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

    /// 选择分组
    private func 选择分组(_ 分组名: String) {
        if 分组名 == 节点.分组 {
            显示错误("不能移动至当前分组")
            return
        }
        执行移动(目标分组: 分组名)
    }

    /// 执行移动
    private func 执行移动(目标分组: String) {
        状态.移动节点(节点.id, 到目标分组: 目标分组)
        关闭()
    }

    /// 显示错误提示
    private func 显示错误(_ 消息: String) {
        错误消息 = 消息
        显示错误提示 = true
    }
}

// MARK: - 预览

#Preview {
    节点内容区()
        .environmentObject(AppState.共享)
        .environmentObject(测速管理器.共享)
        .background(Color.页面背景)
}
