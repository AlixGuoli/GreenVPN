//
//  GVAdsConfigTools.swift
//  GreenVPN
//
//  广告配置接口的数据管理：解析和存储
//

import Foundation

/// 广告配置数据管理工具（单例）
final class GVAdsConfigTools {
    
    static let shared = GVAdsConfigTools()
    
    private let adsConfigKey = "GVAdsConfig"
    
    private init() {}
    
    /// 解析并保存广告配置
    /// - Parameter jsonString: 接口返回的 JSON 字符串
    func parseAndSave(_ jsonString: String) {
        // 保存原始 JSON
        UserDefaults.standard.set(jsonString, forKey: adsConfigKey)
        UserDefaults.standard.synchronize()
        
        GVLogger.log("AdsConfigTools", "广告配置已保存")
        
        // 提取并打印关键字段（用于调试）
        GVLogger.log("AdsConfigTools", "Banner unit: \(bannerUnit())")
        GVLogger.log("AdsConfigTools", "Interstitial unit: \(interstitialUnit())")
        GVLogger.log("AdsConfigTools", "AdMob unit: \(admobUnit())")
        GVLogger.log("AdsConfigTools", "Penetration: \(penetration())")
        GVLogger.log("AdsConfigTools", "Delay: \(delay())")
    }
    
    /// 获取横幅广告单元（带默认值）
    func bannerUnit() -> String {
        return extractAdKey(byName: "Yandex_Banner_List") ?? "R-M-16002467-1;R-M-16002467-2"
    }
    
    /// 获取插屏广告单元（带默认值）
    func interstitialUnit() -> String {
        return extractAdKey(byName: "Yandex_Int_List") ?? "R-M-16002467-5;R-M-16002467-6"
    }
    
    /// 获取 AdMob 广告单元（带默认值）
    func admobUnit() -> String {
        return extractAdKey(byName: "Admob_Int_List") ?? "ca-app-pub-9602557768732199/3533000954"
    }
    
    /// 获取穿透率（从 Yandex_Banner_List 获取，带默认值）
    func penetration() -> Int {
        return extractAdField(byName: "Yandex_Banner_List", field: "penetrate") as? Int ?? 100
    }
    
    /// 获取点击延迟（从 Yandex_Banner_List 获取，带默认值）
    func delay() -> Int {
        return extractAdField(byName: "Yandex_Banner_List", field: "clickDelayPenet") as? Int ?? 15
    }
    
    /// 获取广告是否关闭（带默认值）
    func getAdsOff() -> Bool {
        // 如果后续接口返回 adsOff 字段，可以从这里提取
        // 目前先返回默认值
        return true
    }
    
    /// 获取广告配置保存时间
    func saveDate() -> Date? {
        // 如果后续需要保存时间，可以从这里提取
        return nil
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

