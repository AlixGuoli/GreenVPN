//
//  GVBaseParameters.swift
//  GreenVPN
//
//  基础参数工具：集中定义和管理所有接口的通用基础参数
//

import Foundation

enum GVBaseParameters {
    
    /// UserDefaults key 用于存储 UUID
    private static let uuidKey = "GVUserUUID"
    
    /// 获取所有基础参数
    static func parameters() -> [String: Any] {
        return [
            "uid": getUUID(),
            "country": getCountry(),
            "language": getLanguage(),
            "pk": getBundleID(),
            "version": getAppVersion()
        ]
    }
    
    /// 获取用户 UUID（没有则创建并存储）
    static func getUUID() -> String {
        if let stored = UserDefaults.standard.string(forKey: uuidKey), !stored.isEmpty {
            return stored
        }
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: uuidKey)
        return newUUID
    }
    
    /// 获取国家代码
    static func getCountry() -> String {
        return (Locale.current.region?.identifier ?? "us").lowercased()
    }
    
    /// 获取语言代码
    static func getLanguage() -> String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// 获取 Bundle ID
    static func getBundleID() -> String {
        return Bundle.main.bundleIdentifier ?? "com.green.fire.vpn.birds"
    }
    
    /// 获取应用版本
    static func getAppVersion() -> String {
        return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}

