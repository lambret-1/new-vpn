//
//  SingBox内核桥接.swift
//  NewVPN-Tunnel
//
//  sing-box 内核 Swift 桥接层
//  封装 libbox C API，提供 Swift 调用接口
//

import Foundation

// MARK: - sing-box 内核桥接

/// sing-box 内核桥接类
/// 封装 libbox C API，负责内核的启动、停止、重载和统计
final class SingBox内核桥接 {
    /// 共享单例
    static let 共享 = SingBox内核桥接()

    /// 内核是否运行中
    private(set) var 是否运行中 = false

    /// 日志回调
    var 日志回调: ((_ 级别: Int, _ 内容: String) -> Void)?

    /// 私有初始化
    private init() {}

    // MARK: - 启动内核

    /// 启动 sing-box 内核
    /// - Parameters:
    ///   - 配置路径: 配置文件路径
    ///   - 工作目录: 工作目录
    /// - Returns: 是否启动成功
    func 启动内核(配置路径: String, 工作目录: String) -> Bool {
        guard !是否运行中 else {
            日志回调?(2, "sing-box 内核已在运行中")
            return true
        }

        日志回调?(2, "正在启动 sing-box 内核，配置：\(配置路径)")

        // 设置日志回调（使用全局函数指针）
        SingBox内核桥接.当前实例 = self

        let 结果 = libbox_start_service(配置路径, 工作目录) { 级别, 消息 in
            guard let 消息 = 消息 else { return }
            let 内容 = String(cString: 消息)
            SingBox内核桥接.当前实例?.日志回调?(Int(级别), 内容)
        }

        if 结果 == 0 {
            是否运行中 = true
            日志回调?(2, "sing-box 内核启动成功")
            return true
        } else {
            日志回调?(4, "sing-box 内核启动失败，错误码：\(结果)")
            return false
        }
    }

    // MARK: - 停止内核

    /// 停止 sing-box 内核
    func 停止内核() {
        guard 是否运行中 else { return }

        日志回调?(2, "正在停止 sing-box 内核")
        libbox_stop_service()
        是否运行中 = false
        日志回调?(2, "sing-box 内核已停止")
    }

    // MARK: - 重载配置

    /// 重新加载配置
    /// - Parameter 配置路径: 配置文件路径
    /// - Returns: 是否重载成功
    func 重载配置(配置路径: String) -> Bool {
        guard 是否运行中 else {
            日志回调?(4, "内核未运行，无法重载配置")
            return false
        }

        日志回调?(2, "正在重新加载 sing-box 配置")
        let 结果 = libbox_reload_service(配置路径)

        if 结果 == 0 {
            日志回调?(2, "配置重新加载成功")
            return true
        } else {
            日志回调?(4, "配置重新加载失败，错误码：\(结果)")
            return false
        }
    }

    // MARK: - 统计信息

    /// 获取上行字节数
    var 上行字节: UInt64 {
        guard 是否运行中 else { return 0 }
        return UInt64(libbox_get_upload_bytes())
    }

    /// 获取下行字节数
    var 下行字节: UInt64 {
        guard 是否运行中 else { return 0 }
        return UInt64(libbox_get_download_bytes())
    }

    /// 重置统计信息
    func 重置统计() {
        libbox_reset_stats()
    }

    // MARK: - 版本信息

    /// 获取 sing-box 版本
    var 版本: String {
        guard let 版本指针 = libbox_version() else { return "未知" }
        return String(cString: 版本指针)
    }

    // MARK: - 全局实例（用于 C 回调）

    /// 当前实例（用于 C 函数回调）
    private static var 当前实例: SingBox内核桥接?
}
