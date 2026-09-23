//
//  AppUpdateManager.swift
//  NewVPN
//
//  应用更新检测管理器
//  接入真实 GitHub Release API，检测新版本、版本比较、忽略版本管理
//

import Foundation

/// 应用更新检测管理器
final class AppUpdateManager: ObservableObject {
    /// 全局单例
    static let 共享 = AppUpdateManager()

    // MARK: - 发布状态

    /// 当前检测状态
    @Published var 检测状态: 更新检测状态 = .空闲

    /// 当前是否为静默检测模式（静默模式下检测中不弹窗，只有新版本才弹窗）
    private var 当前静默模式 = false

    /// 是否需要显示弹窗（考虑静默模式）
    var 是否显示弹窗: Bool {
        if 当前静默模式 {
            // 静默模式：只有发现新版本才弹窗
            if case .发现新版本 = 检测状态 { return true }
            return false
        }
        return 检测状态.是否显示弹窗
    }

    /// 当前版本号（从 Info.plist 读取）
    var 当前版本号: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    // MARK: - GitHub API 配置

    /// GitHub 仓库所有者
    private let 仓库所有者 = "lambret-1"
    /// GitHub 仓库名
    private let 仓库名 = "new-vpn"
    /// GitHub API 最新 Release 地址
    private var 最新Release地址: URL? {
        URL(string: "https://api.github.com/repos/\(仓库所有者)/\(仓库名)/releases/latest")
    }

    // MARK: - 本地存储键

    private let 忽略版本键 = "AppUpdate_忽略版本"
    private let 稍后提醒时间键 = "AppUpdate_稍后提醒时间"
    private let 上次检测时间键 = "AppUpdate_上次检测时间"
    private let 每日检测日期键 = "AppUpdate_每日检测日期"

    // MARK: - URLSession

    private let 会话: URLSession = {
        let 配置 = URLSessionConfiguration.default
        配置.timeoutIntervalForRequest = 15
        配置.timeoutIntervalForResource = 30
        return URLSession(configuration: 配置)
    }()

    // MARK: - 初始化

    private init() {}

    // MARK: - 开始检测

    /// 开始检测更新
    /// - Parameter 静默模式: true=后台静默检测（有新版本才弹窗），false=手动检测（始终弹窗）
    func 开始检测(静默模式: Bool = false) {
        // 允许从非检测中状态重新开始（检测失败/已是最新/发现新版本都可重试）
        if case .检测中 = 检测状态 { return }

        // 检查是否在稍后提醒冷却期内
        if 静默模式, let 提醒时间 = UserDefaults.standard.object(forKey: 稍后提醒时间键) as? Date,
           Date().timeIntervalSince(提醒时间) < 24 * 3600 {
            return
        }

        // 重置状态为空闲，再开始新检测
        检测状态 = .空闲

        // 记录当前模式
        当前静默模式 = 静默模式

        // 记录检测时间
        UserDefaults.standard.set(Date(), forKey: 上次检测时间键)

        Task {
            await 执行检测流程(静默模式: 静默模式)
        }
    }

    /// 前台检测（App从后台回到前台时调用，间隔>6小时才检测）
    func 前台检测() {
        // 检测中不重复触发
        if case .检测中 = 检测状态 { return }

        // 检查距离上次检测是否超过6小时
        if let 上次检测 = UserDefaults.standard.object(forKey: 上次检测时间键) as? Date,
           Date().timeIntervalSince(上次检测) < 6 * 3600 {
            return
        }

        开始检测(静默模式: true)
    }

    /// 每日首次启动检测（每天最多自动检测1次）
    func 每日启动检测() {
        let 日期格式 = DateFormatter()
        日期格式.dateFormat = "yyyy-MM-dd"
        let 今天 = 日期格式.string(from: Date())

        // 检查今天是否已检测过
        if let 上次检测日期 = UserDefaults.standard.string(forKey: 每日检测日期键),
           上次检测日期 == 今天 {
            return
        }

        UserDefaults.standard.set(今天, forKey: 每日检测日期键)
        开始检测(静默模式: true)
    }

    // MARK: - 检测流程

    /// 执行完整检测流程（真实 GitHub API，无模拟延迟）
    private func 执行检测流程(静默模式: Bool) async {
        // 步骤1：连接服务器
        await 更新状态(.检测中(.正在连接服务器))

        // 步骤2：获取版本信息（真实 API 请求）
        await 更新状态(.检测中(.获取版本信息))

        do {
            let 版本信息 = try await 请求最新Release()

            // 步骤3：校验版本号
            await 更新状态(.检测中(.校验版本号))

            // 步骤4：检测完成，判断结果
            await 更新状态(.检测中(.检测完成))

            await MainActor.run {
                if 版本比较器.有新版本(当前版本: 当前版本号, 最新版本: 版本信息.最新版本) {
                    // 检查是否被忽略
                    if 静默模式, 版本信息.最新版本 == 已忽略版本 {
                        检测状态 = .空闲
                        当前静默模式 = false
                        return
                    }
                    检测状态 = .发现新版本(版本信息)
                } else {
                    if 静默模式 {
                        // 静默模式下已是最新版本不弹窗
                        检测状态 = .空闲
                        当前静默模式 = false
                    } else {
                        检测状态 = .已是最新
                    }
                }
            }
        } catch let 错误 {
            await MainActor.run {
                if 静默模式 {
                    // 静默模式下检测失败不弹窗
                    检测状态 = .空闲
                    当前静默模式 = false
                } else {
                    检测状态 = .检测失败(错误.localizedDescription)
                }
            }
        }
    }

    // MARK: - 真实 API 请求

    /// 请求 GitHub 最新 Release 信息
    private func 请求最新Release() async throws -> 版本信息模型 {
        guard let url = 最新Release地址 else {
            throw 更新错误.无效地址
        }

        var 请求 = URLRequest(url: url)
        // GitHub API 要求 User-Agent
        请求.setValue("newVPN-iOS-Client", forHTTPHeaderField: "User-Agent")
        请求.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (数据, 响应) = try await 会话.data(for: 请求)

        // 检查 HTTP 状态码
        guard let http响应 = 响应 as? HTTPURLResponse else {
            throw 更新错误.无效响应
        }

        guard http响应.statusCode == 200 else {
            if http响应.statusCode == 404 {
                throw 更新错误.无Release
            }
            throw 更新错误.请求失败("HTTP \(http响应.statusCode)")
        }

        // 解析 JSON
        guard let json = try JSONSerialization.jsonObject(with: 数据) as? [String: Any] else {
            throw 更新错误.解析失败
        }

        // 提取版本号（tag_name，去掉 v 前缀）
        guard let tag名称 = json["tag_name"] as? String else {
            throw 更新错误.解析失败
        }
        let 版本号 = tag名称.hasPrefix("v") ? String(tag名称.dropFirst()) : tag名称

        // 提取发布日期
        let 发布日期原始 = json["published_at"] as? String ?? ""
        let 发布日期 = 格式化日期(发布日期原始)

        // 提取 Release 名称
        let release名称 = json["name"] as? String ?? "newVPN v\(版本号)"

        // 提取更新说明（body）
        let 更新说明 = json["body"] as? String ?? ""

        // 提取详情页地址
        let 详情地址 = json["html_url"] as? String ??
            "https://github.com/\(仓库所有者)/\(仓库名)/releases/tag/\(tag名称)"

        // 从 assets 中查找 IPA 下载地址
        var 下载地址 = ""
        var 产物文件名 = "newVPN-v\(版本号).ipa"

        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let 名称 = asset["name"] as? String, 名称.hasSuffix(".ipa") {
                    产物文件名 = 名称
                    下载地址 = asset["browser_download_url"] as? String ?? ""
                    break
                }
            }
        }

        // 如果没找到 asset，构造默认下载地址
        if 下载地址.isEmpty {
            下载地址 = "https://github.com/\(仓库所有者)/\(仓库名)/releases/download/\(tag名称)/\(产物文件名)"
        }

        return 版本信息模型(
            最新版本: 版本号,
            发布日期: 发布日期,
            构建环境: "Xcode 15.4 / macOS 14",
            最低iOS版本: "iOS 16.0",
            产物文件名: 产物文件名,
            产物描述: "未签名IPA（需自签名或侧载安装）",
            下载地址: 下载地址,
            详情地址: 详情地址,
            更新说明: 更新说明.isEmpty ? release名称 : 更新说明
        )
    }

    // MARK: - 日期格式化

    /// 将 GitHub ISO 日期格式化为 yyyy-MM-dd
    private func 格式化日期(_ 原始日期: String) -> String {
        guard !原始日期.isEmpty else { return "未知" }

        let 输入格式 = DateFormatter()
        输入格式.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        输入格式.locale = Locale(identifier: "en_US_POSIX")

        guard let 日期 = 输入格式.date(from: 原始日期) else {
            return String(原始日期.prefix(10))
        }

        let 输出格式 = DateFormatter()
        输出格式.dateFormat = "yyyy-MM-dd"
        return 输出格式.string(from: 日期)
    }

    // MARK: - 在主线程更新状态

    private func 更新状态(_ 新状态: 更新检测状态) async {
        await MainActor.run {
            self.检测状态 = 新状态
        }
    }

    // MARK: - 忽略版本管理

    /// 已忽略的版本号
    var 已忽略版本: String? {
        UserDefaults.standard.string(forKey: 忽略版本键)
    }

    /// 忽略当前版本
    func 忽略当前版本(_ 版本号: String) {
        UserDefaults.standard.set(版本号, forKey: 忽略版本键)
        关闭弹窗()
    }

    /// 稍后提醒（24小时冷却）
    func 稍后提醒() {
        UserDefaults.standard.set(Date(), forKey: 稍后提醒时间键)
        关闭弹窗()
    }

    /// 关闭弹窗
    func 关闭弹窗() {
        检测状态 = .空闲
        当前静默模式 = false
    }
}

// MARK: - 更新错误枚举

/// 更新检测相关错误
enum 更新错误: LocalizedError {
    case 无效地址
    case 无效响应
    case 请求失败(String)
    case 无Release
    case 解析失败

    var 错误描述: String {
        switch self {
        case .无效地址: return "更新服务器地址无效"
        case .无效响应: return "服务器响应无效"
        case .请求失败(let 信息): return "请求失败：\(信息)"
        case .无Release: return "暂无发布版本"
        case .解析失败: return "版本信息解析失败"
        }
    }

    var errorDescription: String? { 错误描述 }
}
