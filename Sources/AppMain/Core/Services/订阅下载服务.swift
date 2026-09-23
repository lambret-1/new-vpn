//
//  订阅下载服务.swift
//  NewVPN
//
//  远程订阅下载服务：网络请求、sing-box配置解析、本地持久化
//

import Foundation

// MARK: - 订阅下载错误

/// 订阅下载相关错误
enum 订阅下载错误: LocalizedError {
    /// 无效的URL
    case 无效URL
    /// 网络请求失败
    case 网络错误(Error)
    /// HTTP状态码错误
    case 状态码错误(Int)
    /// 响应数据为空
    case 响应为空
    /// JSON解析失败
    case 解析失败(String)
    /// 文件写入失败
    case 写入失败(Error)

    var errorDescription: String? {
        switch self {
        case .无效URL: return "订阅地址无效"
        case .网络错误(let 错误): return "网络错误：\(错误.localizedDescription)"
        case .状态码错误(let 码): return "HTTP状态码错误：\(码)"
        case .响应为空: return "服务器返回空数据"
        case .解析失败(let 信息): return "配置解析失败：\(信息)"
        case .写入失败(let 错误): return "文件写入失败：\(错误.localizedDescription)"
        }
    }
}

// MARK: - 订阅下载结果

/// 订阅下载结果
struct 订阅下载结果 {
    /// 下载的配置内容（原始文本）
    let 配置内容: String
    /// 下载时间
    let 下载时间: Date
    /// 配置文件大小（字节）
    let 文件大小: Int
}

// MARK: - 订阅下载服务

/// 远程订阅下载服务
final class 订阅下载服务 {
    /// 共享单例
    static let 共享 = 订阅下载服务()

    /// URLSession 配置
    private let 会话: URLSession

    /// 配置文件存储目录
    private var 配置目录: URL {
        let 路径 = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let 目录 = 路径.appendingPathComponent("订阅配置", isDirectory: true)
        try? FileManager.default.createDirectory(at: 目录, withIntermediateDirectories: true)
        return 目录
    }

    /// 私有初始化
    private init() {
        let 配置 = URLSessionConfiguration.default
        配置.timeoutIntervalForRequest = 30
        配置.timeoutIntervalForResource = 60
        配置.requestCachePolicy = .reloadIgnoringLocalCacheData
        会话 = URLSession(configuration: 配置)
    }

    // MARK: - 下载订阅

    /// 下载远程订阅配置
    /// - Parameters:
    ///   - 订阅: 远程订阅模型
    ///   - 完成: 完成回调
    func 下载订阅(_ 订阅: 远程订阅模型, 完成: @escaping (Result<订阅下载结果, 订阅下载错误>) -> Void) {
        guard let url = URL(string: 订阅.地址) else {
            完成(.failure(.无效URL))
            return
        }

        var 请求 = URLRequest(url: url)
        请求.httpMethod = "GET"

        // 设置 User-Agent
        if let ua = 订阅.自定义UA, !ua.isEmpty {
            请求.setValue(ua, forHTTPHeaderField: "User-Agent")
        } else {
            请求.setValue("NewVPN/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        }

        // 设置自定义请求头
        for (键, 值) in 订阅.请求头 {
            请求.setValue(值, forHTTPHeaderField: 键)
        }

        let 任务 = 会话.dataTask(with: 请求) { [weak self] 数据, 响应, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                DispatchQueue.main.async {
                    完成(.failure(.网络错误(错误)))
                }
                return
            }

            // 检查 HTTP 状态码
            if let http响应 = 响应 as? HTTPURLResponse {
                guard (200...299).contains(http响应.statusCode) else {
                    DispatchQueue.main.async {
                        完成(.failure(.状态码错误(http响应.statusCode)))
                    }
                    return
                }
            }

            guard let 数据 = 数据, !数据.isEmpty else {
                DispatchQueue.main.async {
                    完成(.failure(.响应为空))
                }
                return
            }

            // 尝试解析为文本
            guard let 文本 = String(data: 数据, encoding: .utf8) else {
                DispatchQueue.main.async {
                    完成(.failure(.解析失败("无法解码为UTF-8文本")))
                }
                return
            }

            // 验证是否为有效的 JSON（sing-box 配置格式）
            if let json数据 = 文本.data(using: .utf8) {
                do {
                    _ = try JSONSerialization.jsonObject(with: json数据, options: [])
                } catch {
                    // 可能是 base64 编码的订阅，尝试解码
                    if let 解码数据 = Data(base64Encoded: 文本, options: .ignoreUnknownCharacters),
                       let 解码文本 = String(data: 解码数据, encoding: .utf8) {
                        // base64 解码成功，继续验证
                        do {
                            _ = try JSONSerialization.jsonObject(with: 解码数据, options: [])
                        } catch {
                            DispatchQueue.main.async {
                                完成(.failure(.解析失败("内容不是有效的JSON配置")))
                            }
                            return
                        }
                        let 结果 = 订阅下载结果(配置内容: 解码文本, 下载时间: Date(), 文件大小: 解码数据.count)
                        self.保存配置(订阅: 订阅, 内容: 解码文本)
                        DispatchQueue.main.async {
                            完成(.success(结果))
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        完成(.failure(.解析失败("内容不是有效的JSON配置")))
                    }
                    return
                }
            }

            // JSON 验证通过，保存配置
            let 结果 = 订阅下载结果(配置内容: 文本, 下载时间: Date(), 文件大小: 数据.count)
            self.保存配置(订阅: 订阅, 内容: 文本)
            DispatchQueue.main.async {
                完成(.success(结果))
            }
        }

        任务.resume()
    }

    // MARK: - 本地持久化

    /// 保存订阅配置到本地
    private func 保存配置(订阅: 远程订阅模型, 内容: String) {
        let 文件名 = "订阅_\(订阅.id.uuidString).json"
        let 文件路径 = 配置目录.appendingPathComponent(文件名)

        do {
            try 内容.write(to: 文件路径, atomically: true, encoding: .utf8)
        } catch {
            print("订阅配置保存失败：\(error.localizedDescription)")
        }
    }

    /// 读取本地订阅配置
    func 读取本地配置(订阅ID: UUID) -> String? {
        let 文件名 = "订阅_\(订阅ID.uuidString).json"
        let 文件路径 = 配置目录.appendingPathComponent(文件名)

        do {
            return try String(contentsOf: 文件路径, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// 删除本地订阅配置文件
    func 删除本地配置(订阅ID: UUID) {
        let 文件名 = "订阅_\(订阅ID.uuidString).json"
        let 文件路径 = 配置目录.appendingPathComponent(文件名)
        try? FileManager.default.removeItem(at: 文件路径)
    }

    /// 获取本地配置文件大小
    func 本地配置大小(订阅ID: UUID) -> Int? {
        let 文件名 = "订阅_\(订阅ID.uuidString).json"
        let 文件路径 = 配置目录.appendingPathComponent(文件名)

        do {
            let 属性 = try FileManager.default.attributesOfItem(atPath: 文件路径.path)
            return 属性[.size] as? Int
        } catch {
            return nil
        }
    }
}

// MARK: - 订阅列表持久化

/// 订阅列表本地存储管理
final class 订阅存储 {
    /// 共享单例
    static let 共享 = 订阅存储()

    /// UserDefaults 存储键
    private let 存储键 = "远程订阅列表"

    /// 保存订阅列表
    func 保存订阅列表(_ 列表: [远程订阅模型]) {
        do {
            let 数据 = try JSONEncoder().encode(列表)
            UserDefaults.standard.set(数据, forKey: 存储键)
        } catch {
            print("订阅列表保存失败：\(error.localizedDescription)")
        }
    }

    /// 读取订阅列表
    func 读取订阅列表() -> [远程订阅模型] {
        guard let 数据 = UserDefaults.standard.data(forKey: 存储键) else {
            return []
        }
        do {
            return try JSONDecoder().decode([远程订阅模型].self, from: 数据)
        } catch {
            print("订阅列表读取失败：\(error.localizedDescription)")
            return []
        }
    }
}
