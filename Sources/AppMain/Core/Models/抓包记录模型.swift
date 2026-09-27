//
//  抓包记录模型.swift
//  NewVPN
//
//  HTTP 抓包记录数据模型，支持 App Group 跨进程共享
//

import Foundation

// MARK: - 抓包记录

/// HTTP 抓包记录（单条请求/响应完整信息）
struct 抓包记录: Codable, Equatable, Identifiable {
    /// 唯一标识
    let id: UUID
    /// 请求开始时间
    let 开始时间: Date
    /// 请求结束时间
    var 结束时间: Date?
    /// 耗时（毫秒）
    var 耗时毫秒: Int?

    // MARK: - 请求信息

    /// HTTP 方法（GET/POST/PUT/DELETE/...）
    var 请求方法: String
    /// 完整请求 URL
    var 请求URL: String
    /// 请求主机名
    var 请求主机: String
    /// 请求路径
    var 请求路径: String
    /// 请求端口
    var 请求端口: Int
    /// 是否 HTTPS
    var 是否HTTPS: Bool
    /// 请求头列表
    var 请求头: [请求头项]
    /// 请求 Body 大小（字节）
    var 请求Body大小: Int
    /// 请求 Body 类型（json/form/text/binary/...）
    var 请求Body类型: String?
    /// 请求 Body 内容（仅文本类型，限 64KB）
    var 请求Body内容: String?
    /// 请求 Body 是否已截断
    var 请求Body已截断: Bool

    // MARK: - 响应信息

    /// 响应状态码
    var 响应状态码: Int?
    /// 响应状态文本
    var 响应状态文本: String?
    /// 响应头列表
    var 响应头: [请求头项]?
    /// 响应 Body 大小（字节）
    var 响应Body大小: Int?
    /// 响应 Body 类型
    var 响应Body类型: String?
    /// 响应 Body 内容（仅文本类型，限 64KB）
    var 响应Body内容: String?
    /// 响应 Body 是否已截断
    var 响应Body已截断: Bool

    // MARK: - 连接信息

    /// 客户端 IP
    var 客户端IP: String?
    /// 目标服务器 IP
    var 目标IP: String?
    /// 错误信息（请求失败时）
    var 错误信息: String?

    // MARK: - 计算属性

    /// 是否完成（有响应或错误）
    var 是否完成: Bool {
        结束时间 != nil
    }

    /// 是否失败
    var 是否失败: Bool {
        错误信息 != nil || (响应状态码 ?? 0) >= 400
    }

    /// 状态码颜色标识（用于 UI）
    var 状态码类别: String {
        guard let code = 响应状态码 else { return "pending" }
        switch code {
        case 200..<300: return "success"
        case 300..<400: return "redirect"
        case 400..<500: return "client_error"
        case 500..<600: return "server_error"
        default: return "unknown"
        }
    }

    /// 显示用的耗时字符串
    var 耗时显示: String {
        guard let ms = 耗时毫秒 else { return "--" }
        if ms < 1000 {
            return "\(ms)ms"
        } else {
            return String(format: "%.2fs", Double(ms) / 1000.0)
        }
    }

    /// 显示用的请求大小
    var 请求大小显示: String {
        字节格式化(请求Body大小)
    }

    /// 显示用的响应大小
    var 响应大小显示: String {
        guard let size = 响应Body大小 else { return "--" }
        return 字节格式化(size)
    }

    /// 导出为 cURL 命令
    var cURL命令: String {
        var 命令 = "curl -X \(请求方法.uppercased())"

        // URL
        命令 += " '\(请求URL)'"

        // 请求头
        for 头 in 请求头 {
            命令 += " \\\n  -H '\(头.名称): \(头.值)'"
        }

        // 请求 Body
        if let body = 请求Body内容, !body.isEmpty {
            let 转义Body = body.replacingOccurrences(of: "'", with: "'\\''")
            命令 += " \\\n  -d '\(转义Body)'"
        }

        return 命令
    }

    /// 转换为 HAR 格式的 entry 字典
    var har条目: [String: Any] {
        let 日期格式化器 = ISO8601DateFormatter()
        日期格式化器.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 请求头
        var 请求头数组: [[String: String]] = []
        for 头 in 请求头 {
            请求头数组.append(["name": 头.名称, "value": 头.值])
        }

        // 响应头
        var 响应头数组: [[String: String]] = []
        if let 响应头 = 响应头 {
            for 头 in 响应头 {
                响应头数组.append(["name": 头.名称, "value": 头.值])
            }
        }

        // 请求部分
        var 请求字典: [String: Any] = [
            "method": 请求方法.uppercased(),
            "url": 请求URL,
            "httpVersion": "HTTP/1.1",
            "headers": 请求头数组,
            "queryString": [],
            "cookies": [],
            "headersSize": -1,
            "bodySize": 请求Body大小
        ]
        if let body = 请求Body内容 {
            请求字典["postData"] = [
                "mimeType": 请求Body类型 ?? "application/octet-stream",
                "text": body
            ]
        }

        // 响应部分
        var 内容字典: [String: Any] = [
            "size": 响应Body大小 ?? 0,
            "mimeType": 响应Body类型 ?? ""
        ]
        if let body = 响应Body内容 {
            内容字典["text"] = body
        }

        var 响应字典: [String: Any] = [
            "status": 响应状态码 ?? 0,
            "statusText": 响应状态文本 ?? "",
            "httpVersion": "HTTP/1.1",
            "headers": 响应头数组,
            "cookies": [],
            "content": 内容字典,
            "redirectURL": "",
            "headersSize": -1,
            "bodySize": 响应Body大小 ?? 0
        ]

        // 完整 entry
        return [
            "startedDateTime": 日期格式化器.string(from: 开始时间),
            "time": 耗时毫秒 ?? 0,
            "request": 请求字典,
            "response": 响应字典,
            "cache": [:],
            "timings": [
                "send": 0,
                "wait": 耗时毫秒 ?? 0,
                "receive": 0
            ]
        ]
    }

    /// 将多条记录导出为 HAR 格式 JSON 字符串
    static func 导出HAR(_ 记录列表: [抓包记录]) -> String {
        let har字典: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": [
                    "name": "NewVPN",
                    "version": "1.0"
                ],
                "entries": 记录列表.map { $0.har条目 }
            ]
        ]
        if let 数据 = try? JSONSerialization.data(withJSONObject: har字典, options: [.prettyPrinted]),
           let 字符串 = String(data: 数据, encoding: .utf8) {
            return 字符串
        }
        return "{}"
    }

    // MARK: - 初始化

    /// 创建新的抓包记录（请求开始时调用）
    init(请求方法: String, 请求URL: String, 请求主机: String, 请求路径: String, 请求端口: Int, 是否HTTPS: Bool) {
        self.id = UUID()
        self.开始时间 = Date()
        self.请求方法 = 请求方法
        self.请求URL = 请求URL
        self.请求主机 = 请求主机
        self.请求路径 = 请求路径
        self.请求端口 = 请求端口
        self.是否HTTPS = 是否HTTPS
        self.请求头 = []
        self.请求Body大小 = 0
        self.请求Body已截断 = false
        self.响应Body已截断 = false
    }

    // MARK: - 私有方法

    /// 字节数格式化显示
    private func 字节格式化(_ 字节数: Int) -> String {
        if 字节数 < 1024 {
            return "\(字节数)B"
        } else if 字节数 < 1024 * 1024 {
            return String(format: "%.1fKB", Double(字节数) / 1024.0)
        } else {
            return String(format: "%.2fMB", Double(字节数) / (1024.0 * 1024.0))
        }
    }
}

// MARK: - 请求头项

/// HTTP 请求/响应头键值对
struct 请求头项: Codable, Equatable, Identifiable {
    /// 唯一标识（用于列表渲染）
    let id: UUID
    /// 头名称
    let 名称: String
    /// 头值
    let 值: String

    init(名称: String, 值: String) {
        self.id = UUID()
        self.名称 = 名称
        self.值 = 值
    }
}

// MARK: - 抓包筛选条件

/// 抓包记录筛选条件
struct 抓包筛选条件: Equatable, Codable {
    /// 搜索关键词（匹配 URL/主机/路径）
    var 关键词: String = ""
    /// 方法筛选（空=全部）
    var 方法筛选: Set<String> = []
    /// 仅显示错误
    var 仅显示错误: Bool = false
    /// 仅显示 HTTPS
    var 仅显示HTTPS: Bool = false
    /// 状态码筛选（空=全部，可选 2xx/3xx/4xx/5xx）
    var 状态码筛选: Set<String> = []
    /// 最小响应大小（字节，0=不限制）
    var 最小响应大小: Int = 0
    /// 仅显示有响应 Body 的记录
    var 仅显示有Body: Bool = false

    /// 是否无筛选条件
    var 是否空: Bool {
        关键词.isEmpty && 方法筛选.isEmpty && !仅显示错误 && !仅显示HTTPS
        && 状态码筛选.isEmpty && 最小响应大小 == 0 && !仅显示有Body
    }

    /// 判断记录是否符合筛选条件
    func 匹配(_ 记录: 抓包记录) -> Bool {
        // 关键词筛选
        if !关键词.isEmpty {
            let kw = 关键词.lowercased()
            let 匹配 = 记录.请求URL.lowercased().contains(kw)
                || 记录.请求主机.lowercased().contains(kw)
                || 记录.请求路径.lowercased().contains(kw)
            if !匹配 { return false }
        }
        // 方法筛选
        if !方法筛选.isEmpty {
            if !方法筛选.contains(记录.请求方法.uppercased()) { return false }
        }
        // 仅错误
        if 仅显示错误 && !记录.是否失败 { return false }
        // 仅 HTTPS
        if 仅显示HTTPS && !记录.是否HTTPS { return false }
        // 状态码筛选
        if !状态码筛选.isEmpty {
            guard let 状态码 = 记录.响应状态码 else { return false }
            let 类别 = "\(状态码 / 100)xx"
            if !状态码筛选.contains(类别) { return false }
        }
        // 最小响应大小
        if 最小响应大小 > 0 {
            if (记录.响应Body大小 ?? 0) < 最小响应大小 { return false }
        }
        // 仅显示有 Body
        if 仅显示有Body {
            if (记录.响应Body大小 ?? 0) == 0 { return false }
        }
        return true
    }
}
