//
//  Libbox平台接口OC.h
//  NewVPN-Tunnel
//
//  Objective-C 子类，正确重写 openTun 方法
//  Swift 中方法签名映射复杂，用 OC 实现更可靠
//

#import <Foundation/Foundation.h>
#import <Libbox/Libbox.h>

NS_ASSUME_NONNULL_BEGIN

/// libbox 平台接口 OC 实现
/// 继承 LibboxPlatformInterface，重写 openTun 返回 packetFlow 文件描述符
@interface Libbox平台接口OC : LibboxPlatformInterface

/// TUN 文件描述符（由 PacketTunnelProvider 设置）
@property (nonatomic, assign) int32_t tun文件描述符;

/// 日志回调
@property (nonatomic, copy, nullable) void (^日志回调)(NSInteger 级别, NSString *内容);

@end

NS_ASSUME_NONNULL_END
