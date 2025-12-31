//
//  AppDelegate.swift
//  GreenVPN
//
//  应用级委托（当前占位，后续可按需扩展生命周期逻辑）
//

import UIKit
import GoogleMobileAds
import YandexMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        initializeThirdPartySDKs()
        return true
    }
    
    // MARK: - 第三方SDK初始化
    
    /// 初始化所有第三方SDK
    private func initializeThirdPartySDKs() {
        setupGoogleAds()
        setupYandexAds()
        setupAnalytics()
    }
    
    /// 初始化 Google Ads
    private func setupGoogleAds() {
        MobileAds.shared.start { [weak self] status in
            let adapters = status.adapterStatusesByClassName
            let isReady = adapters.values.contains { $0.state == .ready }
            self?.logSDKStatus(name: "Google Ads", success: isReady)
        }
    }
    
    /// 初始化 Yandex Ads
    private func setupYandexAds() {
        MobileAds.initializeSDK { [weak self] in
            self?.logSDKStatus(name: "Yandex Ads", success: true)
        }
    }
    
    /// 初始化分析SDK
    private func setupAnalytics() {
        let analyticsKey = "624e26a93bcf92fa376205861fd0cea7"
        let analyticsSecret = "30935c365fd50e9721c3469b8ee6b1667ef8d8dc"
        
        GVLogger.log("AppDelegate", "开始初始化分析SDK")
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // 配置日志
        GameAnalytics.setEnabledInfoLog(true)
        GameAnalytics.setEnabledVerboseLog(true)
        GameAnalytics.configureAutoDetectAppVersion(true)
        GameAnalytics.configureBuild(appVersion)
        GameAnalytics.initialize(withGameKey: analyticsKey, gameSecret: analyticsSecret)
    }
    
    /// 记录SDK初始化状态
    private func logSDKStatus(name: String, success: Bool) {
        let status = success ? "成功" : "失败"
        GVLogger.log("AppDelegate", "\(name) 初始化\(status)")
    }
}


