//
//  SingBox内核桥接.swift
//  NewVPN-Tunnel
//
//  sing-box 内核 Swift 桥接层
//  封装 libbox Objective-C API，负责内核的启动、停止、重载和统计
//

import Foundation
import Libbox

// MARK: - sing-box 内核桥接

/// sing-box 内核桥接类
/// 封装 libbox Objective-C API，负责内核的启动、停止、重载和统计
final class SingBox内核桥接 {
    /// 共享单例
    static let 共享 = SingBox内核桥接()

    /// 内核是否运行中
    private(set) var 是否运行中 = false

    /// 日志回调
    var 日志回调: ((_ 级别: Int, _ 内容: String) -> Void)?

    /// libbox 服务实例
    private var 服务: LibboxBoxService?

    /// 平台接口（OC实现，正确重写openTun）
    private let 平台接口 = Libbox平台接口OC()

    /// 是否已初始化
    private var 已初始化 = false

    // MARK: - 流量统计

    /// 累计上行字节数（从内核同步）
    private(set) var 上行字节: UInt64 = 0
    /// 累计下行字节数（从内核同步）
    private(set) var 下行字节: UInt64 = 0

    /// 私有初始化
    private init() {
        平台接口.日志回调 = { [weak self] 级别, 内容 in
            self?.日志回调?(Int(级别), 内容)
        }
    }

    // MARK: - 初始化

    /// 初始化 libbox 环境
    /// - Parameter 工作目录: 工作目录路径
    func 初始化(工作目录: String) {
        guard !已初始化 else { return }

        let 选项 = LibboxSetupOptions()
        选项.basePath = 工作目录
        选项.workingPath = 工作目录
        选项.tempPath = NSTemporaryDirectory()
        选项.isTVOS = false

        var 错误: NSError?
        let 成功 = LibboxSetup(选项, &错误)

        if 成功 {
            已初始化 = true
            日志回调?(2, "libbox 初始化成功，版本：\(LibboxVersion())")
        } else {
            日志回调?(4, "libbox 初始化失败：\(错误?.localizedDescription ?? "未知错误")")
        }
    }

    // MARK: - 启动内核

    /// 测试用：用 nil 平台接口创建服务（排查平台接口是否导致崩溃）
    /// - Parameter 配置内容: 配置文件内容
    /// - Returns: 是否创建成功
    func 测试创建服务无平台接口(配置内容: String) -> Bool {
        日志回调?(2, "桥接层：测试 nil 平台接口创建服务...")
        var 错误: NSError?
        let 服务 = LibboxNewService(配置内容, nil, &错误)
        if 服务 != nil {
            日志回调?(2, "桥接层：nil 平台接口创建成功")
            // 立即关闭，不保留
            do {
                try 服务?.close()
            } catch {
                日志回调?(3, "桥接层：关闭测试服务失败：\(error.localizedDescription)")
            }
            return true
        } else {
            日志回调?(4, "桥接层：nil 平台接口创建失败，错误：\(错误?.localizedDescription ?? "未知")")
            return false
        }
    }

    /// 启动 sing-box 内核
    /// - Parameters:
    ///   - 配置内容: 配置文件内容（JSON 字符串）
    ///   - tun文件描述符: TUN 接口文件描述符
    /// - Returns: 是否启动成功
    func 启动内核(配置内容: String, tun文件描述符: Int32) -> Bool {
        guard !是否运行中 else {
            日志回调?(2, "sing-box 内核已在运行中")
            return true
        }

        日志回调?(2, "桥接层：开始启动内核，TUN fd=\(tun文件描述符)")

        // 设置 TUN 文件描述符
        平台接口.tun文件描述符 = tun文件描述符
        日志回调?(2, "桥接层：TUN 文件描述符已设置到平台接口")

        // 创建服务
        日志回调?(2, "桥接层：调用 LibboxNewService...")
        var 错误: NSError?
        guard let 新服务 = LibboxNewService(配置内容, 平台接口, &错误) else {
            日志回调?(4, "桥接层：LibboxNewService 返回 nil，错误：\(错误?.localizedDescription ?? "未知")")
            return false
        }
        日志回调?(2, "桥接层：LibboxNewService 成功，服务对象已创建")

        服务 = 新服务

        // 启动服务（Swift 中 start 映射为 throws）
        日志回调?(2, "桥接层：调用 service.start()...")
        do {
            try 新服务.start()
            是否运行中 = true
            日志回调?(2, "桥接层：service.start() 成功，内核运行中")
            return true
        } catch {
            日志回调?(4, "桥接层：service.start() 抛出异常：\(error.localizedDescription)")
            服务 = nil
            return false
        }
    }

    // MARK: - 停止内核

    /// 停止 sing-box 内核
    func 停止内核() {
        guard 是否运行中, let 服务 = 服务 else { return }

        日志回调?(2, "正在停止 sing-box 内核")

        do {
            try 服务.close()
        } catch {
            日志回调?(4, "停止 sing-box 内核出错：\(error.localizedDescription)")
        }

        self.服务 = nil
        是否运行中 = false
        日志回调?(2, "sing-box 内核已停止")
    }

    // MARK: - 重载配置

    /// 重新加载配置
    /// - Parameter 配置内容: 新的配置文件内容
    /// - Returns: 是否重载成功
    func 重载配置(配置内容: String) -> Bool {
        guard 是否运行中 else {
            日志回调?(4, "内核未运行，无法重载配置")
            return false
        }

        日志回调?(2, "正在重新加载 sing-box 配置...")

        // 停止当前服务
        停止内核()

        // 使用新配置启动
        return 启动内核(配置内容: 配置内容, tun文件描述符: 平台接口.tun文件描述符)
    }

    // MARK: - 版本信息

    /// 获取 sing-box 版本
    var 版本: String {
        LibboxVersion()
    }

    // MARK: - 统计信息（从内核服务对象同步）

    /// 从内核服务对象同步流量统计
    /// 通过 Objective-C 运行时探测服务对象的统计属性，兼容不同 libbox 版本
    func 更新统计() {
        guard 是否运行中, let 服务 = 服务 else { return }

        // 尝试通过 KVC 获取上行/下行字节统计
        // libbox 不同版本属性名可能不同，逐一尝试常见命名
        let 上行键名列表 = ["uploadBytes", "upload", "upBytes", "txBytes", "sentBytes"]
        let 下行键名列表 = ["downloadBytes", "download", "downBytes", "rxBytes", "receivedBytes"]

        for 键名 in 上行键名列表 {
            if let 值 = (服务 as AnyObject).value(forKey: 键名) as? NSNumber {
                上行字节 = 值.uint64Value
                break
            }
        }

        for 键名 in 下行键名列表 {
            if let 值 = (服务 as AnyObject).value(forKey: 键名) as? NSNumber {
                下行字节 = 值.uint64Value
                break
            }
        }

        // 尝试调用 stats 方法获取统计字典
        if 服务.responds(to: NSSelectorFromString("stats")) {
            if let 统计 = (服务 as AnyObject).perform(NSSelectorFromString("stats"))?.takeUnretainedValue() as? [String: Any] {
                if let 上行 = 统计["upload"] as? UInt64 { 上行字节 = 上行 }
                if let 下行 = 统计["download"] as? UInt64 { 下行字节 = 下行 }
                if let 上行 = 统计["up"] as? UInt64 { 上行字节 = 上行 }
                if let 下行 = 统计["down"] as? UInt64 { 下行字节 = 下行 }
            }
        }
    }

    /// 重置统计计数
    func 重置统计() {
        上行字节 = 0
        下行字节 = 0
    }
}
