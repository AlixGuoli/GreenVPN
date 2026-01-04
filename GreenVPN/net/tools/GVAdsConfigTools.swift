//
//  GVAdsConfigTools.swift
//  GreenVPN
//
//  广告配置接口的数据管理：解析和存储
//

import Foundation

/// 广告跳过按钮配置
struct GVAdSkipConfig {
    let location: Int
    let x: Int
    let y: Int
    
    static let `default` = GVAdSkipConfig(location: 0, x: 20, y: 100)
}

/// 广告配置数据管理工具（单例）
final class GVAdsConfigTools {
    
    static let shared = GVAdsConfigTools()
    
    private let adsConfigKey = "GVAdsConfig"
    private let saveDateKey = "GVAdsConfigSaveDate"
    private let skipConfigKey = "GVAdsSkipConfig"
    
    private init() {}
    
    /// 解析并保存广告配置
    /// - Parameter jsonString: 接口返回的 JSON 字符串
    func parseAndSave(_ jsonString: String) {
        // 保存原始 JSON
        UserDefaults.standard.set(jsonString, forKey: adsConfigKey)
        
        // 保存配置时间
        let saveDate = Date()
        UserDefaults.standard.set(saveDate, forKey: saveDateKey)
        
        UserDefaults.standard.synchronize()
        
        GVLogger.log("AdsConfigTools", "广告配置已保存，保存时间：\(saveDate)")
        
        // 提取并打印关键字段（用于调试）
        GVLogger.log("AdsConfigTools", "Banner unit: \(bannerUnit())")
        GVLogger.log("AdsConfigTools", "Interstitial unit: \(interstitialUnit())")
        GVLogger.log("AdsConfigTools", "AdMob unit: \(admobUnit())")
        GVLogger.log("AdsConfigTools", "Penetration: \(penetration())")
        GVLogger.log("AdsConfigTools", "Delay: \(delay())")
    }
    
    /// 获取横幅广告单元（带默认值）
    func bannerUnit() -> String {
        /// 测试服
        //return "demo-banner-yandex"
        return extractAdKey(byName: "Yandex_Banner_List") ?? "R-M-18328270-1;R-M-18328270-2"
    }
    
    /// 获取插屏广告单元（带默认值）
    func interstitialUnit() -> String {
        /// 测试服
        //return "demo-interstitial-yandex"
        return extractAdKey(byName: "Yandex_Int_List") ?? "R-M-18328270-3"
    }
    
    /// 获取 AdMob 广告单元（带默认值）
    func admobUnit() -> String {
        /// 测试服
        //return "ca-app-pub-3940256099942544/4411468910"
        return extractAdKey(byName: "Admob_Int_List") ?? "ca-app-pub-4769248627863594/6514577426"
    }
    
    /// 获取穿透率（从 Yandex_Banner_List 获取，带默认值）
    func penetration() -> Int {
        return extractAdField(byName: "Yandex_Banner_List", field: "penetrate") as? Int ?? 100
    }
    
    /// 获取点击延迟（从 Yandex_Banner_List 获取，带默认值）
    func delay() -> Int {
        return extractAdField(byName: "Yandex_Banner_List", field: "clickDelayPenet") as? Int ?? 15
    }
    
    /// 获取广告配置保存时间
    func timestamp() -> Date? {
        return UserDefaults.standard.object(forKey: saveDateKey) as? Date
    }
    
    // MARK: - 跳过按钮配置
    
    /// 解析并保存跳过按钮配置
    /// - Parameter jsonString: 接口返回的 JSON 字符串
    func parseAndSaveSkipConfig(_ jsonString: String) {
        // 保存原始 JSON
        UserDefaults.standard.set(jsonString, forKey: skipConfigKey)
        UserDefaults.standard.synchronize()
        
        GVLogger.log("AdsConfigTools", "跳过按钮配置已保存")
        
        // 提取并打印关键字段（用于调试）
        let config = skipConfig()
        GVLogger.log("AdsConfigTools", "Skip config - location: \(config.location), x: \(config.x), y: \(config.y)")
    }
    
    /// 获取跳过按钮配置（返回默认值如果不存在）
    func skipConfig() -> GVAdSkipConfig {
        guard let jsonString = UserDefaults.standard.string(forKey: skipConfigKey),
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pageConfig = dict["pageconfig"] as? [String: Any],
              let location = pageConfig["location"] as? Int,
              let x = pageConfig["x"] as? Int,
              let y = pageConfig["y"] as? Int else {
            return GVAdSkipConfig.default
        }
        return GVAdSkipConfig(location: location, x: x, y: y)
    }
    
    // MARK: - 私有方法：从 adMixed 数组中提取字段
    
    /// 从 adMixed 数组中根据 name 提取 key
    private func extractAdKey(byName name: String) -> String? {
        guard let adMixed = extractAdMixedArray() else {
            return nil
        }
        
        for ad in adMixed {
            if let adName = ad["name"] as? String, adName == name {
                return ad["key"] as? String
            }
        }
        return nil
    }
    
    /// 从 adMixed 数组中根据 name 提取指定字段
    private func extractAdField(byName name: String, field: String) -> Any? {
        guard let adMixed = extractAdMixedArray() else {
            return nil
        }
        
        for ad in adMixed {
            if let adName = ad["name"] as? String, adName == name {
                return ad[field]
            }
        }
        return nil
    }
    
    /// 提取 adMixed 数组
    private func extractAdMixedArray() -> [[String: Any]]? {
        guard let jsonString = UserDefaults.standard.string(forKey: adsConfigKey),
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let adConfig = dict["adConfig"] as? [String: Any],
              let adMixed = adConfig["adMixed"] as? [[String: Any]] else {
            return nil
        }
        return adMixed
    }
}

