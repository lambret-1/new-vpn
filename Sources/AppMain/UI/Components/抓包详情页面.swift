//
//  抓包详情页面.swift
//  NewVPN
//
//  HTTP 抓包记录详情页，展示请求/响应完整信息
//  第三期：请求/响应 Tab、Headers 展示、Body 多格式查看、cURL 导出
//

import SwiftUI

/// HTTP 抓包记录详情页面
struct 抓包详情页面: View {
    /// 抓包记录
    let 记录: 抓包记录

    /// 当前选中的 Tab
    @State private var 当前Tab = 0
    /// Body 显示格式
    @State private var 请求Body格式 = Body格式.自动
    @State private var 响应Body格式 = Body格式.自动
    /// 复制提示
    @State private var 显示复制提示 = false
    /// 重放状态
    @State private var 正在重放 = false
    /// 重放结果
    @State private var 重放结果: 重放结果信息?
    /// 显示编辑重放
    @State private var 显示编辑重放 = false
    /// 编辑后的 URL
    @State private var 编辑URL = ""
    /// 显示分享面板
    @State private var 显示分享 = false
    /// 分享文件 URL
    @State private var 分享文件URL: URL?

    /// 导出格式
    enum 导出格式 {
        case json, har
    }

    /// 重放结果数据结构
    struct 重放结果信息 {
        let 状态码: Int
        let 耗时毫秒: Int
        let 响应大小: Int
        let 错误信息: String?
    }

    /// Body 显示格式枚举
    enum Body格式: String, CaseIterable {
        case 自动 = "自动"
        case 原始 = "原始"
        case 格式化 = "格式化"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部信息栏
                顶部信息栏

                // 重放操作栏
                重放操作栏

                // 时间线
                时间线视图

                // Tab 切换
                Picker("", selection: $当前Tab) {
                    Text("请求").tag(0)
                    Text("响应").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                // Tab 内容
                if 当前Tab == 0 {
                    请求内容
                } else {
                    响应内容
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color.页面背景.ignoresSafeArea())
        .navigationTitle("抓包详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = 记录.cURL命令
                        显示复制提示 = true
                    } label: {
                        Label("复制 cURL", systemImage: "terminal")
                    }
                    Button {
                        UIPasteboard.general.string = 记录.请求URL
                        显示复制提示 = true
                    } label: {
                        Label("复制 URL", systemImage: "link")
                    }
                    Divider()
                    Button {
                        导出单条记录(格式: .json)
                    } label: {
                        Label("导出为 JSON", systemImage: "doc.text")
                    }
                    Button {
                        导出单条记录(格式: .har)
                    } label: {
                        Label("导出为 HAR", systemImage: "doc.zipper")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
                }
            }
        }
        .alert("已复制", isPresented: $显示复制提示) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("内容已复制到剪贴板")
        }
        .sheet(isPresented: $显示分享) {
            if let 文件URL = 分享文件URL {
                分享视图(活动项: [文件URL])
            }
        }
    }

    // MARK: - 顶部信息栏

    private var 顶部信息栏: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // 方法标签
                Text(记录.请求方法.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(方法颜色)
                    .cornerRadius(4)

                // 状态码
                if let 状态码 = 记录.响应状态码 {
                    Text("\(状态码)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(状态码颜色(状态码))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(状态码颜色(状态码).opacity(0.1))
                        .cornerRadius(4)
                } else if 记录.错误信息 != nil {
                    Text("失败")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                // 耗时
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(记录.耗时显示)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
            }

            // URL
            Text(记录.请求URL)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(3)
                .textSelection(.enabled)

            // 时间
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                Text(记录.开始时间.格式化显示)
                    .font(.system(size: 11))
                Spacer()
                if 记录.是否HTTPS {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text("HTTPS")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "lock.open")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("HTTP")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.卡片背景)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - 重放操作栏

    private var 重放操作栏: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // 直接重放按钮
                Button {
                    执行重放(编辑: false)
                } label: {
                    HStack(spacing: 4) {
                        if 正在重放 {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("重放")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(正在重放 ? Color.gray : Color.blue)
                    .cornerRadius(8)
                }
                .disabled(正在重放)

                // 编辑重放按钮
                Button {
                    编辑URL = 记录.请求URL
                    显示编辑重放 = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                        Text("编辑重放")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.卡片背景)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(正在重放)
            }

            // 重放结果
            if let 结果 = 重放结果 {
                HStack(spacing: 12) {
                    if let 错误 = 结果.错误信息 {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("重放失败: \(错误)")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("状态码: \(结果.状态码)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                        Text("耗时: \(结果.耗时毫秒)ms")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("大小: \(字节格式化(结果.响应大小))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.卡片背景)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $显示编辑重放) {
            编辑重放页面(原始URL: 记录.请求URL, 原始方法: 记录.请求方法) { 新URL in
                编辑URL = 新URL
                执行重放(编辑: true)
            }
        }
    }

    /// 执行重放
    private func 执行重放(编辑: Bool) {
        正在重放 = true
        重放结果 = nil

        let 目标URL = 编辑 ? 编辑URL : 记录.请求URL
        guard let url = URL(string: 目标URL) else {
            重放结果 = 重放结果信息(状态码: 0, 耗时毫秒: 0, 响应大小: 0, 错误信息: "无效的 URL")
            正在重放 = false
            return
        }

        let 开始时间 = Date()
        var 请求 = URLRequest(url: url)
        请求.httpMethod = 记录.请求方法

        // 复制请求头
        for 头 in 记录.请求头 {
            let 跳过头 = ["host", "connection", "content-length"]
            if !跳过头.contains(头.名称.lowercased()) {
                请求.setValue(头.值, forHTTPHeaderField: 头.名称)
            }
        }

        // 复制请求 Body
        if let body = 记录.请求Body内容, let body数据 = body.data(using: .utf8) {
            请求.httpBody = body数据
        }

        URLSession.shared.dataTask(with: 请求) { 数据, 响应, 错误 in
            DispatchQueue.main.async {
                正在重放 = false
                let 耗时 = Int(Date().timeIntervalSince(开始时间) * 1000)

                if let 错误 = 错误 {
                    重放结果 = 重放结果信息(状态码: 0, 耗时毫秒: 耗时, 响应大小: 0, 错误信息: 错误.localizedDescription)
                } else if let http响应 = 响应 as? HTTPURLResponse {
                    重放结果 = 重放结果信息(
                        状态码: http响应.statusCode,
                        耗时毫秒: 耗时,
                        响应大小: 数据?.count ?? 0,
                        错误信息: nil
                    )
                }
            }
        }.resume()
    }

    /// 字节格式化
    private func 字节格式化(_ 字节数: Int) -> String {
        if 字节数 < 1024 {
            return "\(字节数)B"
        } else if 字节数 < 1024 * 1024 {
            return String(format: "%.1fKB", Double(字节数) / 1024.0)
        } else {
            return String(format: "%.2fMB", Double(字节数) / (1024.0 * 1024.0))
        }
    }

    // MARK: - 时间线视图

    private var 时间线视图: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("请求时间线")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            if let 耗时 = 记录.耗时毫秒 {
                // 简化时间线：请求发送 / 服务器处理 / 响应接收
                let 发送占比 = 0.1
                let 处理占比 = 0.7
                let 接收占比 = 0.2

                VStack(spacing: 6) {
                    // 进度条
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(height: 8)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(Color.orange)
                            .frame(height: 8)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(Color.green)
                            .frame(height: 8)
                            .frame(maxWidth: .infinity)
                    }
                    .cornerRadius(4)

                    // 时间标签
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("请求发送")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                            Text("\(Int(Double(耗时) * 发送占比))ms")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .center, spacing: 2) {
                            Text("服务器处理")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text("\(Int(Double(耗时) * 处理占比))ms")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("响应接收")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                            Text("\(Int(Double(耗时) * 接收占比))ms")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("请求进行中，暂无时间线数据")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.卡片背景)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - 导出单条记录

    private func 导出单条记录(格式: 导出格式) {
        let 内容: String
        let 文件扩展名: String

        switch 格式 {
        case .json:
            // 导出为 JSON 格式
            let 字典: [String: Any] = [
                "request": [
                    "method": 记录.请求方法,
                    "url": 记录.请求URL,
                    "headers": 记录.请求头.map { ["name": $0.名称, "value": $0.值] },
                    "bodySize": 记录.请求Body大小,
                    "body": 记录.请求Body内容 ?? ""
                ],
                "response": [
                    "status": 记录.响应状态码 ?? 0,
                    "statusText": 记录.响应状态文本 ?? "",
                    "headers": (记录.响应头 ?? []).map { ["name": $0.名称, "value": $0.值] },
                    "bodySize": 记录.响应Body大小 ?? 0,
                    "body": 记录.响应Body内容 ?? ""
                ],
                "timing": [
                    "started": 记录.开始时间.timeIntervalSince1970,
                    "durationMs": 记录.耗时毫秒 ?? 0
                ]
            ]
            if let 数据 = try? JSONSerialization.data(withJSONObject: 字典, options: [.prettyPrinted]),
               let 字符串 = String(data: 数据, encoding: .utf8) {
                内容 = 字符串
            } else {
                内容 = "{}"
            }
            文件扩展名 = "json"
        case .har:
            内容 = 抓包记录.导出HAR([记录])
            文件扩展名 = "har"
        }

        // 写入临时文件
        let 日期格式化器 = DateFormatter()
        日期格式化器.dateFormat = "yyyyMMdd_HHmmss"
        let 文件名 = "capture_\(日期格式化器.string(from: Date())).\(文件扩展名)"
        let 临时目录 = FileManager.default.temporaryDirectory
        let 文件URL = 临时目录.appendingPathComponent(文件名)

        do {
            try 内容.write(to: 文件URL, atomically: true, encoding: .utf8)
            分享文件URL = 文件URL
            显示分享 = true
        } catch {
            NSLog("[抓包] 导出失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 请求内容

    private var 请求内容: some View {
        VStack(spacing: 12) {
            // 请求行
            信息卡片(标题: "请求行") {
                Text("\(记录.请求方法.uppercased()) \(记录.请求路径) HTTP/1.1")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }

            // 请求头
            信息卡片(标题: "请求头 (\(记录.请求头.count))") {
                if 记录.请求头.isEmpty {
                    空文本("无请求头")
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(记录.请求头) { 头 in
                            HStack(alignment: .top) {
                                Text(头.名称)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .frame(width: 120, alignment: .leading)
                                Text(头.值)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                Spacer()
                            }
                        }
                    }
                }
            }

            // 请求 Body
            信息卡片(标题: "请求 Body (\(记录.请求大小显示))") {
                if 记录.请求Body大小 == 0 {
                    空文本("无请求 Body")
                } else if let body = 记录.请求Body内容 {
                    VStack(spacing: 8) {
                        // 格式切换
                        HStack {
                            Text("类型: \(记录.请求Body类型 ?? "unknown")")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $请求Body格式) {
                                ForEach(Body格式.allCases, id: \.self) { 格式 in
                                    Text(格式.rawValue).tag(格式)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        // Body 内容
                        ScrollView(.horizontal) {
                            Text(格式化Body(body, 格式: 请求Body格式))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                        if 记录.请求Body已截断 {
                            Text("[内容已截断，仅显示前 64KB]")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    空文本("Body 为二进制数据，无法显示文本内容")
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 响应内容

    private var 响应内容: some View {
        VStack(spacing: 12) {
            // 响应行
            信息卡片(标题: "响应行") {
                if let 状态码 = 记录.响应状态码 {
                    Text("HTTP/1.1 \(状态码) \(记录.响应状态文本 ?? "")")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                } else if let 错误 = 记录.错误信息 {
                    Text("请求失败: \(错误)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                } else {
                    空文本("等待响应...")
                }
            }

            // 响应头
            信息卡片(标题: "响应头 (\(记录.响应头?.count ?? 0))") {
                if let 响应头 = 记录.响应头, !响应头.isEmpty {
                    LazyVStack(spacing: 6) {
                        ForEach(响应头) { 头 in
                            HStack(alignment: .top) {
                                Text(头.名称)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.purple)
                                    .frame(width: 120, alignment: .leading)
                                Text(头.值)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                Spacer()
                            }
                        }
                    }
                } else {
                    空文本("无响应头")
                }
            }

            // 响应 Body
            信息卡片(标题: "响应 Body (\(记录.响应大小显示))") {
                if (记录.响应Body大小 ?? 0) == 0 {
                    空文本("无响应 Body")
                } else if let body = 记录.响应Body内容 {
                    VStack(spacing: 8) {
                        HStack {
                            Text("类型: \(记录.响应Body类型 ?? "unknown")")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $响应Body格式) {
                                ForEach(Body格式.allCases, id: \.self) { 格式 in
                                    Text(格式.rawValue).tag(格式)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        ScrollView(.horizontal) {
                            Text(格式化Body(body, 格式: 响应Body格式))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                        if 记录.响应Body已截断 {
                            Text("[内容已截断，仅显示前 64KB]")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    空文本("Body 为二进制数据，无法显示文本内容")
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 辅助视图

    private func 信息卡片<内容: View>(标题: String, @ViewBuilder 内容: () -> 内容) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(标题)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            内容()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.卡片背景)
        .cornerRadius(12)
    }

    private func 空文本(_ 文本: String) -> some View {
        Text(文本)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    // MARK: - 辅助方法

    private var 方法颜色: Color {
        switch 记录.请求方法.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        case "PATCH": return .purple
        default: return .gray
        }
    }

    private func 状态码颜色(_ 码: Int) -> Color {
        switch 码 {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .gray
        }
    }

    /// 格式化 Body 内容
    private func 格式化Body(_ 内容: String, 格式: Body格式) -> String {
        switch 格式 {
        case .原始:
            return 内容
        case .自动:
            // 自动检测 JSON 并格式化
            if 内容.hasPrefix("{") || 内容.hasPrefix("[") {
                return 格式化JSON(内容) ?? 内容
            }
            return 内容
        case .格式化:
            return 格式化JSON(内容) ?? 内容
        }
    }

    /// 格式化 JSON 字符串
    private func 格式化JSON(_ 字符串: String) -> String? {
        guard let 数据 = 字符串.data(using: .utf8),
              let 对象 = try? JSONSerialization.jsonObject(with: 数据),
              let 格式化数据 = try? JSONSerialization.data(withJSONObject: 对象, options: [.prettyPrinted]),
              let 格式化字符串 = String(data: 格式化数据, encoding: .utf8) else {
            return nil
        }
        return 格式化字符串
    }
}

// MARK: - Date 扩展

private extension Date {
    /// 格式化显示
    var 格式化显示: String {
        let 格式化器 = DateFormatter()
        格式化器.dateFormat = "yyyy-MM-dd HH:mm:ss"
        格式化器.locale = Locale(identifier: "zh_CN")
        return 格式化器.string(from: self)
    }
}

// MARK: - 分享视图

/// UIActivityViewController 包装
private struct 分享视图: UIViewControllerRepresentable {
    let 活动项: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: 活动项, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 编辑重放页面

/// 编辑重放页面
private struct 编辑重放页面: View {
    /// 原始 URL
    let 原始URL: String
    /// 原始方法
    let 原始方法: String
    /// 确认回调
    var 确认回调: (String) -> Void

    /// 编辑后的 URL
    @State private var 编辑URL: String
    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    init(原始URL: String, 原始方法: String, 确认回调: @escaping (String) -> Void) {
        self.原始URL = 原始URL
        self.原始方法 = 原始方法
        self.确认回调 = 确认回调
        self._编辑URL = State(initialValue: 原始URL)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("请求方法") {
                    Text(原始方法.uppercased())
                        .foregroundColor(.secondary)
                }

                Section("请求 URL") {
                    TextField("请求 URL", text: $编辑URL, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 14, design: .monospaced))
                }

                Section {
                    Button(role: .destructive) {
                        编辑URL = 原始URL
                    } label: {
                        Text("恢复原始 URL")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("编辑重放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("发送") {
                        确认回调(编辑URL)
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .disabled(编辑URL.isEmpty)
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        抓包详情页面(记录: 抓包记录(
            请求方法: "GET",
            请求URL: "https://api.example.com/v1/users?page=1",
            请求主机: "api.example.com",
            请求路径: "/v1/users?page=1",
            请求端口: 443,
            是否HTTPS: true
        ))
    }
}
