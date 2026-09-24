//
//  Libbox平台接口OC.m
//  NewVPN-Tunnel
//
//  Objective-C 实现，正确重写 openTun 方法
//

#import "Libbox平台接口OC.h"

@implementation Libbox平台接口OC

- (BOOL)underNetworkExtension {
    return YES;
}

- (void)writeLog:(NSString * _Nullable)message {
    if (message && self.日志回调) {
        self.日志回调(2, message);
    }
}

- (BOOL)includeAllNetworks {
    return YES;
}

- (BOOL)useProcFS {
    return NO;
}

- (BOOL)usePlatformAutoDetectControl {
    return NO;
}

- (void)clearDNSCache {
}

/// 重写 openTun，返回 packetFlow 的文件描述符
/// 这是 sing-box 内核能读写系统 VPN 数据包的关键
- (BOOL)openTun:(id<LibboxTunOptions> _Nullable)options ret0_:(int32_t * _Nullable)ret0_ error:(NSError * _Nullable * _Nullable)error {
    if (self.tun文件描述符 < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.newvpn.tunnel" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"TUN 文件描述符无效"}];
        }
        return NO;
    }
    if (ret0_) {
        *ret0_ = self.tun文件描述符;
    }
    return YES;
}

@end
