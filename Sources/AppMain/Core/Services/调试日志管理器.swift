//
//  调试日志管理器.swift
//  NewVPN
//
//  调试日志管理器：收集、过滤、搜索、导出调试日志
//  支持日志级别过滤、模块过滤、关键词搜索、持久化存储、敏感信息脱敏
//  文件滚动日志、内存环形缓冲区、异步队列、超长截断
//

import Foundation
import Combine

// MARK: - 日志配置

/// 日志配置（持久化到 UserDefaults）
struct 日志配置: Codable, Equatable {
    /// 最低输出级别
    var 最低输出级别: 日志级别 = .调试
    /// 内存缓冲区最大条数
    var 最大日志条数: Int = 2000
    /// 是否启用文件日志
    var 启用文件日志: Bool = true
    /// 单文件最大大小（MB）
    var 单文件最大MB: Int = 5
    /// 文件数量上限
    var 文件数量上限: Int = 10
    /// 是否启用敏感信息脱敏
    var 启用脱敏: Bool = true
    /// 是否自动滚动到最新日志
    var 自动滚动: Bool = true
    /// 单条日志最大字符数（超过截断）
    var 单条最大字符数: Int = 4096
}

// MARK: - 调试日志管理器

/// 调试日志管理器
final class 调试日志管理器: ObservableObject {
    /// 共享单例
    static let 共享 = 调试日志管理器()

    // MARK: - 发布属性

    /// 日志列表
    @Published private(set) var 日志列表: [日志模型] = []
    /// 搜索关键词
    @Published var 搜索关键词: String = ""
    /// 当前过滤级别（nil 表示显示所有级别）
    @Published var 过滤级别: 日志级别?
    /// 当前过滤模块（nil 表示显示所有模块）
    @Published var 过滤模块: String?
    /// 是否正在加载
    @Published var 是否加载中: Bool = false
    /// 最近错误信息
    @Published var 最近错误: String?
    /// 日志配置
    @Published var 配置: 日志配置 {
        didSet { 保存配置() }
    }

    // MARK: - 私有属性

    /// App Group 容器 URL
    private var 容器URL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.newvpn.app")
    }

    /// 日志文件目录
    private var 日志目录: URL? {
        guard let 目录 = 容器URL?.appendingPathComponent("logs", isDirectory: true) else { return nil }
        if !FileManager.default.fileExists(atPath: 目录.path) {
            try? FileManager.default.createDirectory(at: 目录, withIntermediateDirectories: true)
        }
        return 目录
    }

    /// 配置文件路径
    private var 配置文件路径: URL? {
        容器URL?.appendingPathComponent("debug_config.json")
    }

    /// 串行队列（保证线程安全）
    private let 队列 = DispatchQueue(label: "com.newvpn.debuglog", qos: .utility)

    /// 日志处理队列（有容量限制）
    private let 处理队列 = DispatchQueue(label: "com.newvpn.debuglog.process", qos: .background)

    /// 待处理日志计数（用于队列溢出判断）
    private var 待处理计数 = 0
    /// 队列容量上限
    private let 队列容量 = 1000

    /// 脱敏正则表达式列表
    private let 脱敏规则: [(模式: String, 替换: String)] = [
        // UUID 格式
        ("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", "********"),
        // 订阅 URL（包含 /sub）
        ("https?://[^\\s]*?/sub[^\\s]*", "********"),
        // Reality 公钥（base64 长字符串）
        ("(?i)reality[\\s:]*[A-Za-z0-9+/]{40,}={0,2}", "reality: ********"),
        // Cookie 头
        ("(?i)cookie:\\s*[^\\n\\r]+", "Cookie: ********"),
        // Authorization 头
        ("(?i)authorization:\\s*[^\\n\\r]+", "Authorization: ********"),
        // 密码字段
        ("(?i)password[=:\\s]+[^\\s&\"']+", "password=********"),
        // 令牌字段
        ("(?i)token[=:\\s]+[^\\s&\"']+", "token=********"),
        // IP 地址（可选脱敏）
        ("\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b", "***.***.***.***")
    ]

    /// 日期格式化器（日志文件名用）
    private let 文件日期格式化: DateFormatter = {
        let 格式化 = DateFormatter()
        格式化.dateFormat = "yyyyMMdd"
        return 格式化
    }()

    /// 日期格式化器（日志内容用）
    private let 内容日期格式化: DateFormatter = {
        let 格式化 = DateFormatter()
        格式化.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return 格式化
    }()

    // MARK: - 初始化

    private init() {
        // 先加载配置
        let 默认配置 = 日志配置()
        self.配置 = 默认配置
        加载配置()

        // 加载历史日志
        加载日志()

        // 启动扩展日志读取定时器
        启动扩展日志读取定时器()
    }

    // MARK: - 配置持久化

    /// 保存配置到文件
    private func 保存配置() {
        guard let 路径 = 配置文件路径 else { return }
        队列.async {
            do {
                let 数据 = try JSONEncoder().encode(self.配置)
                try 数据.write(to: 路径, options: .atomic)
            } catch {
                DispatchQueue.main.async {
                    self.最近错误 = "保存日志配置失败：\(error.localizedDescription)"
                }
            }
        }
    }

    /// 从文件加载配置
    private func 加载配置() {
        guard let 路径 = 配置文件路径,
              FileManager.default.fileExists(atPath: 路径.path),
              let 数据 = try? Data(contentsOf: 路径),
              let 已加载配置 = try? JSONDecoder().decode(日志配置.self, from: 数据) else {
            return
        }
        self.配置 = 已加载配置
    }

    // MARK: - 扩展日志读取

    /// 扩展日志读取定时器
    private var 扩展日志定时器: Timer?

    /// 已读取的扩展日志 ID 集合（避免重复）
    private var 已读取扩展日志ID = Set<String>()

    /// 启动扩展日志读取定时器（每 2 秒读取一次隧道扩展日志）
    private func 启动扩展日志读取定时器() {
        DispatchQueue.main.async { [weak self] in
            self?.扩展日志定时器 = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                self?.读取扩展日志()
            }
            self?.扩展日志定时器?.tolerance = 0.5
        }
    }

    /// 从共享 UserDefaults 读取隧道扩展日志
    func 读取扩展日志() {
        guard let 共享默认 = UserDefaults(suiteName: "group.com.newvpn.app"),
              let 日志数据 = 共享默认.data(forKey: "tunnelLogs"),
              let 扩展日志列表 = try? JSONDecoder().decode([扩展日志条目].self, from: 日志数据) else {
            return
        }

        for 扩展日志 in 扩展日志列表 {
            let id字符串 = 扩展日志.id.uuidString
            guard !已读取扩展日志ID.contains(id字符串) else { continue }
            已读取扩展日志ID.insert(id字符串)

            let 级别 = 日志级别(rawValue: 扩展日志.级别) ?? .信息
            let 日志 = 日志模型(
                id: 扩展日志.id,
                时间: 扩展日志.时间,
                级别: 级别,
                模块: "扩展-\(扩展日志.模块)",
                内容: 扩展日志.内容
            )

            DispatchQueue.main.async { [weak self] in
                self?.日志列表.append(日志)
                self?.清理超出缓冲区()
            }

            // 异步写入文件
            写入文件日志(日志)
        }
    }

    /// 扩展日志条目（与隧道扩展写入格式一致）
    private struct 扩展日志条目: Codable {
        let id: UUID
        let 时间: Date
        let 级别: String
        let 模块: String
        let 内容: String
    }

    // MARK: - 日志添加

    /// 添加调试日志
    /// - Parameters:
    ///   - 级别: 日志级别
    ///   - 模块: 模块名称
    ///   - 内容: 日志内容
    ///   - 附加字段: 附加字段（可选）
    ///   - 堆栈: 异常堆栈（仅 error/fatal，可选）
    func 添加日志(级别: 日志级别, 模块: String, 内容: String, 附加字段: [String: String]? = nil, 堆栈: String? = nil) {
        // 级别过滤：低于最低输出级别的日志不记录
        guard 级别.级别序号 >= 配置.最低输出级别.级别序号 else { return }

        // 队列溢出保护：队列满时丢弃 trace/debug
        if 待处理计数 >= 队列容量 {
            if 级别 == .追踪 || 级别 == .调试 {
                return
            }
        }
        待处理计数 += 1

        处理队列.async { [weak self] in
            guard let self = self else { return }
            self.待处理计数 -= 1

            // 单条日志超长截断
            var 处理后内容 = 内容
            if 处理后内容.count > self.配置.单条最大字符数 {
                let 截断索引 = 处理后内容.index(处理后内容.startIndex, offsetBy: self.配置.单条最大字符数)
                处理后内容 = String(处理后内容[..<截断索引]) + "...[截断]"
            }

            // 敏感信息脱敏
            if self.配置.启用脱敏 {
                处理后内容 = self.脱敏处理(处理后内容)
            }

            let 日志 = 日志模型(
                级别: 级别,
                模块: 模块,
                内容: 处理后内容,
                附加字段: 附加字段,
                堆栈: 堆栈
            )

            DispatchQueue.main.async {
                self.日志列表.append(日志)
                self.清理超出缓冲区()
            }

            // 异步写入文件
            if self.配置.启用文件日志 {
                self.写入文件日志(日志)
            }
        }
    }

    /// 清理超出缓冲区的旧日志
    private func 清理超出缓冲区() {
        if 日志列表.count > 配置.最大日志条数 {
            let 移除数量 = 日志列表.count - 配置.最大日志条数
            日志列表.removeFirst(移除数量)
        }
    }

    /// 便捷方法：添加致命级别日志
    func 致命(_ 模块: String, _ 内容: String, 堆栈: String? = nil) {
        添加日志(级别: .致命, 模块: 模块, 内容: 内容, 堆栈: 堆栈)
    }

    /// 便捷方法：添加错误级别日志
    func 错误(_ 模块: String, _ 内容: String, 堆栈: String? = nil) {
        添加日志(级别: .错误, 模块: 模块, 内容: 内容, 堆栈: 堆栈)
    }

    /// 便捷方法：添加警告级别日志
    func 警告(_ 模块: String, _ 内容: String) {
        添加日志(级别: .警告, 模块: 模块, 内容: 内容)
    }

    /// 便捷方法：添加信息级别日志
    func 信息(_ 模块: String, _ 内容: String) {
        添加日志(级别: .信息, 模块: 模块, 内容: 内容)
    }

    /// 便捷方法：添加调试级别日志
    func 调试(_ 模块: String, _ 内容: String, 附加字段: [String: String]? = nil) {
        添加日志(级别: .调试, 模块: 模块, 内容: 内容, 附加字段: 附加字段)
    }

    /// 便捷方法：添加追踪级别日志
    func 追踪(_ 模块: String, _ 内容: String, 附加字段: [String: String]? = nil) {
        添加日志(级别: .追踪, 模块: 模块, 内容: 内容, 附加字段: 附加字段)
    }

    // MARK: - 敏感信息脱敏

    /// 对日志内容进行敏感信息脱敏
    /// - Parameter 内容: 原始日志内容
    /// - Returns: 脱敏后的内容
    private func 脱敏处理(_ 内容: String) -> String {
        var 处理后内容 = 内容
        for 规则 in 脱敏规则 {
            处理后内容 = 处理后内容.replacingOccurrences(
                of: 规则.模式,
                with: 规则.替换,
                options: .regularExpression
            )
        }
        return 处理后内容
    }

    // MARK: - 日志过滤

    /// 筛选后的日志列表
    var 筛选后的日志列表: [日志模型] {
        日志列表.filter { 日志 in
            // 级别过滤
            if let 级别 = 过滤级别, 日志.级别 != 级别 {
                return false
            }
            // 模块过滤
            if let 模块 = 过滤模块, 日志.模块 != 模块 {
                return false
            }
            // 搜索过滤
            if !搜索关键词.isEmpty {
                if !日志.内容.lowercased().contains(搜索关键词.lowercased()) &&
                   !日志.模块.lowercased().contains(搜索关键词.lowercased()) {
                    return false
                }
            }
            return true
        }
    }

    /// 所有模块列表（用于过滤选择）
    var 所有模块列表: [String] {
        let 模块集合 = Set(日志列表.map { $0.模块 })
        return Array(模块集合).sorted()
    }

    // MARK: - 统计

    /// 各级别日志数量
    var 级别统计: [日志级别: Int] {
        var 统计: [日志级别: Int] = [:]
        for 级别 in 日志级别.allCases {
            统计[级别] = 0
        }
        for 日志 in 日志列表 {
            统计[日志.级别, default: 0] += 1
        }
        return 统计
    }

    /// 今日日志数量
    var 今日日志数量: Int {
        let 日历 = Calendar.current
        return 日志列表.filter { 日历.isDateInToday($0.时间) }.count
    }

    // MARK: - 文件滚动日志

    /// 当前日志文件路径
    private var 当前日志文件路径: URL? {
        guard let 目录 = 日志目录 else { return nil }
        let 日期字符串 = 文件日期格式化.string(from: Date())
        return 目录.appendingPathComponent("app-\(日期字符串).log")
    }

    /// 写入单条日志到文件
    private func 写入文件日志(_ 日志: 日志模型) {
        guard 配置.启用文件日志, let 文件路径 = 当前日志文件路径 else { return }

        let 时间 = 内容日期格式化.string(from: 日志.时间)
        var 行 = "[\(时间)] [\(日志.级别.rawValue)] [\(日志.模块)] \(日志.内容)\n"
        if let 堆栈 = 日志.堆栈 {
            行 += "堆栈：\(堆栈)\n"
        }
        if let 附加 = 日志.附加字段, !附加.isEmpty {
            行 += "附加：\(附加)\n"
        }

        队列.async {
            do {
                // 检查文件大小，触发滚动
                if FileManager.default.fileExists(atPath: 文件路径.path) {
                    let 属性 = try FileManager.default.attributesOfItem(atPath: 文件路径.path)
                    if let 大小 = 属性[.size] as? Int,
                       大小 >= self.配置.单文件最大MB * 1024 * 1024 {
                        self.滚动日志文件()
                    }
                }

                // 追加写入
                if let 数据 = 行.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: 文件路径.path) {
                        let 文件句柄 = try FileHandle(forWritingTo: 文件路径)
                        文件句柄.seekToEndOfFile()
                        文件句柄.write(数据)
                        try 文件句柄.close()
                    } else {
                        try 数据.write(to: 文件路径, options: .atomic)
                    }
                }
            } catch {
                // 文件写入失败不影响内存日志
            }
        }
    }

    /// 滚动日志文件（重命名当前文件，清理旧文件）
    private func 滚动日志文件() {
        guard let 目录 = 日志目录, let 当前路径 = 当前日志文件路径 else { return }

        let 日期字符串 = 文件日期格式化.string(from: Date())
        let 时间戳 = Int(Date().timeIntervalSince1970)
        let 归档路径 = 目录.appendingPathComponent("app-\(日期字符串)_\(时间戳).log")

        do {
            try FileManager.default.moveItem(at: 当前路径, to: 归档路径)
        } catch {
            return
        }

        // 清理超过数量上限的旧文件
        清理旧日志文件()
    }

    /// 清理超过数量上限的旧日志文件
    private func 清理旧日志文件() {
        guard let 目录 = 日志目录 else { return }

        do {
            let 文件列表 = try FileManager.default.contentsOfDirectory(
                at: 目录,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "log" }
              .sorted { (文件1, 文件2) -> Bool in
                  let 日期1 = (try? 文件1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                  let 日期2 = (try? 文件2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                  return 日期1 < 日期2
              }

            if 文件列表.count > 配置.文件数量上限 {
                let 移除数量 = 文件列表.count - 配置.文件数量上限
                for i in 0..<移除数量 {
                    try? FileManager.default.removeItem(at: 文件列表[i])
                }
            }
        } catch {
            // 忽略清理错误
        }
    }

    /// 获取所有日志文件列表（按时间倒序）
    func 获取日志文件列表() -> [URL] {
        guard let 目录 = 日志目录 else { return [] }

        return (try? FileManager.default.contentsOfDirectory(
            at: 目录,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "log" }
          .sorted { (文件1, 文件2) -> Bool in
              let 日期1 = (try? 文件1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
              let 日期2 = (try? 文件2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
              return 日期1 > 日期2
          }) ?? []
    }

    // MARK: - 日志操作

    /// 清除所有日志（内存 + 文件）
    func 清除日志() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.日志列表.removeAll()
            self.已读取扩展日志ID.removeAll()
        }

        队列.async { [weak self] in
            guard let self = self else { return }

            // 清除文件日志
            if let 目录 = self.日志目录 {
                let 文件列表 = try? FileManager.default.contentsOfDirectory(at: 目录, includingPropertiesForKeys: nil)
                for 文件 in 文件列表 ?? [] where 文件.pathExtension == "log" {
                    try? FileManager.default.removeItem(at: 文件)
                }
            }

            // 清除内存日志持久化文件
            if let 路径 = self.容器URL?.appendingPathComponent("debug_logs.json") {
                try? FileManager.default.removeItem(at: 路径)
            }
        }
    }

    /// 导出当前筛选后的日志为文本文件
    /// - Returns: 导出的文件 URL，失败返回 nil
    func 导出日志为文本() -> URL? {
        let 日期格式化 = DateFormatter()
        日期格式化.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var 文本 = "NewVPN 调试日志导出\n"
        文本 += "导出时间：\(日期格式化.string(from: Date()))\n"
        文本 += "日志总数：\(筛选后的日志列表.count)\n"
        if let 级别 = 过滤级别 {
            文本 += "级别过滤：\(级别.rawValue)\n"
        }
        if let 模块 = 过滤模块 {
            文本 += "模块过滤：\(模块)\n"
        }
        if !搜索关键词.isEmpty {
            文本 += "搜索关键词：\(搜索关键词)\n"
        }
        文本 += String(repeating: "=", count: 60) + "\n\n"

        for 日志 in 筛选后的日志列表 {
            let 时间 = 日期格式化.string(from: 日志.时间)
            文本 += "[\(时间)] [\(日志.级别.rawValue)] [\(日志.模块)]\n"
            文本 += "\(日志.内容)\n"
            if let 堆栈 = 日志.堆栈 {
                文本 += "堆栈：\(堆栈)\n"
            }
            if let 附加 = 日志.附加字段, !附加.isEmpty {
                文本 += "附加：\(附加)\n"
            }
            文本 += "\n"
        }

        // 保存到临时目录
        let 临时目录 = FileManager.default.temporaryDirectory
        let 文件名 = "newVPN_debug_\(Int(Date().timeIntervalSince1970)).log"
        let 文件URL = 临时目录.appendingPathComponent(文件名)

        do {
            try 文本.write(to: 文件URL, atomically: true, encoding: .utf8)
            return 文件URL
        } catch {
            DispatchQueue.main.async {
                self.最近错误 = "导出日志失败：\(error.localizedDescription)"
            }
            return nil
        }
    }

    // MARK: - 内存日志持久化

    /// 保存内存日志到文件（定期保存，避免频繁 IO）
    private var 保存定时器: Timer?

    /// 启动定期保存
    func 启动定期保存() {
        DispatchQueue.main.async { [weak self] in
            self?.保存定时器 = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                self?.保存内存日志()
            }
        }
    }

    /// 保存内存日志到 JSON 文件
    private func 保存内存日志() {
        guard let 路径 = 容器URL?.appendingPathComponent("debug_logs.json") else { return }
        // 先在主线程复制日志列表，避免后台线程访问导致竞争条件
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let 保存列表 = Array(self.日志列表.suffix(500))
            self.队列.async {
                do {
                    let 数据 = try JSONEncoder().encode(保存列表)
                    try 数据.write(to: 路径, options: .atomic)
                } catch {
                    // 忽略保存错误
                }
            }
        }
    }

    /// 从文件加载内存日志
    private func 加载日志() {
        是否加载中 = true

        队列.async { [weak self] in
            guard let self = self else { return }
            guard let 路径 = self.容器URL?.appendingPathComponent("debug_logs.json"),
                  FileManager.default.fileExists(atPath: 路径.path) else {
                DispatchQueue.main.async {
                    self.是否加载中 = false
                }
                return
            }

            do {
                let 数据 = try Data(contentsOf: 路径)
                let 日志 = try JSONDecoder().decode([日志模型].self, from: 数据)

                DispatchQueue.main.async {
                    self.日志列表 = 日志
                    self.是否加载中 = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.最近错误 = "加载日志失败：\(error.localizedDescription)"
                    self.是否加载中 = false
                }
            }
        }
    }

    // MARK: - 设置快捷方法

    /// 设置最低输出级别
    func 设置最低级别(_ 级别: 日志级别) {
        配置.最低输出级别 = 级别
    }

    /// 切换脱敏开关
    func 切换脱敏() {
        配置.启用脱敏.toggle()
    }

    /// 切换自动滚动
    func 切换自动滚动() {
        配置.自动滚动.toggle()
    }

    /// 设置缓冲区大小
    func 设置缓冲区大小(_ 大小: Int) {
        配置.最大日志条数 = max(500, min(5000, 大小))
    }
}
