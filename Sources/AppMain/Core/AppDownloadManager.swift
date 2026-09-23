//
//  AppDownloadManager.swift
//  NewVPN
//
//  IPA 下载管理器
//  使用 URLSession 下载，跟踪进度，下载完成后弹出系统分享面板
//  下载文件仅存临时目录，分享面板关闭后自动清理
//

import Foundation
import UIKit

/// IPA 下载管理器
final class AppDownloadManager: NSObject, ObservableObject {
    /// 全局单例
    static let 共享 = AppDownloadManager()

    // MARK: - 发布状态

    /// 下载状态
    @Published var 下载状态: 下载状态 = .空闲
    /// 下载进度（0~1）
    @Published var 进度: Double = 0
    /// 已下载字节数
    @Published var 已下载字节: Int64 = 0
    /// 总字节数
    @Published var 总字节: Int64 = 0
    /// 下载速度（MB/s）
    @Published var 下载速度: Double = 0

    // MARK: - 私有属性

    private var 下载会话: URLSession!
    private var 下载任务: URLSessionDownloadTask?
    private var 开始时间: Date?
    private var 上次统计字节: Int64 = 0
    private var 上次统计时间: Date?
    private var 临时文件URL: URL?
    private var 下载完成回调: ((URL?) -> Void)?

    // MARK: - 初始化

    private override init() {
        super.init()
        let 配置 = URLSessionConfiguration.default
        下载会话 = URLSession(configuration: 配置, delegate: self, delegateQueue: .main)
    }

    // MARK: - 计算属性

    /// 是否可以开始新的下载
    private var 是否可开始下载: Bool {
        switch 下载状态 {
        case .空闲, .已取消:
            return true
        case .下载失败:
            return true
        default:
            return false
        }
    }

    // MARK: - 开始下载

    /// 开始下载 IPA 文件
    /// - Parameters:
    ///   - 下载地址: IPA 下载 URL
    ///   - 完成回调: 下载完成后回调临时文件路径
    func 开始下载(下载地址: String, 完成回调: @escaping (URL?) -> Void) {
        guard 是否可开始下载 else { return }

        guard let url = URL(string: 下载地址) else {
            下载状态 = .下载失败("无效的下载地址")
            return
        }

        self.下载完成回调 = 完成回调
        重置状态()

        下载状态 = .下载中
        开始时间 = Date()
        上次统计时间 = Date()
        上次统计字节 = 0

        let 请求 = URLRequest(url: url)
        下载任务 = 下载会话.downloadTask(with: 请求)
        下载任务?.resume()
    }

    // MARK: - 取消下载

    /// 取消下载
    func 取消下载() {
        下载任务?.cancel()
        下载任务 = nil
        下载状态 = .已取消
        清理临时文件()
    }

    // MARK: - 重置状态

    private func 重置状态() {
        进度 = 0
        已下载字节 = 0
        总字节 = 0
        下载速度 = 0
        临时文件URL = nil
    }

    // MARK: - 清理临时文件

    /// 清理临时下载文件
    func 清理临时文件() {
        if let url = 临时文件URL {
            try? FileManager.default.removeItem(at: url)
            临时文件URL = nil
        }
    }

    // MARK: - 弹出分享面板

    /// 下载完成后弹出 iOS 系统分享面板
    /// - Parameter 文件URL: 临时 IPA 文件路径
    func 弹出分享面板(文件URL: URL) {
        let 分享控制器 = UIActivityViewController(
            activityItems: [文件URL],
            applicationActivities: nil
        )

        // 排除不需要的分享类型
        分享控制器.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .copyToPasteboard
        ]

        // 获取最顶层的视图控制器（处理 sheet 等场景）
        guard let 顶层控制器 = 获取最顶层视图控制器() else {
            return
        }

        // iPad 适配：设置 popover 来源
        if let 弹出控制器 = 分享控制器.popoverPresentationController {
            弹出控制器.sourceView = 顶层控制器.view
            弹出控制器.sourceRect = CGRect(x: 顶层控制器.view.bounds.midX,
                                           y: 顶层控制器.view.bounds.midY,
                                           width: 0, height: 0)
            弹出控制器.permittedArrowDirections = []
        }

        顶层控制器.present(分享控制器, animated: true) { [weak self] in
            // 分享面板弹出后，延迟60秒清理临时文件
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                self?.清理临时文件()
            }
        }
    }

    /// 获取最顶层的视图控制器（递归查找 presentedViewController）
    private func 获取最顶层视图控制器() -> UIViewController? {
        guard let 窗口 = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              var 顶层控制器 = 窗口.rootViewController else {
            return nil
        }

        // 递归查找最顶层 presented 控制器
        while let  presented = 顶层控制器.presentedViewController {
            顶层控制器 = presented
        }

        return 顶层控制器
    }

    // MARK: - 字节格式化

    /// 格式化字节数为可读字符串
    static func 格式化字节(_ 字节: Int64) -> String {
        if 字节 < 1024 {
            return "\(字节) B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.1f KB", Double(字节) / 1024)
        } else if 字节 < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(字节) / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", Double(字节) / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension AppDownloadManager: URLSessionDownloadDelegate {
    /// 下载进度更新
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {

        已下载字节 = totalBytesWritten
        总字节 = totalBytesExpectedToWrite

        if totalBytesExpectedToWrite > 0 {
            进度 = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }

        // 计算下载速度（每0.5秒统计一次）
        if let 上次时间 = 上次统计时间 {
            let 时间间隔 = Date().timeIntervalSince(上次时间)
            if 时间间隔 >= 0.5 {
                let 字节差 = totalBytesWritten - 上次统计字节
                下载速度 = Double(字节差) / 时间间隔 / (1024 * 1024)
                上次统计字节 = totalBytesWritten
                上次统计时间 = Date()
            }
        }
    }

    /// 下载完成
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {

        // 检查 HTTP 状态码
        if let 响应 = downloadTask.response as? HTTPURLResponse,
           响应.statusCode != 200 {
            DispatchQueue.main.async {
                self.下载状态 = .下载失败("下载失败：HTTP \(响应.statusCode)")
            }
            return
        }

        // 复制到临时可分享目录
        let 临时目录 = FileManager.default.temporaryDirectory
        let 文件名 = "newVPN-update.ipa"
        let 目标URL = 临时目录.appendingPathComponent(文件名)

        do {
            try? FileManager.default.removeItem(at: 目标URL)
            try FileManager.default.copyItem(at: location, to: 目标URL)
            临时文件URL = 目标URL

            DispatchQueue.main.async {
                self.进度 = 1.0
                self.下载状态 = .下载完成
                self.下载完成回调?(目标URL)
            }
        } catch {
            DispatchQueue.main.async {
                self.下载状态 = .下载失败("文件保存失败：\(error.localizedDescription)")
            }
        }
    }

    /// 下载任务完成（含错误）
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let 错误 = error {
            // 区分用户取消和真实错误
            if (错误 as NSError).code == NSURLErrorCancelled {
                return  // 已在取消方法中处理
            }
            DispatchQueue.main.async {
                self.下载状态 = .下载失败(错误.localizedDescription)
            }
        }
    }
}
