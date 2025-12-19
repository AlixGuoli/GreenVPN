//
//  GVAppInfo.swift
//  GreenVPN
//
//  统一获取应用名称等基础信息，避免在各处写死字符串
//

import Foundation

enum GVAppInfo {
    /// 当前应用对用户展示的名称，优先使用 CFBundleDisplayName，其次使用 CFBundleName
    static var displayName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.isEmpty {
            return name
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }
        return "App"
    }
}


