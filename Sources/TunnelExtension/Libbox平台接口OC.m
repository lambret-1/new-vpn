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
#include <sys/socket.h>

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

#pragma mark - 平台接口实现

/// 类扩展：声明内部辅助方法
@interface Libbox平台接口OC ()
/// 创建 LibboxNetworkInterface 对象
- (LibboxNetworkInterface *)创建接口对象:(NSDictionary *)信息;
/// 获取默认物理网卡接口索引
- (int)获取默认接口索引;
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

/// 使用平台自动检测接口控制（将出站 socket 绑定到物理网卡，排除 VPN 路由）
- (BOOL)usePlatformAutoDetectInterfaceControl {
    return YES;
}

/// 清空 DNS 缓存（iOS 由系统管理，空实现）
- (void)clearDNSCache {
}

/// 自动检测接口控制：将出站 socket 绑定到物理网卡，避免被 VPN 路由回环
/// 这是 iOS Network Extension 中直连流量能正常发出的关键
- (BOOL)autoDetectInterfaceControl:(int32_t)fd error:(NSError * _Nullable * _Nullable)error {
    if (fd < 0) {
        // fd 无效时返回 YES，避免 sing-box 因接口控制失败而中断连接
        return YES;
    }

    // 每次都获取最新的物理网卡接口索引（不缓存，避免网络切换后使用过期索引）
    int 接口索引 = [self 获取默认接口索引];
    if (接口索引 <= 0) {
        // 未找到可用物理网卡时返回 YES，让 socket 使用系统默认路由
        return YES;
    }

    // 绑定 socket 到物理网卡（IPv4）
    int 结果 = setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &接口索引, sizeof(接口索引));
    if (结果 != 0) {
        // 绑定 IPv4 失败，尝试 IPv6
        setsockopt(fd, IPPROTO_IPV6, IPV6_BOUND_IF, &接口索引, sizeof(接口索引));
    }

    // 无论绑定成功与否都返回 YES，避免 sing-box 因接口控制失败而中断连接
    // 绑定失败时 socket 回退到系统默认路由，仍可正常工作
    return YES;
}

/// 获取默认物理网卡接口索引（每次实时获取，不缓存）
- (int)获取默认接口索引 {
    NSError *错误 = nil;
    id<LibboxNetworkInterfaceIterator> 迭代器 = [self getInterfaces:&错误];
    if (迭代器) {
        LibboxNetworkInterface *第一个接口 = [迭代器 next];
        if (第一个接口 && 第一个接口.index > 0) {
            return (int)第一个接口.index;
        }
    }
    return 0;
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

/// 默认接口更新监听器（保存引用，网络切换时通知 sing-box）
static id<LibboxInterfaceUpdateListener> _默认接口监听器 = nil;

/// 通过运行时探测协议方法并调用默认接口更新
static void 通知默认接口更新(id<LibboxInterfaceUpdateListener> listener, int32_t 接口索引) {
    if (!listener) return;

    // 枚举协议方法，找到接受单个 int 参数的方法并调用
    unsigned int 方法数量 = 0;
    struct objc_method_description *方法列表 = protocol_copyMethodDescriptionList(@protocol(LibboxInterfaceUpdateListener), YES, YES, &方法数量);
    for (unsigned int i = 0; i < 方法数量; i++) {
        SEL 方法名 = 方法列表[i].name;
        NSString *方法名字符串 = NSStringFromSelector(方法名);
        // 查找包含 "interface" 或 "default" 的方法
        if ([方法名字符串.lowercaseString containsString:@"interface"] ||
            [方法名字符串.lowercaseString containsString:@"default"]) {
            if ([listener respondsToSelector:方法名]) {
                // 尝试调用单个 int 参数的方法
                typedef void (*函数指针类型)(id, SEL, int32_t);
                函数指针类型 函数指针 = (函数指针类型)[listener methodForSelector:方法名];
                函数指针(listener, 方法名, 接口索引);
                break;
            }
        }
    }
    free(方法列表);
}

/// 启动默认接口监视器
- (BOOL)startDefaultInterfaceMonitor:(id<LibboxInterfaceUpdateListener> _Nullable)listener error:(NSError * _Nullable * _Nullable)error {
    _默认接口监听器 = listener;

    // 立即通知当前默认接口（通过 getInterfaces 获取第一个可用接口）
    if (listener) {
        NSError *接口错误 = nil;
        id<LibboxNetworkInterfaceIterator> 迭代器 = [self getInterfaces:&接口错误];
        if (迭代器) {
            LibboxNetworkInterface *第一个接口 = [迭代器 next];
            if (第一个接口) {
                通知默认接口更新(listener, 第一个接口.index);
                if (self.日志回调) {
                    self.日志回调(2, [NSString stringWithFormat:@"默认接口监视器已启动，当前默认接口 index=%d name=%@", 第一个接口.index, 第一个接口.name]);
                }
            } else {
                if (self.日志回调) {
                    self.日志回调(3, @"默认接口监视器启动：getInterfaces 返回空列表");
                }
            }
        } else {
            if (self.日志回调) {
                self.日志回调(4, [NSString stringWithFormat:@"默认接口监视器启动：getInterfaces 失败 - %@", 接口错误.localizedDescription]);
            }
        }
    }
    return YES;
}

/// 关闭默认接口监视器
- (BOOL)closeDefaultInterfaceMonitor:(id<LibboxInterfaceUpdateListener> _Nullable)listener error:(NSError * _Nullable * _Nullable)error {
    _默认接口监听器 = nil;
    return YES;
}

/// 获取网络接口列表（使用 ifaddrs 获取系统真实接口，支持 IPv4/IPv6，按接口名分组）
- (id<LibboxNetworkInterfaceIterator> _Nullable)getInterfaces:(NSError * _Nullable * _Nullable)error {
    struct ifaddrs *接口链表 = NULL;
    if (getifaddrs(&接口链表) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.newvpn.tunnel" code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"getifaddrs 调用失败"}];
        }
        return nil;
    }

    // 按接口名分组，收集每个接口的所有地址和属性
    NSMutableDictionary *接口字典 = [NSMutableDictionary dictionary];

    for (struct ifaddrs *当前 = 接口链表; 当前 != NULL; 当前 = 当前->ifa_next) {
        if (当前->ifa_addr == NULL) continue;

        NSString *接口名 = [NSString stringWithUTF8String:当前->ifa_name];
        if (!接口名) continue;

        // 跳过回环、隧道、IPsec 接口（这些不是物理出站接口）
        if ([接口名 isEqualToString:@"lo0"]) continue;
        if ([接口名 hasPrefix:@"utun"]) continue;
        if ([接口名 hasPrefix:@"ipsec"]) continue;
        if ([接口名 hasPrefix:@"tap"]) continue;
        if ([接口名 hasPrefix:@"bridge"]) continue;

        // 只处理 IPv4 和 IPv6
        sa_family_t 地址族 = 当前->ifa_addr->sa_family;
        if (地址族 != AF_INET && 地址族 != AF_INET6) continue;

        // 解析 IP 地址字符串
        char 地址缓冲[INET6_ADDRSTRLEN];
        if (地址族 == AF_INET) {
            struct sockaddr_in *addr = (struct sockaddr_in *)当前->ifa_addr;
            inet_ntop(AF_INET, &addr->sin_addr, 地址缓冲, sizeof(地址缓冲));
        } else {
            struct sockaddr_in6 *addr = (struct sockaddr_in6 *)当前->ifa_addr;
            inet_ntop(AF_INET6, &addr->sin6_addr, 地址缓冲, sizeof(地址缓冲));
        }
        NSString *IP字符串 = [NSString stringWithUTF8String:地址缓冲];

        // 跳过全零地址和链路本地地址（fe80:: 开头的 IPv6）
        if ([IP字符串 isEqualToString:@"0.0.0.0"] || [IP字符串 isEqualToString:@"::"]) continue;
        if ([IP字符串 hasPrefix:@"fe80:"]) continue;

        // 获取或创建接口信息
        NSMutableDictionary *接口信息 = 接口字典[接口名];
        if (!接口信息) {
            // 使用 if_nametoindex 获取真实接口索引（sing-box 绑定 socket 需要真实 ifindex）
            unsigned int 真实索引 = if_nametoindex(当前->ifa_name);
            int32_t MTU值 = 1500;
            if (当前->ifa_data != NULL) {
                MTU值 = (int32_t)((struct if_data *)当前->ifa_data)->ifi_mtu;
                if (MTU值 <= 0) MTU值 = 1500;
            }

            // 判断接口类型
            int32_t 接口类型 = 0; // 0=未知
            if ([接口名 hasPrefix:@"en"]) {
                接口类型 = 1; // 1=以太网/WiFi
            } else if ([接口名 hasPrefix:@"pdp_ip"] || [接口名 hasPrefix:@"cell"] || [接口名 hasPrefix:@"rmnet"]) {
                接口类型 = 2; // 2=蜂窝
            }

            接口信息 = [NSMutableDictionary dictionary];
            接口信息[@"name"] = 接口名;
            接口信息[@"index"] = @(真实索引 > 0 ? 真实索引 : (int32_t)接口字典.count);
            接口信息[@"mtu"] = @(MTU值);
            接口信息[@"flags"] = @((int32_t)当前->ifa_flags);
            接口信息[@"type"] = @(接口类型);
            接口信息[@"addresses"] = [NSMutableArray array];
            接口字典[接口名] = 接口信息;
        }

        // 收集地址
        [(NSMutableArray *)接口信息[@"addresses"] addObject:IP字符串];

        // 更新 flags（取最新的）
        接口信息[@"flags"] = @((int32_t)当前->ifa_flags);
    }

    freeifaddrs(接口链表);

    if (接口字典.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.newvpn.tunnel" code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"未找到可用的物理网络接口"}];
        }
        return nil;
    }

    // 转换为 LibboxNetworkInterface 列表，优先 WiFi（en），其次蜂窝（pdp_ip）
    NSMutableArray<LibboxNetworkInterface *> *接口列表 = [NSMutableArray array];

    // 先加 WiFi 接口
    for (NSString *接口名 in 接口字典) {
        if ([接口名 hasPrefix:@"en"]) {
            [接口列表 addObject:[self 创建接口对象:接口字典[接口名]]];
        }
    }
    // 再加蜂窝接口
    for (NSString *接口名 in 接口字典) {
        if ([接口名 hasPrefix:@"pdp_ip"] || [接口名 hasPrefix:@"cell"]) {
            [接口列表 addObject:[self 创建接口对象:接口字典[接口名]]];
        }
    }
    // 最后加其他接口
    for (NSString *接口名 in 接口字典) {
        if (![接口名 hasPrefix:@"en"] && ![接口名 hasPrefix:@"pdp_ip"] && ![接口名 hasPrefix:@"cell"]) {
            [接口列表 addObject:[self 创建接口对象:接口字典[接口名]]];
        }
    }

    // 记录获取到的接口列表（方便调试 "no available network interface" 问题）
    if (self.日志回调) {
        NSMutableString *接口描述 = [NSMutableString stringWithFormat:@"getInterfaces 获取到 %lu 个接口：", (unsigned long)接口列表.count];
        for (LibboxNetworkInterface *接口 in 接口列表) {
            [接口描述 appendFormat:@" [%@ index=%d type=%d]", 接口.name, 接口.index, 接口.type];
        }
        self.日志回调(2, 接口描述);
    }

    return [[网络接口迭代器 alloc] initWith接口列表:接口列表];
}

/// 创建 LibboxNetworkInterface 对象（辅助方法）
- (LibboxNetworkInterface *)创建接口对象:(NSDictionary *)信息 {
    LibboxNetworkInterface *接口 = [[LibboxNetworkInterface alloc] init];
    接口.index = [信息[@"index"] intValue];
    接口.name = 信息[@"name"];
    接口.mtu = [信息[@"mtu"] intValue];
    接口.flags = [信息[@"flags"] intValue];
    接口.type = [信息[@"type"] intValue];
    接口.metered = NO;
    // addresses 留空：libbox 当前版本不强制要求地址列表，index 和 name 足够用于 socket 绑定
    return 接口;
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
    if (!message || !self.日志回调) return;

    // 根据 sing-box 日志前缀映射级别：TRACE=0, DEBUG=1, INFO=2, WARN=3, ERROR=4, FATAL=5
    int 日志级别 = 2; // 默认信息
    if ([message hasPrefix:@"FATAL"]) {
        日志级别 = 5;
    } else if ([message hasPrefix:@"ERROR"]) {
        日志级别 = 4;
    } else if ([message hasPrefix:@"WARN"]) {
        日志级别 = 3;
    } else if ([message hasPrefix:@"INFO"]) {
        日志级别 = 2;
    } else if ([message hasPrefix:@"DEBUG"]) {
        日志级别 = 1;
    } else if ([message hasPrefix:@"TRACE"]) {
        日志级别 = 0;
    }

    self.日志回调(日志级别, message);
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

    [调试信息 appendFormat:@"类名=%@; ", NSStringFromClass(类)];

    // 方式A：直接尝试已知的私有属性名（NEPacketTunnelFlow 常见内部属性）
    NSArray *已知属性名列表 = @[
        @"_socket", @"socket", @"_fileDescriptor", @"fileDescriptor",
        @"_tunSocket", @"tunSocket", @"_tunFd", @"tunFd",
        @"_utunSocket", @"utunSocket", @"_interfaceSocket",
        @"_nwSocket", @"nwSocket", @"_connectionSocket",
        @"socketDescriptor", @"_socketDescriptor"
    ];
    for (NSString *属性名 in 已知属性名列表) {
        @try {
            id 值 = [packetFlow valueForKey:属性名];
            if ([值 isKindOfClass:[NSNumber class]]) {
                int32_t fd = [(NSNumber *)值 intValue];
                [调试信息 appendFormat:@"直接属性%@=%d; ", 属性名, fd];
                if (fd > 2) {
                    if (error) *error = nil;
                    return fd;
                }
            }
        } @catch (NSException *异常) {
            [调试信息 appendFormat:@"直接属性%@=异常; ", 属性名];
        }
    }

    // 方式B：枚举实例变量（ivar），文件描述符可能不在属性中而在 ivar 中
    unsigned int ivar数量 = 0;
    Ivar *ivar列表 = class_copyIvarList(类, &ivar数量);
    NSMutableArray *ivar名列表 = [NSMutableArray array];
    for (unsigned int i = 0; i < ivar数量; i++) {
        const char *ivar名 = ivar_getName(ivar列表[i]);
        NSString *名字 = [NSString stringWithUTF8String:ivar名];
        [ivar名列表 addObject:名字];
        NSString *小写名 = [名字 lowercaseString];
        if ([小写名 containsString:@"fd"] || [小写名 containsString:@"socket"] ||
            [小写名 containsString:@"file"] || [小写名 containsString:@"desc"] ||
            [小写名 containsString:@"tun"] || [小写名 containsString:@"interface"]) {
            @try {
                id 值 = object_getIvar(packetFlow, ivar列表[i]);
                if ([值 isKindOfClass:[NSNumber class]]) {
                    int32_t fd = [(NSNumber *)值 intValue];
                    [调试信息 appendFormat:@"ivar%@=%d; ", 名字, fd];
                    if (fd > 2) {
                        free(ivar列表);
                        if (error) *error = nil;
                        return fd;
                    }
                }
            } @catch (NSException *异常) {
                [调试信息 appendFormat:@"ivar%@=异常; ", 名字];
            }
        }
    }
    free(ivar列表);
    [调试信息 appendFormat:@"ivar列表=%@; ", ivar名列表];

    // 方式C：枚举所有属性
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

    // 方式D：枚举所有无参数方法
    unsigned int 方法数量 = 0;
    Method *方法列表 = class_copyMethodList(类, &方法数量);
    NSMutableArray *方法名列表 = [NSMutableArray array];
    for (unsigned int i = 0; i < 方法数量; i++) {
        SEL 方法名 = method_getName(方法列表[i]);
        [方法名列表 addObject:NSStringFromSelector(方法名)];
    }
    free(方法列表);
    [调试信息 appendFormat:@"方法列表=%@; ", 方法名列表];

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
