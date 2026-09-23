//
//  UpdateModel.swift
//  NewVPN
//
//  应用更新数据模型与状态枚举
//

import Foundation

// MARK: - 版本信息模型

/// 应用版本信息数据模型
struct 版本信息模型: Codable, Equatable {
    /// 最新版本号（语义化版本，如 "1.8.4"）
    let 最新版本: String
    /// 发布日期（如 "2026-09-21"）
    let 发布日期: String
    /// 构建环境描述
    let 构建环境: String
    /// 最低支持 iOS 版本
    let 最低iOS版本: String
    /// 产物文件名
    let 产物文件名: String
    /// 产物描述
    let 产物描述: String
    /// IPA 下载地址
    let 下载地址: String
    /// 更新详情页地址
    let 详情地址: String
    /// 更新内容说明
    let 更新说明: String

    /// 从 JSON 字典初始化
    init?(字典: [String: Any]) {
        guard let 版本 = 字典["latest_version"] as? String,
              let 日期 = 字典["release_date"] as? String,
              let 下载 = 字典["download_url"] as? String else {
            return nil
        }
        self.最新版本 = 版本
        self.发布日期 = 日期
        self.构建环境 = 字典["build_env"] as? String ?? "Xcode 15.4 / macOS 14"
        self.最低iOS版本 = 字典["min_ios"] as? String ?? "iOS 16.0"
        self.产物文件名 = 字典["artifact_name"] as? String ?? "newVPN-\(版本).ipa"
        self.产物描述 = 字典["artifact_desc"] as? String ?? "未签名IPA（需自签名或侧载安装）"
        self.下载地址 = 下载
        self.详情地址 = 字典["detail_url"] as? String ?? ""
        self.更新说明 = 字典["release_notes"] as? String ?? ""
    }
}

// MARK: - 更新检测状态

/// 更新检测状态枚举
enum 更新检测状态: Equatable {
    /// 空闲（未开始）
    case 空闲
    /// 正在检测（半高弹窗）
    case 检测中(检测步骤文本)
    /// 发现新版本（完整弹窗）
    case 发现新版本(版本信息模型)
    /// 已是最新版本（半高弹窗）
    case 已是最新
    /// 检测失败（半高弹窗）
    case 检测失败(String)

    /// 是否需要显示弹窗
    var 是否显示弹窗: Bool {
        switch self {
        case .空闲:
            return false
        default:
            return true
        }
    }

    /// 弹窗高度比例（相对于屏幕高度）
    var 弹窗高度比例: CGFloat {
        switch self {
        case .检测中, .已是最新, .检测失败:
            return 0.45  // 半高
        case .发现新版本:
            return 0.82  // 完整高度
        case .空闲:
            return 0
        }
    }
}

// MARK: - 检测步骤文本

/// 检测过程中的步骤文本
enum 检测步骤文本: String, CaseIterable {
    case 正在连接服务器 = "正在连接服务器…"
    case 获取版本信息 = "获取版本信息…"
    case 校验版本号 = "校验版本号…"
    case 检测完成 = "检测完成"
}

// MARK: - 下载状态

/// IPA 下载状态枚举
enum 下载状态: Equatable {
    /// 空闲
    case 空闲
    /// 下载中
    case 下载中
    /// 下载完成
    case 下载完成
    /// 下载失败
    case 下载失败(String)
    /// 已取消
    case 已取消
}

// MARK: - 版本比较工具

/// 语义化版本比较工具
enum 版本比较器 {
    /// 比较两个语义化版本号
    /// 返回：1 = 新版本更大，0 = 相等，-1 = 新版本更小
    static func 比较(当前版本: String, 最新版本: String) -> Int {
        let 当前段 = 当前版本.split(separator: ".").compactMap { Int($0) }
        let 最新段 = 最新版本.split(separator: ".").compactMap { Int($0) }

        let 最大长度 = max(当前段.count, 最新段.count)

        for 索引 in 0..<最大长度 {
            let 当前值 = 索引 < 当前段.count ? 当前段[索引] : 0
            let 最新值 = 索引 < 最新段.count ? 最新段[索引] : 0

            if 最新值 > 当前值 { return 1 }
            if 最新值 < 当前值 { return -1 }
        }
        return 0
    }

    /// 判断是否有新版本
    static func 有新版本(当前版本: String, 最新版本: String) -> Bool {
        return 比较(当前版本: 当前版本, 最新版本: 最新版本) == 1
    }
}
