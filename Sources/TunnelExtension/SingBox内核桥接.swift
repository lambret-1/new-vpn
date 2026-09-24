//
//  SingBox内核桥接.swift
//  NewVPN-Tunnel
//
//  sing-box 内核 Swift 桥接层
//  封装 libbox Objective-C API，负责内核的启动、停止、重载和统计
//

import Foundation
import Libbox

// MARK: - 平台接口实现

/// libbox 平台接口实现
/// 实现 LibboxPlatformInterface 协议，为 sing-box 提供平台相关功能
final class Libbox平台接口: NSObject, LibboxPlatformInterface {
    /// 日志回调
    var 日志回调: ((_ 级别: Int, _ 内容: String) -> Void)?

    /// TUN 文件描述符（由 PacketTunnelProvider 设置）
    var tun文件描述符: Int32 = -1

    /// 是否在 Network Extension 中运行
    func underNetworkExtension() -> Bool {
        true
    }

    /// 写日志
    func writeLog(_ message: String?) {
        guard let 消息 = message else { return }
        日志回调?(2, 消息)
    }

    /// 打开 TUN 接口，返回文件描述符
    func openTun(_ options: LibboxTunOptions?, ret0_: UnsafeMutablePointer<Int32>?, error: NSErrorPointer) -> Bool {
        guard tun文件描述符 >= 0 else {
            日志回调?(4, "TUN 文件描述符无效")
            return false
        }
        ret0_?.pointee = tun文件描述符
        日志回调?(2, "TUN 接口已打开，文件描述符：\(tun文件描述符)")
        return true
    }

    /// 是否使用平台自动检测接口控制
    func usePlatformAutoDetectInterfaceControl() -> Bool {
        false
    }

    /// 自动检测接口控制
    func autoDetectInterfaceControl(_ fd: Int32, error: NSErrorPointer) -> Bool {
        true
    }

    /// 清除 DNS 缓存
    func clearDNSCache() {
        日志回调?(2, "清除 DNS 缓存")
    }

    /// 包含所有网络
    func includeAllNetworks() -> Bool {
        true
    }

    /// 使用 procfs
    func useProcFS() -> Bool {
        false
    }

    /// 关闭默认接口监控
    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListener?, error: NSErrorPointer) -> Bool {
        true
    }

    /// 启动默认接口监控
    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListener?, error: NSErrorPointer) -> Bool {
        true
    }

    /// 获取网络接口列表
    func getInterfaces(_ error: NSErrorPointer) -> LibboxNetworkInterfaceIterator? {
        nil
    }

    /// 查找连接所有者
    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32, destinationAddress: String?, destinationPort: Int32, ret0_: UnsafeMutablePointer<Int32>?, error: NSErrorPointer) -> Bool {
        ret0_?.pointee = -1
        return true
    }

    /// 根据 UID 获取包名
    func packageName(byUid: Int32, error: NSErrorPointer) -> String {
        ""
    }

    /// 根据包名获取 UID
    func uid(byPackageName: String?, ret0_: UnsafeMutablePointer<Int32>?, error: NSErrorPointer) -> Bool {
        ret0_?.pointee = -1
        return true
    }

    /// 读取 WiFi 状态
    func readWIFIState() -> LibboxWIFIState? {
        nil
    }

    /// 发送通知
    func sendNotification(_ notification: LibboxNotification?, error: NSErrorPointer) -> Bool {
        true
    }
}

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

    /// 平台接口
    private let 平台接口 = Libbox平台接口()

    /// 是否已初始化
    private var 已初始化 = false

    /// 私有初始化
    private init() {
        平台接口.日志回调 = { [weak self] 级别, 内容 in
            self?.日志回调?(级别, 内容)
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

        日志回调?(2, "正在启动 sing-box 内核...")

        // 设置 TUN 文件描述符
        平台接口.tun文件描述符 = tun文件描述符

        // 创建服务
        var 错误: NSError?
        guard let 新服务 = LibboxNewService(配置内容, 平台接口, &错误) else {
            日志回调?(4, "创建 sing-box 服务失败：\(错误?.localizedDescription ?? "未知错误")")
            return false
        }

        服务 = 新服务

        // 启动服务
        var 启动错误: NSError?
        let 启动成功 = 新服务.start(&启动错误)

        if 启动成功 {
            是否运行中 = true
            日志回调?(2, "sing-box 内核启动成功")
            return true
        } else {
            日志回调?(4, "sing-box 内核启动失败：\(启动错误?.localizedDescription ?? "未知错误")")
            服务 = nil
            return false
        }
    }

    // MARK: - 停止内核

    /// 停止 sing-box 内核
    func 停止内核() {
        guard 是否运行中, let 服务 = 服务 else { return }

        日志回调?(2, "正在停止 sing-box 内核")

        var 错误: NSError?
        _ = 服务.close(&错误)

        if let 错误 = 错误 {
            日志回调?(4, "停止 sing-box 内核出错：\(错误.localizedDescription)")
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
}
