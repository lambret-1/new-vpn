//
//  PacketTunnelProvider.swift
//  NewVPN-Tunnel
//
//  PacketTunnel 扩展入口
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelTunnelProvider {

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // TODO: 启动 sing-box 内核
        completionHandler(nil)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // TODO: 停止 sing-box 内核
        completionHandler()
    }
}
