//
//  Libbox平台接口OC.m
//  NewVPN-Tunnel
//
//  Objective-C 实现，正确重写 openTun 方法
//

#import "Libbox平台接口OC.h"
#import <objc/runtime.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#pragma mark - 网络接口迭代器

/// 网络接口迭代器（实现 LibboxNetworkInterfaceIterator 协议）
@interface 网络接口迭代器 : NSObject <LibboxNetworkInterfaceIterator>
/// 接口列表
@property (nonatomic, strong) NSArray<LibboxNetworkInterface *> *接口列表;
/// 当前索引
@property (nonatomic, assign) NSInteger 当前索引;
@end

@implementation 网络接口迭代器

- (instancetype)initWith接口列表:(NSArray<LibboxNetworkInterface *> *)列表 {
    self = [super init];
    if (self) {
        _接口列表 = 列表;
        _当前索引 = 0;
    }
    return self;
}

- (LibboxNetworkInterface * _Nullable)next {
    if (self.当前索引 < self.接口列表.count) {
        LibboxNetworkInterface *接口 = self.接口列表[self.当前索引];
        self.当前索引 += 1;
        return 接口;
    }
    return nil;
}

@end

@implementation Libbox平台接口OC

/// 当前运行在 Network Extension 中，必须返回 YES
- (BOOL)underNetworkExtension {
    return YES;
}

/// VPN 包含所有网络流量
- (BOOL)includeAllNetworks {
    return YES;
}

/// iOS 没有 procfs，返回 NO
- (BOOL)useProcFS {
    return NO;
}

/// 不使用平台自动检测接口控制
- (BOOL)usePlatformAutoDetectInterfaceControl {
    return NO;
}

/// 清空 DNS 缓存（iOS 由系统管理，空实现）
- (void)clearDNSCache {
}

/// 自动检测接口控制（iOS 不使用，返回 NO）
- (BOOL)autoDetectInterfaceControl:(int32_t)fd error:(NSError * _Nullable * _Nullable)error {
    return NO;
}

/// 查找连接所有者（iOS 不支持，返回 -1）
- (BOOL)findConnectionOwner:(int32_t)ipProtocol sourceAddress:(NSString * _Nullable)sourceAddress sourcePort:(int32_t)sourcePort destinationAddress:(NSString * _Nullable)destinationAddress destinationPort:(int32_t)destinationPort ret0_:(int32_t * _Nullable)ret0_ error:(NSError * _Nullable * _Nullable)error {
    if (ret0_) *ret0_ = -1;
    return NO;
}

/// 根据 UID 获取包名（iOS 不支持，返回空字符串）
- (NSString * _Nonnull)packageNameByUid:(int32_t)uid error:(NSError * _Nullable * _Nullable)error {
    return @"";
}

/// 根据包名获取 UID（iOS 不支持，返回 -1）
- (BOOL)uidByPackageName:(NSString * _Nullable)packageName ret0_:(int32_t * _Nullable)ret0_ error:(NSError * _Nullable * _Nullable)error {
    if (ret0_) *ret0_ = -1;
    return NO;
}

/// 启动默认接口监视器（iOS 由系统管理，返回 YES 表示成功但不实际操作）
- (BOOL)startDefaultInterfaceMonitor:(id<LibboxInterfaceUpdateListener> _Nullable)listener error:(NSError * _Nullable * _Nullable)error {
    return YES;
}

/// 关闭默认接口监视器（iOS 由系统管理，返回 YES 表示成功但不实际操作）
- (BOOL)closeDefaultInterfaceMonitor:(id<LibboxInterfaceUpdateListener> _Nullable)listener error:(NSError * _Nullable * _Nullable)error {
    return YES;
}

/// 获取网络接口列表（使用 ifaddrs 获取系统真实接口）
- (id<LibboxNetworkInterfaceIterator> _Nullable)getInterfaces:(NSError * _Nullable * _Nullable)error {
    struct ifaddrs *接口链表 = NULL;
    if (getifaddrs(&接口链表) != 0) {
        return nil;
    }

    NSMutableArray<LibboxNetworkInterface *> *接口列表 = [NSMutableArray array];
    int32_t 索引 = 0;

    for (struct ifaddrs *当前 = 接口链表; 当前 != NULL; 当前 = 当前->ifa_next) {
        // 跳过无地址的接口
        if (当前->ifa_addr == NULL) continue;

        // 只处理 IPv4 接口
        if (当前->ifa_addr->sa_family != AF_INET) continue;

        NSString *接口名 = [NSString stringWithUTF8String:当前->ifa_name];
        // 跳过回环接口和隧道接口
        if ([接口名 isEqualToString:@"lo0"]) continue;
        if ([接口名 hasPrefix:@"utun"]) continue;
        if ([接口名 hasPrefix:@"ipsec"]) continue;

        struct sockaddr_in *地址 = (struct sockaddr_in *)当前->ifa_addr;
        NSString *IP字符串 = [NSString stringWithUTF8String:inet_ntoa(地址->sin_addr)];

        // 跳过无有效 IP 的接口
        if ([IP字符串 isEqualToString:@"0.0.0.0"]) continue;

        LibboxNetworkInterface *接口 = [[LibboxNetworkInterface alloc] init];
        接口.index = 索引;
        接口.name = 接口名;
        int32_t MTU值 = 1500;
        if (当前->ifa_data != NULL) {
            MTU值 = (int32_t)((struct if_data *)当前->ifa_data)->ifi_mtu;
        }
        接口.mtu = MTU值;
        接口.flags = (int32_t)当前->ifa_flags;
        接口.type = 0; // 0 表示未知类型
        接口.metered = NO;
        // addresses 留空（nil），sing-box 不需要具体地址

        [接口列表 addObject:接口];
        索引 += 1;
    }

    freeifaddrs(接口链表);

    if (接口列表.count == 0) {
        return nil;
    }

    return [[网络接口迭代器 alloc] initWith接口列表:接口列表];
}

/// 读取 WIFI 状态（iOS 不使用，返回 nil）
- (LibboxWIFIState * _Nullable)readWIFIState {
    return nil;
}

/// 发送通知（iOS 不使用，返回 NO）
- (BOOL)sendNotification:(LibboxNotification * _Nullable)notification error:(NSError * _Nullable * _Nullable)error {
    return NO;
}

- (void)writeLog:(NSString * _Nullable)message {
    if (message && self.日志回调) {
        self.日志回调(2, message);
    }
}

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
