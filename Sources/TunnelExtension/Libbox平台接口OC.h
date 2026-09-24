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
/// 直接实现 LibboxPlatformInterface 协议（不继承 gobind 生成的类，避免引用计数崩溃）
@interface Libbox平台接口OC : NSObject <LibboxPlatformInterface>

/// TUN 文件描述符（由 PacketTunnelProvider 设置）
@property (nonatomic, assign) int32_t tun文件描述符;

/// 日志回调
@property (nonatomic, copy, nullable) void (^日志回调)(NSInteger 级别, NSString *内容);

/// 安全获取 packetFlow 的文件描述符（@try/@catch 防止 KVC 崩溃）
/// @param packetFlow NEPacketTunnelFlow 实例
/// @return 文件描述符，失败返回 -1，错误信息通过 error 参数返回
+ (int32_t)安全获取文件描述符:(id)packetFlow error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
