//
//  SingBox内核管理器.swift
//  NewVPN
//
//  sing-box 内核管理器
//  负责内核启动、停止、状态监控、日志收集、配置管理
//

import Foundation
import Combine

// MARK: - sing-box 内核管理器

/// sing-box 内核管理器
final class SingBox内核管理器: ObservableObject {
    /// 共享单例
    static let 共享 = SingBox内核管理器()

    // MARK: - 发布状态

    /// 内核运行状态
    @Published var 内核状态: SingBox内核状态 = .未启动
    /// 当前配置
    @Published var 当前配置: SingBox配置?
    /// 内核日志列表
    @Published var 日志列表: [SingBox内核日志] = []
    /// 内核版本
    @Published var 内核版本: String = "未知"
    /// 是否正在加载配置
    @Published var 是否加载中 = false
    /// 最近错误
    @Published var 最近错误: String?
    /// 运行时长（秒）
    @Published var 运行时长: TimeInterval = 0

    // MARK: - 内部属性

    /// 内核启动时间
    private var 启动时间: Date?
    /// 运行时长定时器
    private var 运行时长定时器: Timer?
    /// 配置文件路径
    private var 配置文件路径: String?
    /// 日志文件路径
    private var 日志文件路径: String?
    /// 内核进程（预留，实际 sing-box 运行在同一进程的 Go 运行时中）
    private var 内核运行中 = false

    /// 私有初始化
    private init() {
        初始化路径()
        检测内核版本()
    }

    // MARK: - 初始化

    /// 初始化文件路径
    private func 初始化路径() {
        // 共享容器路径
        if let 容器URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: 隧道常量.AppGroupID) {
            配置文件路径 = 容器URL.appendingPathComponent("singbox_config.json").path
            日志文件路径 = 容器URL.appendingPathComponent("singbox.log").path
        }

        // 文档目录路径（备选）
        if 配置文件路径 == nil {
            let 文档目录 = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            配置文件路径 = 文档目录?.appendingPathComponent("singbox_config.json").path
            日志文件路径 = 文档目录?.appendingPathComponent("singbox.log").path
        }
    }

    /// 检测内核版本
    private func 检测内核版本() {
        // 预留：实际应调用 sing-box 内核 API 获取版本
        // 目前使用硬编码版本
        内核版本 = "1.10.0"
        记录日志(级别: "info", 内容: "sing-box 内核版本：\(内核版本)")
    }

    // MARK: - 内核控制

    /// 启动内核
    /// - Parameter 配置: sing-box 配置
    /// - Returns: 是否启动成功
    @discardableResult
    func 启动内核(配置: SingBox配置) -> Bool {
        guard !内核状态.是否活动 else {
            记录日志(级别: "warn", 内容: "内核已在运行中")
            return false
        }

        内核状态 = .正在启动
        是否加载中 = true
        当前配置 = 配置

        // 验证配置
        let 验证结果 = SingBox配置生成器.共享.验证配置(配置)
        guard 验证结果.有效 else {
            内核状态 = .配置错误
            最近错误 = 验证结果.错误.joined(separator: "; ")
            记录日志(级别: "error", 内容: "配置验证失败：\(最近错误 ?? "未知错误")")
            是否加载中 = false
            return false
        }

        // 保存配置到文件
        guard let 配置路径 = 配置文件路径,
              SingBox配置生成器.共享.保存配置(配置, 到路径: 配置路径) else {
            内核状态 = .配置错误
            最近错误 = "配置文件保存失败"
            记录日志(级别: "error", 内容: "配置文件保存失败")
            是否加载中 = false
            return false
        }

        记录日志(级别: "info", 内容: "配置文件已保存：\(配置路径)")

        // 启动 sing-box 内核
        // 预留：实际应调用 sing-box Go 库的启动函数
        // 例如：singbox_start(configPath, logCallback)
        let 启动成功 = 执行内核启动(配置路径: 配置路径)

        if 启动成功 {
            内核状态 = .运行中
            内核运行中 = true
            启动时间 = Date()
            启动运行时长定时器()
            记录日志(级别: "info", 内容: "sing-box 内核启动成功")
        } else {
            内核状态 = .启动失败
            最近错误 = "内核启动失败"
            记录日志(级别: "error", 内容: "sing-box 内核启动失败")
        }

        是否加载中 = false
        return 启动成功
    }

    /// 停止内核
    func 停止内核() {
        guard 内核状态.是否活动 else {
            记录日志(级别: "warn", 内容: "内核未在运行")
            return
        }

        内核状态 = .正在停止
        记录日志(级别: "info", 内容: "正在停止 sing-box 内核...")

        // 停止 sing-box 内核
        // 预留：实际应调用 sing-box Go 库的停止函数
        // 例如：singbox_stop()
        执行内核停止()

        内核运行中 = false
        内核状态 = .已停止
        停止运行时长定时器()
        运行时长 = 0
        启动时间 = nil

        记录日志(级别: "info", 内容: "sing-box 内核已停止")
    }

    /// 重启内核
    func 重启内核() {
        guard let 配置 = 当前配置 else {
            记录日志(级别: "error", 内容: "没有可用的配置，无法重启")
            return
        }

        记录日志(级别: "info", 内容: "正在重启 sing-box 内核...")

        if 内核状态.是否活动 {
            停止内核()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.启动内核(配置: 配置)
        }
    }

    /// 重新加载配置
    func 重新加载配置(_ 新配置: SingBox配置) {
        guard 内核状态.是否活动 else {
            启动内核(配置: 新配置)
            return
        }

        记录日志(级别: "info", 内容: "正在重新加载配置...")

        // 保存新配置
        guard let 配置路径 = 配置文件路径,
              SingBox配置生成器.共享.保存配置(新配置, 到路径: 配置路径) else {
            记录日志(级别: "error", 内容: "配置文件保存失败")
            return
        }

        当前配置 = 新配置

        // 通知内核重新加载配置
        // 预留：实际应调用 sing-box Go 库的重新加载函数
        // 例如：singbox_reload(configPath)
        执行内核重载(配置路径: 配置路径)

        记录日志(级别: "info", 内容: "配置已重新加载")
    }

    // MARK: - 内核执行（预留接口）

    /// 执行内核启动
    /// 预留：实际应调用 sing-box Go 库
    private func 执行内核启动(配置路径: String) -> Bool {
        // TODO: 集成 sing-box Go 库后实现
        // 目前返回模拟成功
        return true
    }

    /// 执行内核停止
    private func 执行内核停止() {
        // TODO: 集成 sing-box Go 库后实现
    }

    /// 执行内核重载
    private func 执行内核重载(配置路径: String) {
        // TODO: 集成 sing-box Go 库后实现
    }

    // MARK: - 运行时长

    /// 启动运行时长定时器
    private func 启动运行时长定时器() {
        停止运行时长定时器()
        运行时长定时器 = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let 启动时间 = self.启动时间 else { return }
            self.运行时长 = Date().timeIntervalSince(启动时间)
        }
        RunLoop.main.add(运行时长定时器!, forMode: .common)
    }

    /// 停止运行时长定时器
    private func 停止运行时长定时器() {
        运行时长定时器?.invalidate()
        运行时长定时器 = nil
    }

    /// 格式化运行时长
    var 运行时长显示: String {
        let 小时 = Int(运行时长) / 3600
        let 分钟 = (Int(运行时长) % 3600) / 60
        let 秒 = Int(运行时长) % 60

        if 小时 > 0 {
            return String(format: "%02d:%02d:%02d", 小时, 分钟, 秒)
        } else {
            return String(format: "%02d:%02d", 分钟, 秒)
        }
    }

    // MARK: - 日志管理

    /// 记录日志
    func 记录日志(级别: String, 内容: String) {
        let 日志 = SingBox内核日志(
            时间: Date(),
            级别: 级别,
            内容: 内容
        )

        DispatchQueue.main.async { [weak self] in
            self?.日志列表.insert(日志, at: 0)
            if (self?.日志列表.count ?? 0) > 500 {
                self?.日志列表.removeLast()
            }
        }

        // 写入日志文件
        if let 日志路径 = 日志文件路径 {
            let 日志行 = "\(日志.时间显示) [\(级别.uppercased())] \(内容)\n"
            if let 数据 = 日志行.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: 日志路径) {
                    if let 文件 = try? FileHandle(forWritingTo: URL(fileURLWithPath: 日志路径)) {
                        文件.seekToEndOfFile()
                        文件.write(数据)
                        try? 文件.close()
                    }
                } else {
                    try? 数据.write(to: URL(fileURLWithPath: 日志路径))
                }
            }
        }
    }

    /// 清除日志
    func 清除日志() {
        日志列表.removeAll()
        if let 日志路径 = 日志文件路径 {
            try? FileManager.default.removeItem(atPath: 日志路径)
        }
    }

    /// 从日志文件读取历史日志
    func 读取历史日志(最大条数: Int = 100) {
        guard let 日志路径 = 日志文件路径,
              let 内容 = try? String(contentsOfFile: 日志路径, encoding: .utf8) else {
            return
        }

        let 行列表 = 内容.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let 最近行 = Array(行列表.suffix(最大条数))

        for 行 in 最近行.reversed() {
            // 解析日志行：时间 [级别] 内容
            if let 级别范围 = 行.range(of: "\\[([A-Z]+)\\]", options: .regularExpression),
               let 时间范围 = 行.range(of: "^\\d{2}:\\d{2}:\\d{2}\\.\\d{3}", options: .regularExpression) {
                let 级别 = String(行[级别范围].dropFirst().dropLast())
                let 内容 = String(行[级别范围.upperBound...]).trimmingCharacters(in: .whitespaces)
                let 日志 = SingBox内核日志(
                    时间: Date(),
                    级别: 级别.lowercased(),
                    内容: 内容
                )
                日志列表.append(日志)
            }
        }
    }

    // MARK: - 配置管理

    /// 生成并保存配置
    /// - Parameters:
    ///   - 节点: 当前节点
    ///   - 节点列表: 所有节点
    ///   - 分流规则: 分流规则
    ///   - DNS配置: DNS 配置
    /// - Returns: 生成的配置
    func 生成并保存配置(节点: 节点模型?,
                        节点列表: [节点模型] = [],
                        分流规则: [分流规则项] = [],
                        DNS配置: DNS配置模型? = nil) -> SingBox配置? {
        let 配置 = SingBox配置生成器.共享.生成配置(
            节点: 节点,
            节点列表: 节点列表,
            分流规则: 分流规则,
            DNS配置: DNS配置
        )

        当前配置 = 配置

        if let 配置路径 = 配置文件路径 {
            SingBox配置生成器.共享.保存配置(配置, 到路径: 配置路径)
            记录日志(级别: "info", 内容: "配置已生成并保存")
        }

        return 配置
    }

    /// 获取当前配置的 JSON 字符串
    var 当前配置JSON: String? {
        当前配置?.转换为JSON字符串(格式化: true)
    }

    // MARK: - 统计信息

    /// 获取内核统计信息
    /// 预留：实际应从 sing-box 内核 API 获取
    func 获取统计信息() -> [String: Any] {
        // TODO: 集成 sing-box Go 库后从内核获取真实统计
        return [
            "status": 内核状态.rawValue,
            "version": 内核版本,
            "uptime": 运行时长,
            "inbounds": 当前配置?.inbounds?.count ?? 0,
            "outbounds": 当前配置?.outbounds?.count ?? 0,
            "rules": 当前配置?.route?.rules?.count ?? 0
        ]
    }

    // MARK: - 内核健康检查

    /// 检查内核是否健康
    var 是否健康: Bool {
        内核状态 == .运行中 && 内核运行中
    }

    /// 等待内核启动（最多等待指定秒数）
    func 等待内核启动(超时: TimeInterval = 10.0) -> Bool {
        let 开始时间 = Date()

        while Date().timeIntervalSince(开始时间) < 超时 {
            if 内核状态 == .运行中 {
                return true
            }
            if 内核状态 == .启动失败 || 内核状态 == .配置错误 {
                return false
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        return 内核状态 == .运行中
    }
}
