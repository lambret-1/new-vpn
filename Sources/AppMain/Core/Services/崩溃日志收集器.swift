//
//  崩溃日志收集器.swift
//  NewVPN
//
//  捕获并存储 APP 崩溃日志，支持查看、导出和清除
//

import Foundation
import UIKit

/// 全局 Signal 处理器（C 函数指针不能捕获 self）
private func 全局Signal处理器(_ 信号: Int32) {
    崩溃日志收集器.共享.处理信号(信号)
    // 恢复默认处理器并重新发送信号，确保 APP 正常退出
    signal(信号, SIG_DFL)
    raise(信号)
}

/// 全局异常处理器（C 函数指针不能捕获 self）
private func 全局异常处理器(_ 异常: NSException) {
    崩溃日志收集器.共享.处理异常(异常)
    // 调用之前的处理器
    if let 之前 = 崩溃日志收集器.共享.之前的异常处理器 {
        之前(异常)
    }
}

/// 崩溃日志模型
struct 崩溃日志模型: Identifiable, Codable, Hashable {
    /// 唯一标识
    let id: UUID
    /// 崩溃时间
    let 时间: Date
    /// 崩溃名称（异常名称）
    let 名称: String
    /// 崩溃原因
    let 原因: String
    /// 调用栈信息
    let 调用栈: [String]
    /// 设备信息
    let 设备信息: 设备信息模型
    /// APP 版本
    let app版本: String
    /// iOS 版本
    let iOS版本: String

    /// 时间显示文字
    var 时间显示: String {
        let 格式器 = DateFormatter()
        格式器.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return 格式器.string(from: 时间)
    }
}

/// 设备信息模型
struct 设备信息模型: Codable, Hashable {
    /// 设备型号
    let 型号: String
    /// 系统版本
    let 系统版本: String
    /// 内存总量（字节）
    let 内存总量: UInt64
    /// 磁盘总量（字节）
    let 磁盘总量: UInt64
    /// 是否越狱
    let 是否越狱: Bool
}

/// 崩溃日志收集器：捕获 NSException 和 Signal 崩溃
final class 崩溃日志收集器 {
    /// 共享单例
    static let 共享 = 崩溃日志收集器()

    /// 崩溃日志存储键
    private let 存储键 = "crashLogs"
    /// App Group UserDefaults
    private var 共享默认: UserDefaults? {
        UserDefaults(suiteName: "group.com.newvpn.app")
    }

    /// 最大保存崩溃日志数量
    private let 最大数量 = 50

    /// 之前的异常处理器
    var 之前的异常处理器: NSUncaughtExceptionHandler?
    /// 之前的 Signal 处理器
    private var 之前的Signal处理器: [Int32: sig_t] = [:]

    /// 私有初始化
    private init() {}

    // MARK: - 开始/停止捕获

    /// 开始捕获崩溃日志
    func 开始捕获() {
        // 保存之前的处理器
        之前的异常处理器 = NSGetUncaughtExceptionHandler()

        // 设置异常处理器
        NSSetUncaughtExceptionHandler(全局异常处理器)

        // 设置 Signal 处理器
        let 信号列表: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE, SIGTRAP]
        for 信号 in 信号列表 {
            之前的Signal处理器[信号] = signal(信号, 全局Signal处理器)
        }
    }

    /// 停止捕获崩溃日志（恢复之前的处理器）
    func 停止捕获() {
        // 恢复默认异常处理器
        NSSetUncaughtExceptionHandler(nil)
        for (信号, 处理器) in 之前的Signal处理器 {
            signal(信号, 处理器)
        }
    }

    // MARK: - 处理崩溃

    /// 处理 NSException
    func 处理异常(_ 异常: NSException) {
        let 崩溃日志 = 崩溃日志模型(
            id: UUID(),
            时间: Date(),
            名称: 异常.name.rawValue,
            原因: 异常.reason ?? "未知原因",
            调用栈: 异常.callStackSymbols,
            设备信息: 获取设备信息(),
            app版本: 获取APP版本(),
            iOS版本: UIDevice.current.systemVersion
        )
        保存崩溃日志(崩溃日志)
    }

    /// 处理 Signal
    func 处理信号(_ 信号: Int32) {
        let 信号名称: String
        switch 信号 {
        case SIGABRT: 信号名称 = "SIGABRT (程序中止)"
        case SIGILL: 信号名称 = "SIGILL (非法指令)"
        case SIGSEGV: 信号名称 = "SIGSEGV (段错误)"
        case SIGFPE: 信号名称 = "SIGFPE (浮点异常)"
        case SIGBUS: 信号名称 = "SIGBUS (总线错误)"
        case SIGPIPE: 信号名称 = "SIGPIPE (管道破裂)"
        case SIGTRAP: 信号名称 = "SIGTRAP (陷阱)"
        default: 信号名称 = "Signal \(信号)"
        }

        let 崩溃日志 = 崩溃日志模型(
            id: UUID(),
            时间: Date(),
            名称: 信号名称,
            原因: "收到信号 \(信号)，程序异常终止",
            调用栈: Thread.callStackSymbols,
            设备信息: 获取设备信息(),
            app版本: 获取APP版本(),
            iOS版本: UIDevice.current.systemVersion
        )
        保存崩溃日志(崩溃日志)
    }

    // MARK: - 存储管理

    /// 保存崩溃日志
    private func 保存崩溃日志(_ 日志: 崩溃日志模型) {
        guard let 共享默认 = 共享默认 else { return }

        var 日志列表 = 读取所有崩溃日志()
        日志列表.insert(日志, at: 0)

        // 限制最大数量
        if 日志列表.count > 最大数量 {
            日志列表 = Array(日志列表.prefix(最大数量))
        }

        if let 数据 = try? JSONEncoder().encode(日志列表) {
            共享默认.set(数据, forKey: 存储键)
            共享默认.synchronize()
        }
    }

    /// 读取所有崩溃日志
    func 读取所有崩溃日志() -> [崩溃日志模型] {
        guard let 共享默认 = 共享默认,
              let 数据 = 共享默认.data(forKey: 存储键),
              let 日志列表 = try? JSONDecoder().decode([崩溃日志模型].self, from: 数据) else {
            return []
        }
        return 日志列表
    }

    /// 清除所有崩溃日志
    func 清除所有崩溃日志() {
        guard let 共享默认 = 共享默认 else { return }
        共享默认.removeObject(forKey: 存储键)
        共享默认.synchronize()
    }

    /// 删除指定崩溃日志
    func 删除崩溃日志(_ id: UUID) {
        var 日志列表 = 读取所有崩溃日志()
        日志列表.removeAll { $0.id == id }
        guard let 共享默认 = 共享默认,
              let 数据 = try? JSONEncoder().encode(日志列表) else { return }
        共享默认.set(数据, forKey: 存储键)
        共享默认.synchronize()
    }

    /// 导出崩溃日志为文本
    func 导出崩溃日志(_ 日志: 崩溃日志模型) -> String {
        var 文本 = ""
        文本 += "===== NewVPN 崩溃日志报告 =====\n\n"
        文本 += "崩溃时间：\(日志.时间显示)\n"
        文本 += "崩溃名称：\(日志.名称)\n"
        文本 += "崩溃原因：\(日志.原因)\n"
        文本 += "APP 版本：\(日志.app版本)\n"
        文本 += "iOS 版本：\(日志.iOS版本)\n"
        文本 += "设备型号：\(日志.设备信息.型号)\n"
        文本 += "内存总量：\(字节格式化(日志.设备信息.内存总量))\n"
        文本 += "磁盘总量：\(字节格式化(日志.设备信息.磁盘总量))\n"
        文本 += "是否越狱：\(日志.设备信息.是否越狱 ? "是" : "否")\n\n"
        文本 += "===== 调用栈 =====\n"
        for (索引, 栈帧) in 日志.调用栈.enumerated() {
            文本 += "\(索引): \(栈帧)\n"
        }
        文本 += "\n===== 报告结束 =====\n"
        return 文本
    }

    // MARK: - 辅助方法

    /// 获取设备信息
    private func 获取设备信息() -> 设备信息模型 {
        let 设备 = UIDevice.current
        let 内存 = ProcessInfo.processInfo.physicalMemory

        // 获取磁盘总容量
        let 磁盘: UInt64
        if let 资源值 = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeTotalCapacityKey]),
           let 容量 = 资源值.volumeTotalCapacity {
            磁盘 = UInt64(容量)
        } else {
            磁盘 = 0
        }

        // 简单越狱检测
        let 是否越狱 = FileManager.default.fileExists(atPath: "/Applications/Cydia.app") ||
            FileManager.default.fileExists(atPath: "/private/var/lib/apt/") ||
            FileManager.default.fileExists(atPath: "/usr/sbin/sshd")

        return 设备信息模型(
            型号: 设备.model,
            系统版本: 设备.systemVersion,
            内存总量: 内存,
            磁盘总量: 磁盘,
            是否越狱: 是否越狱
        )
    }

    /// 获取 APP 版本
    private func 获取APP版本() -> String {
        let 版本 = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        let 构建 = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"
        return "\(版本) (\(构建))"
    }

    /// 字节格式化
    private func 字节格式化(_ 字节: UInt64) -> String {
        if 字节 < 1024 {
            return "\(字节) B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.1f KB", Double(字节) / 1024)
        } else if 字节 < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(字节) / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", Double(字节) / (1024 * 1024 * 1024))
        }
    }
}
