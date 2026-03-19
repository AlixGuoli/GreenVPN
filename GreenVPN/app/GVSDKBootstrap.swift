//
//  GVSDKBootstrap.swift
//  GreenVPN
//
//  第三方 SDK 启动协调：等待 ATT 结果后再初始化
//

import Foundation
import YandexMobileAds

final class GVSDKBootstrap {
    static let shared = GVSDKBootstrap()

    private init() {}

    private let stateKey = "GreenVPNSDKBootstrapStarted_v1"

    var hasStarted: Bool {
        UserDefaults.standard.bool(forKey: stateKey)
    }

    func startIfNeeded() {
        guard !hasStarted else { return }

        UserDefaults.standard.set(true, forKey: stateKey)
        UserDefaults.standard.synchronize()

        startYandexAds()
        startAnalytics()
    }

    private func startYandexAds() {
        MobileAds.initializeSDK {
            GVLogger.log("SDK", "Yandex Ads 初始化成功")
        }
    }

    private func startAnalytics() {
        let analyticsKey = "624e26a93bcf92fa376205861fd0cea7"
        let analyticsSecret = "30935c365fd50e9721c3469b8ee6b1667ef8d8dc"

        GVLogger.log("SDK", "开始初始化 GA SDK")

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        GameAnalytics.setEnabledInfoLog(true)
        GameAnalytics.setEnabledVerboseLog(true)
        GameAnalytics.configureAutoDetectAppVersion(true)
        GameAnalytics.configureBuild(appVersion)
        GameAnalytics.initialize(withGameKey: analyticsKey, gameSecret: analyticsSecret)
        GVLogger.log("SDK", "GA SDK 初始化完成")
    }
}

