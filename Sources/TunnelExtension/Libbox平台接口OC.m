//
//  Libbox平台接口OC.m
//  NewVPN-Tunnel
//
//  Objective-C 实现，正确重写 openTun 方法
//

#import "Libbox平台接口OC.h"
#import <objc/runtime.h>

@implementation Libbox平台接口OC

// 暂时注释掉 underNetworkExtension，使用默认值，排查是否导致 LibboxNewService 崩溃
// - (BOOL)underNetworkExtension {
//     return YES;
// }

- (void)writeLog:(NSString * _Nullable)message {
    if (message && self.日志回调) {
        self.日志回调(2, message);
    }
}

// 暂时注释掉以下方法，使用默认值，排查是否导致 LibboxNewService 崩溃
// - (BOOL)includeAllNetworks {
//     return YES;
// }
//
// - (BOOL)useProcFS {
//     return NO;
// }
//
// - (BOOL)usePlatformAutoDetectControl {
//     return NO;
// }
//
// - (void)clearDNSCache {
// }

/// 重写 openTun，返回 packetFlow 的文件描述符
/// 这是 sing-box 内核能读写系统 VPN 数据包的关键
- (BOOL)openTun:(id<LibboxTunOptions> _Nullable)options ret0_:(int32_t * _Nullable)ret0_ error:(NSError * _Nullable * _Nullable)error {
    if (self.日志回调) {
        self.日志回调(2, [NSString stringWithFormat:@"openTun 被调用，tunfd=%d", self.tun文件描述符]);
    }
    if (self.tun文件描述符 < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.newvpn.tunnel" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"TUN 文件描述符无效"}];
        }
        return NO;
    }
    if (ret0_) {
        *ret0_ = self.tun文件描述符;
    }
    if (self.日志回调) {
        self.日志回调(2, [NSString stringWithFormat:@"openTun 返回 fd=%d", self.tun文件描述符]);
    }
    return YES;
}

#pragma mark - 安全获取文件描述符

+ (int32_t)安全获取文件描述符:(id)packetFlow error:(NSError **)error {
    NSMutableString *调试信息 = [NSMutableString string];
    Class 类 = [packetFlow class];

    // 枚举所有属性（包括父类）
    [调试信息 appendFormat:@"类名=%@; ", NSStringFromClass(类)];
    unsigned int 属性数量 = 0;
    objc_property_t *属性列表 = class_copyPropertyList(类, &属性数量);
    NSMutableArray *属性名列表 = [NSMutableArray array];
    for (unsigned int i = 0; i < 属性数量; i++) {
        const char *属性名 = property_getName(属性列表[i]);
        NSString *名字 = [NSString stringWithUTF8String:属性名];
        [属性名列表 addObject:名字];
    }
    free(属性列表);
    [调试信息 appendFormat:@"属性列表=%@; ", 属性名列表];

    // 枚举所有方法
    unsigned int 方法数量 = 0;
    Method *方法列表 = class_copyMethodList(类, &方法数量);
    NSMutableArray *方法名列表 = [NSMutableArray array];
    for (unsigned int i = 0; i < 方法数量; i++) {
        SEL 方法名 = method_getName(方法列表[i]);
        [方法名列表 addObject:NSStringFromSelector(方法名)];
    }
    free(方法列表);
    [调试信息 appendFormat:@"方法列表=%@; ", 方法名列表];

    // 尝试所有属性中包含 fd/socket/file/desc 的
    for (NSString *属性名 in 属性名列表) {
        NSString *小写名 = [属性名 lowercaseString];
        if ([小写名 containsString:@"fd"] || [小写名 containsString:@"socket"] ||
            [小写名 containsString:@"file"] || [小写名 containsString:@"desc"] ||
            [小写名 containsString:@"tun"] || [小写名 containsString:@"interface"]) {
            @try {
                id 值 = [packetFlow valueForKey:属性名];
                if ([值 isKindOfClass:[NSNumber class]]) {
                    int32_t fd = [(NSNumber *)值 intValue];
                    [调试信息 appendFormat:@"%@=%d; ", 属性名, fd];
                    if (fd > 2) {
                        if (error) *error = nil;
                        return fd;
                    }
                } else {
                    [调试信息 appendFormat:@"%@=%@; ", 属性名, 值];
                }
            } @catch (NSException *异常) {
                [调试信息 appendFormat:@"%@=异常; ", 属性名];
            }
        }
    }

    // 尝试所有方法中包含 fd/socket/file/desc 的
    for (NSString *方法名 in 方法名列表) {
        NSString *小写名 = [方法名 lowercaseString];
        if (([小写名 containsString:@"fd"] || [小写名 containsString:@"socket"] ||
             [小写名 containsString:@"file"] || [小写名 containsString:@"desc"]) &&
            ![方法名 containsString:@":"]) {
            SEL 选择子 = NSSelectorFromString(方法名);
            if ([packetFlow respondsToSelector:选择子]) {
                @try {
                    int (*函数指针)(id, SEL) = (int (*)(id, SEL))[packetFlow methodForSelector:选择子];
                    int fd = 函数指针(packetFlow, 选择子);
                    [调试信息 appendFormat:@"方法%@=%d; ", 方法名, fd];
                    if (fd > 2) {
                        if (error) *error = nil;
                        return fd;
                    }
                } @catch (NSException *异常) {
                    [调试信息 appendFormat:@"方法%@=异常; ", 方法名];
                }
            }
        }
    }

    if (error) {
        *error = [NSError errorWithDomain:@"com.newvpn.tunnel" code:-2
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"未找到有效 TUN 文件描述符。%@", 调试信息]}];
    }
    return -1;
}

@end
