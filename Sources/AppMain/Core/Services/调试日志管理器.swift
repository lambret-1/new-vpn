//
//  调试日志管理器.swift
//  NewVPN
//
//  调试日志管理器：收集、过滤、搜索、导出调试日志
//  支持日志级别过滤、模块过滤、关键词搜索、持久化存储、敏感信息脱敏
//

import Foundation
import Combine

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
    /// 是否自动滚动到最新日志
    @Published var 自动滚动: Bool = true
    /// 最大日志条数（超过后自动清理旧日志）
    var 最大日志条数: Int = 2000
    /// 最低输出级别（低于此级别的日志不记录）
    var 最低输出级别: 日志级别 = .调试
    /// 是否启用敏感信息脱敏
    var 启用脱敏: Bool = true

    // MARK: - 私有属性

    /// 日志文件路径
    private var 日志文件路径: URL? {
        guard let 容器URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.newvpn.app") else {
            return nil
        }
        return 容器URL.appendingPathComponent("debug_logs.json")
    }

    /// 串行队列（保证线程安全）
    private let 队列 = DispatchQueue(label: "com.newvpn.debuglog", qos: .utility)

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
        ("(?i)token[=:\\s]+[^\\s&\"']+", "token=********")
    ]

    // MARK: - 初始化

    private init() {
        加载日志()
    }

    // MARK: - 日志添加

    /// 添加调试日志
    /// - Parameters:
    ///   - 级别: 日志级别
    ///   - 模块: 模块名称
    ///   - 内容: 日志内容
    func 添加日志(级别: 日志级别, 模块: String, 内容: String) {
        // 级别过滤：低于最低输出级别的日志不记录
        guard 级别.级别序号 >= 最低输出级别.级别序号 else { return }

        // 敏感信息脱敏
        let 处理后内容 = 启用脱敏 ? 脱敏处理(内容) : 内容

        let 日志 = 日志模型(
            id: UUID(),
            时间: Date(),
            级别: 级别,
            模块: 模块,
            内容: 处理后内容
        )

        队列.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.日志列表.append(日志)

                // 超过最大条数时清理旧日志
                if self.日志列表.count > self.最大日志条数 {
                    let 移除数量 = self.日志列表.count - self.最大日志条数
                    self.日志列表.removeFirst(移除数量)
                }
            }

            // 异步保存
            self.保存日志()
        }
    }

    /// 便捷方法：添加致命级别日志
    func 致命(_ 模块: String, _ 内容: String) {
        添加日志(级别: .致命, 模块: 模块, 内容: 内容)
    }

    /// 便捷方法：添加错误级别日志
    func 错误(_ 模块: String, _ 内容: String) {
        添加日志(级别: .错误, 模块: 模块, 内容: 内容)
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
    func 调试(_ 模块: String, _ 内容: String) {
        添加日志(级别: .调试, 模块: 模块, 内容: 内容)
    }

    /// 便捷方法：添加追踪级别日志
    func 追踪(_ 模块: String, _ 内容: String) {
        添加日志(级别: .追踪, 模块: 模块, 内容: 内容)
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

    // MARK: - 日志操作

    /// 清除所有日志
    func 清除日志() {
        队列.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.日志列表.removeAll()
            }

            self.保存日志()
        }
    }

    /// 导出日志为文本文件
    /// - Returns: 导出的文件 URL，失败返回 nil
    func 导出日志为文本() -> URL? {
        let 日期格式化 = DateFormatter()
        日期格式化.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var 文本 = "NewVPN 调试日志导出\n"
        文本 += "导出时间：\(日期格式化.string(from: Date()))\n"
        文本 += "日志总数：\(日志列表.count)\n"
        文本 += String(repeating: "=", count: 60) + "\n\n"

        for 日志 in 日志列表 {
            let 时间 = 日期格式化.string(from: 日志.时间)
            文本 += "[\(时间)] [\(日志.级别.rawValue)] [\(日志.模块)]\n"
            文本 += "\(日志.内容)\n\n"
        }

        // 保存到临时目录
        let 临时目录 = FileManager.default.temporaryDirectory
        let 文件名 = "newVPN_debug_\(Int(Date().timeIntervalSince1970)).log"
        let 文件URL = 临时目录.appendingPathComponent(文件名)

        do {
            try 文本.write(to: 文件URL, atomically: true, encoding: .utf8)
            return 文件URL
        } catch {
            最近错误 = "导出日志失败：\(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - 持久化

    /// 保存日志到文件
    private func 保存日志() {
        guard let 文件路径 = 日志文件路径 else { return }

        do {
            let 数据 = try JSONEncoder().encode(日志列表)
            try 数据.write(to: 文件路径, options: .atomic)
        } catch {
            DispatchQueue.main.async {
                self.最近错误 = "保存日志失败：\(error.localizedDescription)"
            }
        }
    }

    /// 从文件加载日志
    private func 加载日志() {
        是否加载中 = true

        队列.async { [weak self] in
            guard let self = self else { return }
            guard let 文件路径 = self.日志文件路径,
                  FileManager.default.fileExists(atPath: 文件路径.path) else {
                DispatchQueue.main.async {
                    self.是否加载中 = false
                }
                return
            }

            do {
                let 数据 = try Data(contentsOf: 文件路径)
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
}
