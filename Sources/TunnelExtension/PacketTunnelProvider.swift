//
//  PacketTunnelProvider.swift
//  NewVPN-Tunnel
//
//  PacketTunnel 扩展入口：管理隧道生命周期
//  一期为占位骨架，后续接入 sing-box 内核
//

import NetworkExtension
import os

/// VPN 隧道提供者：负责启动、停止隧道，运行 sing-box 内核
class PacketTunnelProvider: NEPacketTunnelProvider {
    /// 日志记录器
    private let 日志 = Logger(subsystem: "com.newvpn.tunnel", category: "隧道")

    /// 隧道启动完成回调
    override func startTunnel(options: [String: NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        // 一期占位：直接回调成功，后续在此启动 sing-box 内核
        日志.info("隧道启动（占位实现）")
        completionHandler(nil)
    }

    /// 隧道停止完成回调
    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        // 一期占位：直接回调完成，后续在此停止 sing-box 内核
        日志.info("隧道停止（占位实现），原因：\(reason.rawValue)")
        completionHandler()
    }
}
