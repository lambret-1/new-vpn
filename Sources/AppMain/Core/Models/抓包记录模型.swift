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
struct 抓包筛选条件: Equatable {
    /// 搜索关键词（匹配 URL/主机/路径）
    var 关键词: String = ""
    /// 方法筛选（空=全部）
    var 方法筛选: Set<String> = []
    /// 仅显示错误
    var 仅显示错误: Bool = false
    /// 仅显示 HTTPS
    var 仅显示HTTPS: Bool = false

    /// 是否无筛选条件
    var 是否空: Bool {
        关键词.isEmpty && 方法筛选.isEmpty && !仅显示错误 && !仅显示HTTPS
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
        return true
    }
}
