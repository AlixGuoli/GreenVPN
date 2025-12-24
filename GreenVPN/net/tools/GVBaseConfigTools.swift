//
//  GVBaseConfigTools.swift
//  GreenVPN
//
//  基本配置接口的数据管理：解析和存储
//

import Foundation

/// 基本配置数据管理工具（单例）
final class GVBaseConfigTools {
    
    static let shared = GVBaseConfigTools()
    
    private let baseConfigKey = "GVBaseConfig"
    private let saveDateKey = "GVBaseConfigSaveDate"
    private let localGitVersionKey = "GVBaseConfigLocalGitVersion"
    
    private init() {}
    
    // MARK: - 保存配置
    
    /// 解析并保存基本配置
    /// - Parameter jsonString: 接口返回的 JSON 字符串
    func parseAndSave(_ jsonString: String) {
        // 保存原始 JSON
        UserDefaults.standard.set(jsonString, forKey: baseConfigKey)
        
        // 保存配置时间
        let saveDate = Date()
        UserDefaults.standard.set(saveDate, forKey: saveDateKey)
        
        UserDefaults.standard.synchronize()
        
        GVLogger.log("BaseConfigTools", "基本配置已保存，保存时间：\(saveDate)")
        
        // 提取并打印关键字段（用于调试）
        if let adsOff = getAdsOff() {
            GVLogger.log("BaseConfigTools", "adsOff: \(adsOff)")
        }
        if let adsType = adsType() {
            GVLogger.log("BaseConfigTools", "adsType: \(adsType)")
        }
        if let servers = detectionServers() {
            GVLogger.log("BaseConfigTools", "detectionServers: \(servers)")
        }
        if let version = gitVersion() {
            GVLogger.log("BaseConfigTools", "git_version: \(version)")
        }
    }
    
    // MARK: - 从 JSON 配置中提取字段
    
    /// 获取 adsOff
    func getAdsOff() -> Bool? {
        return extractField(path: ["commonConf", "adsOff"]) as? Bool
    }
    
    /// 获取 adsType
    func adsType() -> String? {
        return extractField(path: ["commonConf", "adsType"]) as? String
    }
    
    /// 获取 git_version
    func gitVersion() -> Int? {
        return extractField(path: ["commonConf", "git_version"]) as? Int
    }
    
    /// 获取 detectionServers 列表
    func detectionServers() -> [String]? {
        guard let detectionConfig = extractField(path: ["commonConf", "detectionConfig"]) as? [String: Any],
              let servers = detectionConfig["detectionServers"] as? [String] else {
            return nil
        }
        return servers
    }
 
    // MARK: - 配置保存时间
    
    /// 获取配置保存时间
    func saveDate() -> Date? {
        return UserDefaults.standard.object(forKey: saveDateKey) as? Date
    }
    
    // MARK: - Telegram 链接
    
    /// 获取 Telegram 链接（写死默认值）
    func telegramLink() -> String {
        return "https://t.me/+GHEEsuLHJ0I1YTU1"
    }
    
    // MARK: - Git 版本管理
    
    /// 从 UserDefaults 读取本地保存的 Git 版本号
    func localGitVersion() -> Int {
        return UserDefaults.standard.integer(forKey: localGitVersionKey)
    }
    
    /// 保存 Git 版本号到 UserDefaults
    func saveLocalGitVersion(_ version: Int) {
        UserDefaults.standard.set(version, forKey: localGitVersionKey)
        UserDefaults.standard.synchronize()
        GVLogger.log("BaseConfigTools", "本地 Git 版本号已保存：\(version)")
    }
    
    // MARK: - 私有方法
    
    /// 从保存的配置中提取字段
    private func extractField(path: [String]) -> Any? {
        guard let jsonString = UserDefaults.standard.string(forKey: baseConfigKey),
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        var current: Any? = dict
        for key in path {
            if let dict = current as? [String: Any] {
                current = dict[key]
            } else {
                return nil
            }
        }
        return current
    }
}

