//
//  本地HTTP代理.swift
//  NewVPN-Tunnel
//
//  本地 HTTP 代理服务器，运行在 Network Extension 进程中
//  接收 MITM 解密后的 HTTP 流量，记录抓包信息后转发到目标服务器
//  第一期：记录方法/URL/状态码/耗时，Body 暂不记录
//

import Foundation
import Network

/// 本地 HTTP 代理服务器
final class 本地HTTP代理 {
    // MARK: - 单例

    /// 共享实例
    static let 共享 = 本地HTTP代理()

    // MARK: - 属性

    /// 网络监听器
    private var 监听器: NWListener?
    /// 监听端口
    private let 监听端口: UInt16 = 8888
    /// 是否运行中
    private(set) var 是否运行中 = false
    /// 活跃连接数组
    private var 活跃连接: [NWConnection] = []
    /// 连接队列
    private let 连接队列 = DispatchQueue(label: "com.newvpn.capture.proxy")
    /// URLSession（转发请求用）
    private lazy var 转发会话: URLSession = {
        let 配置 = URLSessionConfiguration.ephemeral
        配置.timeoutIntervalForRequest = 30
        配置.timeoutIntervalForResource = 60
        配置.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: 配置)
    }()

    // MARK: - 初始化

    private init() {}

    // MARK: - 启动/停止

    /// 启动代理服务器
    func 启动() {
        guard !是否运行中 else { return }

        let 参数 = NWParameters.tcp
        参数.allowLocalEndpointReuse = true

        do {
            监听器 = try NWListener(using: 参数, on: NWEndpoint.Port(integerLiteral: 监听端口))
        } catch {
            NSLog("[抓包代理] 创建监听器失败：\(error.localizedDescription)")
            return
        }

        监听器?.stateUpdateHandler = { [weak self] 状态 in
            switch 状态 {
            case .ready:
                self?.是否运行中 = true
                NSLog("[抓包代理] 已启动，监听 127.0.0.1:\(self?.监听端口 ?? 0)")
            case .failed(let 错误):
                NSLog("[抓包代理] 监听器失败：\(错误.localizedDescription)")
                self?.是否运行中 = false
            case .cancelled:
                self?.是否运行中 = false
            default:
                break
            }
        }

        监听器?.newConnectionHandler = { [weak self] 连接 in
            self?.处理新连接(连接)
        }

        监听器?.start(queue: 连接队列)
    }

    /// 停止代理服务器
    func 停止() {
        监听器?.cancel()
        监听器 = nil
        是否运行中 = false
        // 取消所有活跃连接
        连接队列.async {
            self.活跃连接.forEach { $0.cancel() }
            self.活跃连接.removeAll()
        }
        NSLog("[抓包代理] 已停止")
    }

    // MARK: - 连接处理

    /// 处理新连接
    private func 处理新连接(_ 连接: NWConnection) {
        活跃连接.append(连接)
        连接.start(queue: 连接队列)

        // 读取 HTTP 请求
        读取请求(连接) { [weak self] 请求 in
            guard let self = self, let 请求 = 请求 else {
                self?.关闭连接(连接)
                return
            }
            self.转发请求(请求, 原始连接: 连接)
        }
    }

    /// 读取 HTTP 请求
    private func 读取请求(_ 连接: NWConnection, 完成: @escaping (HTTP请求?) -> Void) {
        连接.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] 数据, _, 是否完成, 错误 in
            if let 错误 = 错误 {
                NSLog("[抓包代理] 读取请求失败：\(错误.localizedDescription)")
                完成(nil)
                return
            }

            guard let 数据 = 数据, !数据.isEmpty else {
                完成(nil)
                return
            }

            // 解析 HTTP 请求
            if let 请求 = self?.解析HTTP请求(数据) {
                完成(请求)
            } else {
                完成(nil)
            }
        }
    }

    /// Body 最大记录大小（1MB），超过则截断
    private let 最大Body大小 = 1024 * 1024

    /// 解析 HTTP 请求数据（正确分离头部和 Body，支持二进制 Body）
    private func 解析HTTP请求(_ 数据: Data) -> HTTP请求? {
        // 查找头部和 Body 的分隔符 \r\n\r\n
        guard let 分隔符范围 = 数据.range(of: Data("\r\n\r\n".utf8)) else {
            // 没有找到分隔符，可能数据不完整
            return nil
        }

        // 分离头部和 Body
        let 头部数据 = 数据.prefix(upTo: 分隔符范围.lowerBound)
        var Body数据 = 数据.suffix(from: 分隔符范围.upperBound)

        // 解析头部文本
        guard let 头部文本 = String(data: 头部数据, encoding: .utf8) else { return nil }
        let 行数组 = 头部文本.components(separatedBy: "\r\n")
        guard !行数组.isEmpty else { return nil }

        // 解析请求行：METHOD PATH HTTP/1.1
        let 请求行 = 行数组[0]
        let 请求行部分 = 请求行.components(separatedBy: " ")
        guard 请求行部分.count >= 2 else { return nil }

        let 方法 = 请求行部分[0]
        let 路径 = 请求行部分[1]

        // 解析请求头
        var 头字典: [String: String] = [:]
        var 头列表: [请求头项] = []

        for i in 1..<行数组.count {
            let 行 = 行数组[i]
            if 行.isEmpty { continue }
            if let 冒号位置 = 行.firstIndex(of: ":") {
                let 名称 = String(行[..<冒号位置]).trimmingCharacters(in: .whitespaces)
                let 值 = String(行[行.index(after: 冒号位置)...]).trimmingCharacters(in: .whitespaces)
                头字典[名称.lowercased()] = 值
                头列表.append(请求头项(名称: 名称, 值: 值))
            }
        }

        // 从 Host 头获取主机和端口
        let 主机 = 头字典["host"] ?? ""
        var 端口: Int = 80
        var 主机名 = 主机
        if let 冒号位置 = 主机.firstIndex(of: ":") {
            主机名 = String(主机[..<冒号位置])
            if let p = Int(主机[主机.index(after: 冒号位置)...]) {
                端口 = p
            }
        }

        // 构造完整 URL
        let 完整URL = "http://\(主机)\(路径)"

        // Body 大小限制：超过 1MB 截断
        let 原始Body大小 = Body数据.count
        if Body数据.count > 最大Body大小 {
            Body数据 = Body数据.prefix(最大Body大小)
        }

        return HTTP请求(
            方法: 方法,
            完整URL: 完整URL,
            主机: 主机名,
            路径: 路径,
            端口: 端口,
            请求头: 头列表,
            头字典: 头字典,
            Body: Body数据,
            原始Body大小: 原始Body大小,
            Body已截断: 原始Body大小 > 最大Body大小,
            原始数据: 数据
        )
    }

    /// 转发请求到目标服务器
    private func 转发请求(_ 请求: HTTP请求, 原始连接: NWConnection) {
        let 开始时间 = Date()

        // 创建抓包记录
        var 记录 = 抓包记录(
            请求方法: 请求.方法,
            请求URL: 请求.完整URL,
            请求主机: 请求.主机,
            请求路径: 请求.路径,
            请求端口: 请求.端口,
            是否HTTPS: false  // MITM 解密后已是 HTTP
        )
        记录.请求头 = 请求.请求头
        记录.请求Body大小 = 请求.原始Body大小
        记录.请求Body类型 = 推断Body类型(请求.头字典["content-type"])
        // 记录文本类型 Body 内容（限 64KB）
        if 请求.原始Body大小 <= 65536,
           let body文本 = String(data: 请求.Body, encoding: .utf8),
           !body文本.isEmpty {
            记录.请求Body内容 = body文本
            记录.请求Body已截断 = 请求.Body已截断
        }
        抓包存储管理器.共享.添加记录(记录)

        // 构造 URLRequest
        guard let url = URL(string: 请求.完整URL) else {
            记录.错误信息 = "无效的 URL"
            记录.结束时间 = Date()
            记录.耗时毫秒 = Int(Date().timeIntervalSince(开始时间) * 1000)
            抓包存储管理器.共享.更新记录(记录)
            关闭连接(原始连接)
            return
        }

        var 请求对象 = URLRequest(url: url)
        请求对象.httpMethod = 请求.方法
        // 复制请求头（跳过 hop-by-hop 头）
        let 跳过头 = ["host", "connection", "proxy-connection", "keep-alive", "transfer-encoding", "upgrade"]
        for 头 in 请求.请求头 {
            if !跳过头.contains(头.名称.lowercased()) {
                请求对象.setValue(头.值, forHTTPHeaderField: 头.名称)
            }
        }
        if !请求.Body.isEmpty {
            请求对象.httpBody = 请求.Body
        }

        // 发送请求
        let 任务 = 转发会话.dataTask(with: 请求对象) { [weak self] 数据, 响应, 错误 in
            guard let self = self else { return }

            var 结束记录 = 记录
            结束记录.结束时间 = Date()
            结束记录.耗时毫秒 = Int(Date().timeIntervalSince(开始时间) * 1000)

            if let 错误 = 错误 {
                结束记录.错误信息 = 错误.localizedDescription
                抓包存储管理器.共享.更新记录(结束记录)
                self.发送错误响应(原始连接, 错误: 错误)
                self.关闭连接(原始连接)
                return
            }

            guard let http响应 = 响应 as? HTTPURLResponse else {
                结束记录.错误信息 = "无效的响应"
                抓包存储管理器.共享.更新记录(结束记录)
                self.关闭连接(原始连接)
                return
            }

            // 记录响应信息
            结束记录.响应状态码 = http响应.statusCode
            结束记录.响应状态文本 = HTTPURLResponse.localizedString(forStatusCode: http响应.statusCode)
            var 响应头列表: [请求头项] = []
            for (名称, 值) in http响应.allHeaderFields {
                if let 名字 = 名称 as? String, let 数值 = 值 as? String {
                    响应头列表.append(请求头项(名称: 名字, 值: 数值))
                }
            }
            结束记录.响应头 = 响应头列表
            结束记录.响应Body大小 = 数据?.count ?? 0
            结束记录.响应Body类型 = self.推断Body类型(http响应.allHeaderFields["Content-Type"] as? String)
            // 记录文本类型响应 Body 内容（限 64KB）
            if let 响应数据 = 数据, 响应数据.count <= 65536,
               let body文本 = String(data: 响应数据, encoding: .utf8),
               !body文本.isEmpty {
                结束记录.响应Body内容 = body文本
                结束记录.响应Body已截断 = false
            } else if let 响应数据 = 数据, 响应数据.count > 65536 {
                // 超过 64KB，截断记录
                let 截断数据 = 响应数据.prefix(65536)
                if let body文本 = String(data: 截断数据, encoding: .utf8) {
                    结束记录.响应Body内容 = body文本
                    结束记录.响应Body已截断 = true
                }
            }
            抓包存储管理器.共享.更新记录(结束记录)

            // 将响应写回客户端
            self.发送响应(原始连接, 响应: http响应, 响应数据: 数据 ?? Data())
        }
        任务.resume()
    }

    /// 发送 HTTP 响应到客户端
    private func 发送响应(_ 连接: NWConnection, 响应: HTTPURLResponse, 响应数据: Data) {
        var 响应文本 = "HTTP/1.1 \(响应.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: 响应.statusCode))\r\n"
        // 复制响应头（跳过 transfer-encoding，改用 Content-Length）
        let 跳过头 = ["transfer-encoding", "connection", "keep-alive"]
        for (名称, 值) in 响应.allHeaderFields {
            if let 名字 = 名称 as? String, let 数值 = 值 as? String,
               !跳过头.contains(名字.lowercased()) {
                响应文本 += "\(名字): \(数值)\r\n"
            }
        }
        响应文本 += "Content-Length: \(响应数据.count)\r\n"
        响应文本 += "Connection: close\r\n"
        响应文本 += "\r\n"

        var 完整数据 = 响应文本.data(using: .utf8) ?? Data()
        完整数据.append(响应数据)

        连接.send(content: 完整数据, completion: .contentProcessed { [weak self] _ in
            self?.关闭连接(连接)
        })
    }

    /// 发送错误响应
    private func 发送错误响应(_ 连接: NWConnection, 错误: Error) {
        let 响应文本 = "HTTP/1.1 502 Bad Gateway\r\nContent-Type: text/plain\r\nContent-Length: \(错误.localizedDescription.count)\r\nConnection: close\r\n\r\n\(错误.localizedDescription)"
        if let 数据 = 响应文本.data(using: .utf8) {
            连接.send(content: 数据, completion: .idempotent)
        }
    }

    /// 关闭连接
    private func 关闭连接(_ 连接: NWConnection) {
        连接.cancel()
        if let 索引 = 活跃连接.firstIndex(where: { $0 === 连接 }) {
            活跃连接.remove(at: 索引)
        }
    }

    /// 推断 Body 类型
    private func 推断Body类型(_ contentType: String?) -> String {
        guard let type = contentType?.lowercased() else { return "binary" }
        if type.contains("json") { return "json" }
        if type.contains("xml") { return "xml" }
        if type.contains("html") { return "html" }
        if type.contains("text") { return "text" }
        if type.contains("form-urlencoded") { return "form" }
        if type.contains("multipart") { return "multipart" }
        if type.contains("image") { return "image" }
        if type.contains("video") { return "video" }
        if type.contains("audio") { return "audio" }
        return "binary"
    }
}

// MARK: - HTTP 请求数据结构

/// 解析后的 HTTP 请求
private struct HTTP请求 {
    let 方法: String
    let 完整URL: String
    let 主机: String
    let 路径: String
    let 端口: Int
    let 请求头: [请求头项]
    let 头字典: [String: String]
    let Body: Data
    let 原始Body大小: Int
    let Body已截断: Bool
    let 原始数据: Data
}
