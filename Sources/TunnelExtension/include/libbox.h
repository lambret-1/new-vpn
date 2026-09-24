//
//  libbox.h
//  NewVPN-Tunnel
//
//  sing-box 内核 C 接口定义
//  通过 gomobile 编译的 libbox 静态库暴露的 API
//

#ifndef libbox_h
#define libbox_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - 日志回调

/// 日志级别
typedef NS_ENUM(int, LibboxLogLevel) {
    LibboxLogLevelTrace = 0,
    LibboxLogLevelDebug = 1,
    LibboxLogLevelInfo = 2,
    LibboxLogLevelWarn = 3,
    LibboxLogLevelError = 4,
    LibboxLogLevelFatal = 5
};

/// 日志回调函数类型
typedef void (*LibboxLogCallback)(int level, const char *message);

// MARK: - 平台接口

/// 平台接口结构体（用于回调到 Swift）
typedef struct {
    /// 写日志
    void (*writeLog)(int level, const char *message);
    /// 获取空闲内存
    int64_t (*freeMemory)();
    /// 使用内存
    void (*useMemory)(int64_t bytes);
} LibboxPlatformInterface;

// MARK: - 命令客户端

/// 命令客户端不透明指针
typedef void* LibboxCommandClient;

/// 创建独立命令客户端
/// - Parameter interface: 平台接口
/// - Returns: 命令客户端指针，失败返回 NULL
LibboxCommandClient libbox_new_standalone_command_client(LibboxPlatformInterface interface);

/// 关闭命令客户端
/// - Parameter client: 命令客户端指针
void libbox_command_client_close(LibboxCommandClient client);

// MARK: - 服务管理

/// 启动 sing-box 服务
/// - Parameter configPath: 配置文件路径
/// - Parameter workingDir: 工作目录
/// - Parameter logCallback: 日志回调
/// - Returns: 0 表示成功，非 0 表示失败
int libbox_start_service(const char *configPath, const char *workingDir, LibboxLogCallback logCallback);

/// 停止 sing-box 服务
void libbox_stop_service(void);

/// 重新加载配置
/// - Parameter configPath: 配置文件路径
/// - Returns: 0 表示成功，非 0 表示失败
int libbox_reload_service(const char *configPath);

/// 检查服务是否运行中
/// - Returns: true 表示运行中
bool libbox_service_running(void);

// MARK: - 统计信息

/// 获取上行字节数
/// - Returns: 上行字节数
int64_t libbox_get_upload_bytes(void);

/// 获取下行字节数
/// - Returns: 下行字节数
int64_t libbox_get_download_bytes(void);

/// 重置统计信息
void libbox_reset_stats(void);

// MARK: - 版本信息

/// 获取 sing-box 版本
/// - Returns: 版本字符串（调用者负责释放）
const char *libbox_version(void);

#ifdef __cplusplus
}
#endif

#endif /* libbox_h */
