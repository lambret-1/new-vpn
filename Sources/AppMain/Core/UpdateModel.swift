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
    /// 最新版本号（语义化版本，如 "0.1.3"）
    let 最新版本: String
    /// 发布日期（如 "2026-09-23"）
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
}

// MARK: - 更新检测状态

/// 更新检测状态枚举
enum 更新检测状态: Equatable {
    /// 空闲（未开始，不显示弹窗）
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
        case .空闲: return false
        default: return true
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
