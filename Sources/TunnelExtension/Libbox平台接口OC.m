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

#pragma mark - 安全获取文件描述符

+ (int32_t)安全获取文件描述符:(id)packetFlow error:(NSError **)error {
    // 尝试多种属性名获取文件描述符
    NSArray *属性列表 = @[@"fileDescriptor", @"socket", @"_fileDescriptor", @"_socket", @"fileHandle"];

    for (NSString *属性名 in 属性列表) {
        @try {
            id 值 = [packetFlow valueForKey:属性名];
            if ([值 isKindOfClass:[NSNumber class]]) {
                return [(NSNumber *)值 intValue];
            }
        } @catch (NSException *异常) {
            // 继续尝试下一个属性名
        }
    }

    // 尝试 performSelector 方式
    NSArray *选择子列表 = @[@"fileDescriptor", @"socket", @"fileDescriptor"];
    for (NSString *选择子名 in 选择子列表) {
        SEL 选择子 = NSSelectorFromString(选择子名);
        if ([packetFlow respondsToSelector:选择子]) {
            @try {
                int (*函数指针)(id, SEL) = (int (*)(id, SEL))[packetFlow methodForSelector:选择子];
                return 函数指针(packetFlow, 选择子);
            } @catch (NSException *异常) {
                // 继续尝试
            }
        }
    }

    if (error) {
        *error = [NSError errorWithDomain:@"com.newvpn.tunnel" code:-2
                                 userInfo:@{NSLocalizedDescriptionKey: @"所有方式均无法获取 packetFlow 文件描述符"}];
    }
    return -1;
}

@end
