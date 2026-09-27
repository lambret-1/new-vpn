//
//  MITM连接处理器.swift
//  NewVPN-Tunnel
//
//  MITM 连接处理器：对单个 HTTPS 连接进行 TLS 终结，解密 HTTP 流量后转发
// 一期：SecureTransport 服务端 TLS 终结 + URLSession 转发 + 抓包记录
//

import Foundation
import Network
import Security

/// MITM 连接处理器
final class MITM连接处理器 {
    // MARK: - 属性

    /// 客户端连接（TCP，已接收 CONNECT 请求）
    private let 客户端连接: NWConnection
    /// 目标域名
    private let 目标域名: String
    /// 目标端口
    private let 目标端口: Int
    /// 处理队列
    private let 处理队列: DispatchQueue
    /// SSL 上下文（服务端）
    private var ssl上下文: SSLContext?
    /// 待发送给客户端的加密数据缓冲区
    private var 发送缓冲区 = Data()
    /// 从客户端读取的加密数据缓冲区
    private var 接收缓冲区 = Data()
    /// 是否已完成 TLS 握手
    private var 握手完成 = false
    /// URLSession（转发请求用）
    private let 转发会话: URLSession
    /// 完成回调
    private var 完成回调: (() -> Void)?

    // MARK: - 初始化

    /// 初始化
    /// - Parameters:
    ///   - 连接: 客户端连接（已接收 CONNECT 请求，未响应）
    ///   - 域名: 目标域名
    ///   - 端口: 目标端口
    ///   - 队列: 处理队列
    ///   - 会话: URLSession
    init(连接: NWConnection, 域名: String, 端口: Int, 队列: DispatchQueue, 会话: URLSession) {
        self.客户端连接 = 连接
        self.目标域名 = 域名
        self.目标端口 = 端口
        self.处理队列 = 队列
        self.转发会话 = 会话
    }

    // MARK: - 开始处理

    /// 开始处理：响应 CONNECT → TLS 握手 → 解密转发
    func 开始处理(完成: @escaping () -> Void) {
        self.完成回调 = 完成

        // 1. 响应 200 Connection Established
        let 响应 = "HTTP/1.1 200 Connection Established\r\n\r\n"
        guard let 响应数据 = 响应.data(using: .utf8) else {
            完成()
            return
        }

        客户端连接.send(content: 响应数据, completion: .contentProcessed { [weak self] _ in
            guard let self = self else { return }
            // 2. 初始化 SSL 服务端上下文
            self.初始化SSL服务端()
            // 3. 开始读取客户端数据并进行 TLS 握手
            self.读取客户端数据()
        })
    }

    // MARK: - SSL 服务端初始化

    /// 初始化 SSL 服务端上下文
    private func 初始化SSL服务端() {
        // 创建 SSL 上下文（服务端，流式，无侧）
        guard let 上下文 = SSLCreateContext(kCFAllocatorDefault, .serverSide, .streamType) else {
            扩展日志记录器.共享.错误("MITM", "创建 SSL 上下文失败")
            return
        }
        self.ssl上下文 = 上下文

        // 设置读写回调
        SSLSetIOFuncs(上下文, { 连接, 数据, 长度 in
            // 读取回调：从底层连接读取加密数据到 SSL 引擎
            let 处理器 = Unmanaged<MITM连接处理器>.fromOpaque(连接).takeUnretainedValue()
            return 处理器.ssl读取回调(数据: 数据, 长度: 长度)
        }, { 连接, 数据, 长度 in
            // 写入回调：SSL 引擎将加密数据写入底层连接
            let 处理器 = Unmanaged<MITM连接处理器>.fromOpaque(连接).takeUnretainedValue()
            return 处理器.ssl写入回调(数据: 数据, 长度: 长度)
        })

        // 设置连接引用（传递 self 指针给回调）
        SSLSetConnection(上下文, Unmanaged.passUnretained(self).toOpaque())

        // 设置证书和私钥（含完整证书链：服务器身份 + CA 证书）
        if let 身份 = MITM证书签发器.共享.获取服务器身份(域名: 目标域名) {
            // SSLSetCertificate 接受 CFArray，第一个元素是 SecIdentity，后面是证书链
            var 证书数组: [AnyObject] = [身份]
            if let ca证书 = MITM证书签发器.共享.获取CA证书() {
                证书数组.append(ca证书)
            }
            let 设置状态 = SSLSetCertificate(上下文, 证书数组 as CFArray)
            if 设置状态 != errSecSuccess {
                扩展日志记录器.共享.错误("MITM", "SSLSetCertificate 失败：\(设置状态) (\(目标域名))")
            }
        } else {
            扩展日志记录器.共享.错误("MITM", "获取服务器身份失败：\(目标域名)")
        }

        // 允许 TLS 1.0 到 1.3（兼容旧客户端）
        SSLSetProtocolVersionMin(上下文, .tlsProtocol1)
        SSLSetProtocolVersionMax(上下文, .tlsProtocol13)

        // 允许断点续连（false = 不允许，每次完整握手）
        SSLSetSessionOption(上下文, .breakOnClientAuth, false)
    }

    // MARK: - SSL IO 回调

    /// SSL 读取回调：从接收缓冲区读取数据给 SSL 引擎
    /// 注意：此回调在 SSLHandshake/SSLRead 调用栈中同步执行，不能再用队列同步，否则死锁
    private func ssl读取回调(数据: UnsafeMutableRawPointer, 长度: UnsafeMutablePointer<Int>) -> OSStatus {
        if 接收缓冲区.isEmpty {
            长度.pointee = 0
            return errSSLWouldBlock
        }
        let 可读取 = min(长度.pointee, 接收缓冲区.count)
        接收缓冲区.copyBytes(to: 数据.assumingMemoryBound(to: UInt8.self), count: 可读取)
        接收缓冲区.removeFirst(可读取)
        长度.pointee = 可读取
        return errSecSuccess
    }

    /// SSL 写入回调：SSL 引擎输出的加密数据放入发送缓冲区
    private func ssl写入回调(数据: UnsafeRawPointer, 长度: UnsafeMutablePointer<Int>) -> OSStatus {
        let 字节 = 数据.assumingMemoryBound(to: UInt8.self)
        发送缓冲区.append(字节, count: 长度.pointee)
        return errSecSuccess
    }

    // MARK: - 读取客户端数据

    /// 从客户端连接读取加密数据
    private func 读取客户端数据() {
        客户端连接.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] 数据, _, _, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                扩展日志记录器.共享.调试("MITM", "读取客户端数据失败：\(错误.localizedDescription)")
                self.清理并完成()
                return
            }

            guard let 数据 = 数据, !数据.isEmpty else {
                // 客户端关闭连接
                self.清理并完成()
                return
            }

            // 将加密数据放入接收缓冲区
            self.处理队列.async {
                self.接收缓冲区.append(数据)
                self.处理SSL数据()
            }
        }
    }

    /// 处理 SSL 数据：握手或解密应用数据
    private func 处理SSL数据() {
        guard let 上下文 = ssl上下文 else { return }

        if !握手完成 {
            // 进行 TLS 握手
            let 状态 = SSLHandshake(上下文)
            // 先将发送缓冲区中的数据（ServerHello、证书等）发送给客户端
            刷新发送缓冲区()

            switch 状态 {
            case errSecSuccess:
                握手完成 = true
                扩展日志记录器.共享.信息("MITM", "TLS 握手完成：\(目标域名)")
                // 握手完成后，读取解密后的应用数据
                读取解密数据()
            case errSSLWouldBlock:
                // 需要更多数据，继续读取客户端
                读取客户端数据()
            default:
                扩展日志记录器.共享.错误("MITM", "TLS 握手失败：\(状态) (\(目标域名)) - \(描述SSL错误(状态))")
                清理并完成()
            }
        } else {
            // 已握手完成，读取解密后的应用数据
            读取解密数据()
        }
    }

    /// 描述 SSL 错误码
    private func 描述SSL错误(_ 状态: OSStatus) -> String {
        switch 状态 {
        case errSecSuccess: return "成功"
        case errSSLWouldBlock: return "需要更多数据"
        case errSSLSessionNotFound: return "会话未找到"
        case errSSLNegotiation: return "握手协商失败"
        case errSSLFatalAlert: return "收到致命警报"
        case errSSLUnexpectedRecord: return "意外的记录"
        case errSSLDecompressFail: return "解压失败"
        case errSSLDecryptionFail: return "解密失败"
        case errSSLBadRecordMac: return "记录MAC错误"
        case errSSLProtocol: return "协议错误"
        case errSSLModuleAttach: return "模块附加失败"
        case errSSLUnknownRootCert: return "未知根证书"
        case errSSLNoRootCert: return "无根证书"
        case errSSLCertExpired: return "证书已过期"
        case errSSLCertNotYetValid: return "证书尚未生效"
        case errSSLClosedNoNotify: return "连接关闭无通知"
        case errSSLBufferOverflow: return "缓冲区溢出"
        case errSSLBadCipherSuite: return "密码套件错误"
        case errSSLPeerUnexpectedMsg: return "对端意外消息"
        case errSSLPeerBadRecordMac: return "对端记录MAC错误"
        case errSSLPeerDecryptionFail: return "对端解密失败"
        case errSSLPeerDecompressFail: return "对端解压失败"
        case errSSLPeerHandshakeFail: return "对端握手失败"
        case errSSLPeerUserCancelled: return "对端用户取消"
        case errSSLPeerNoRenegotiation: return "对端不允许重新协商"
        case errSSLClientHelloReceived: return "收到客户端Hello"
        default: return "未知错误(\(状态))"
        }
    }

    /// 读取解密后的应用数据（HTTP 请求）
    private func 读取解密数据() {
        guard let 上下文 = ssl上下文 else { return }

        // 循环读取，直到缓冲区没有完整请求或 wouldBlock
        var 解密数据 = Data()
        let 缓冲区大小 = 65536
        let 缓冲区 = UnsafeMutablePointer<UInt8>.allocate(capacity: 缓冲区大小)
        defer { 缓冲区.deallocate() }

        var 处理状态: OSStatus = errSecSuccess
        repeat {
            var 实际读取 = 0
            处理状态 = SSLRead(上下文, 缓冲区, 缓冲区大小, &实际读取)
            if 实际读取 > 0 {
                解密数据.append(缓冲区, count: 实际读取)
            }
        } while 处理状态 == errSecSuccess && 解密数据.count < 1024 * 1024

        // 刷新发送缓冲区
        刷新发送缓冲区()

        if !解密数据.isEmpty {
            // 解析 HTTP 请求并转发
            处理解密HTTP请求(解密数据)
        }

        // 继续读取客户端数据（下一个请求或更多数据）
        if 处理状态 == errSSLWouldBlock || 处理状态 == errSecSuccess {
            读取客户端数据()
        } else {
            扩展日志记录器.共享.调试("MITM", "SSLRead 失败：\(处理状态)")
            清理并完成()
        }
    }

    // MARK: - 处理解密后的 HTTP 请求

    /// 处理解密后的 HTTP 请求：解析 → 记录 → 转发 → 加密响应
    private func 处理解密HTTP请求(_ 数据: Data) {
        // 解析 HTTP 请求（复用本地代理的解析逻辑，这里简化实现）
        guard let 请求 = 解析HTTP请求(数据) else {
            扩展日志记录器.共享.调试("MITM", "解析 HTTP 请求失败")
            return
        }

        let 开始时间 = Date()

        // 创建抓包记录
        var 记录 = 抓包记录(
            请求方法: 请求.方法,
            请求URL: "https://\(目标域名)\(请求.路径)",
            请求主机: 目标域名,
            请求路径: 请求.路径,
            请求端口: 目标端口,
            是否HTTPS: true
        )
        记录.请求头 = 请求.请求头
        记录.请求Body大小 = 请求.Body.count
        记录.请求Body类型 = 推断Body类型(请求.头字典["content-type"])
        if 请求.Body.count <= 65536, let body文本 = String(data: 请求.Body, encoding: .utf8), !body文本.isEmpty {
            记录.请求Body内容 = body文本
        }
        抓包存储管理器.共享.添加记录(记录)

        // 构造 URLRequest 转发到目标服务器
        guard let url = URL(string: "https://\(目标域名)\(请求.路径)") else {
            记录.错误信息 = "无效的 URL"
            记录.结束时间 = Date()
            抓包存储管理器.共享.更新记录(记录)
            return
        }

        var 请求对象 = URLRequest(url: url)
        请求对象.httpMethod = 请求.方法
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
                self.发送加密错误响应(错误: 错误)
                return
            }

            guard let http响应 = 响应 as? HTTPURLResponse else {
                结束记录.错误信息 = "无效的响应"
                抓包存储管理器.共享.更新记录(结束记录)
                return
            }

            // 记录响应
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
            if let 响应数据 = 数据, 响应数据.count <= 65536,
               let body文本 = String(data: 响应数据, encoding: .utf8), !body文本.isEmpty {
                结束记录.响应Body内容 = body文本
            } else if let 响应数据 = 数据, 响应数据.count > 65536 {
                let 截断 = 响应数据.prefix(65536)
                if let body文本 = String(data: 截断, encoding: .utf8) {
                    结束记录.响应Body内容 = body文本
                    结束记录.响应Body已截断 = true
                }
            }
            抓包存储管理器.共享.更新记录(结束记录)

            // 将响应加密后发送给客户端
            self.发送加密响应(响应: http响应, 响应数据: 数据 ?? Data())
        }
        任务.resume()
    }

    // MARK: - 加密并发送响应

    /// 将 HTTP 响应通过 SSL 加密后发送给客户端
    private func 发送加密响应(响应: HTTPURLResponse, 响应数据: Data) {
        guard let 上下文 = ssl上下文 else { return }

        // 构造 HTTP 响应文本
        var 响应文本 = "HTTP/1.1 \(响应.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: 响应.statusCode))\r\n"
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

        // 通过 SSL 加密并发送
        处理队列.async {
            var 已写入 = 0
            while 已写入 < 完整数据.count {
                var 本次写入 = 0
                let 剩余 = 完整数据.count - 已写入
                let 状态 = SSLWrite(上下文, (完整数据 as NSData).bytes.advanced(by: 已写入), 剩余, &本次写入)
                if 状态 != errSecSuccess && 状态 != errSSLWouldBlock {
                    break
                }
                已写入 += 本次写入
                if 状态 == errSSLWouldBlock { break }
            }
            self.刷新发送缓冲区()
        }
    }

    /// 发送加密的错误响应（502）
    private func 发送加密错误响应(错误: Error) {
        let 响应文本 = "HTTP/1.1 502 Bad Gateway\r\nContent-Type: text/plain\r\nContent-Length: \(错误.localizedDescription.count)\r\nConnection: close\r\n\r\n\(错误.localizedDescription)"
        guard let 数据 = 响应文本.data(using: .utf8), let 上下文 = ssl上下文 else { return }

        处理队列.async {
            var 已写入 = 0
            while 已写入 < 数据.count {
                var 本次写入 = 0
                let 状态 = SSLWrite(上下文, (数据 as NSData).bytes.advanced(by: 已写入), 数据.count - 已写入, &本次写入)
                if 状态 != errSecSuccess { break }
                已写入 += 本次写入
            }
            self.刷新发送缓冲区()
        }
    }

    /// 将发送缓冲区中的加密数据发送给客户端
    private func 刷新发送缓冲区() {
        guard !发送缓冲区.isEmpty else { return }
        let 数据 = 发送缓冲区
        发送缓冲区.removeAll()
        客户端连接.send(content: 数据, completion: .idempotent)
    }

    // MARK: - HTTP 请求解析（简化版）

    /// 解析 HTTP 请求
    private func 解析HTTP请求(_ 数据: Data) -> (方法: String, 路径: String, 请求头: [请求头项], 头字典: [String: String], Body: Data)? {
        guard let 分隔符范围 = 数据.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let 头部数据 = 数据.prefix(upTo: 分隔符范围.lowerBound)
        let Body数据 = 数据.suffix(from: 分隔符范围.upperBound)

        guard let 头部文本 = String(data: 头部数据, encoding: .utf8) else { return nil }
        let 行数组 = 头部文本.components(separatedBy: "\r\n")
        guard !行数组.isEmpty else { return nil }

        let 请求行部分 = 行数组[0].components(separatedBy: " ")
        guard 请求行部分.count >= 2 else { return nil }
        let 方法 = 请求行部分[0]
        let 路径 = 请求行部分[1]

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

        return (方法, 路径, 头列表, 头字典, Body数据)
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

    // MARK: - 清理

    /// 清理并完成
    private func 清理并完成() {
        if let 上下文 = ssl上下文 {
            SSLClose(上下文)
            self.ssl上下文 = nil
        }
        客户端连接.cancel()
        完成回调?()
    }
}
