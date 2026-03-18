//
//  GVYandexEMInterstitialManager.swift
//  GreenVPN
//
//  Yandex EM 插屏广告管理（复用 Yandex SDK，仅更换 EM key 列表）
//

import Foundation
import UIKit
import YandexMobileAds

/// Yandex EM 插屏广告管理器
///
/// 逻辑与 `GVYandexInterstitialManager` 基本一致，区别仅在于：
/// - 广告位来源使用 `GVAdsConfigTools.shared.emInterstitialUnit()`
/// - 日志前缀中标记为 EM，便于排查
final class GVYandexEMInterstitialManager: NSObject {

    private var loadStartAt: Date?
    private var currentAd: InterstitialAd?
    private var adUnitIndex = 0
    private var isLoading = false
    private var adUnitList: [String] = []
    private var adLoader: InterstitialAdLoader?
    private var presentingAd: InterstitialAd?

    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    var onAdClosed: (() -> Void)?

    // MARK: - 状态查询

    func hasReadyAd() -> Bool {
        return currentAd != nil
    }

    func getActiveAd() -> InterstitialAd? {
        return hasReadyAd() ? currentAd : nil
    }

    private func canStartLoading() -> Bool {
        if hasReadyAd() { return false }
        if isLoading {
            guard let startTime = loadStartAt else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > 100
        }
        return true
    }

    // MARK: - 配置管理

    func prepareAdUnits() {
        adUnitList = GVAdsConfigTools.shared.emInterstitialUnit()
            .components(separatedBy: ";")
            .filter { !$0.isEmpty }
        if !adUnitList.isEmpty {
            GVLogger.log("[Ad][EM]", "获取到 EM keys: \(adUnitList.count) 个 | \(adUnitList)")
        } else {
            GVLogger.log("[Ad][EM]", "未找到 EM keys")
        }
    }

    // MARK: - 加载流程

    func startLoading(moment: String? = nil) {
        GVLogger.log("[Ad][EM]", "开始加载 EM Int")

        if canStartLoading() {
            beginLoadProcess(moment: moment)
        }
    }

    private func beginLoadProcess(moment: String? = nil) {
        prepareAdUnits()
        adUnitIndex = 0
        guard adUnitList.count > adUnitIndex else {
            GVLogger.log("[Ad][EM]", "❌ 无可用 EM keys")
            onAdFailed?()
            return
        }

        GVLogger.log("[Ad][EM]", "启动 EM 加载流程")
        isLoading = true
        loadStartAt = Date()

        executeLoad(moment: moment)
    }

    private func executeLoad(moment: String? = nil) {
        Task {
            await tryLoadNext(moment: moment)
        }
    }

    private func tryLoadNext(moment: String? = nil) async {
        guard adUnitIndex < adUnitList.count else {
            notifyLoadFailed()
            return
        }

        if let startTime = loadStartAt, Date().timeIntervalSince(startTime) > 100 {
            GVLogger.log("[Ad][EM]", "加载超时 (100s)")
            isLoading = false
            notifyLoadFailed()
            return
        }

        let adKey = adUnitList[adUnitIndex]
        GVLogger.log("[Ad][EM]", "尝试加载 EM key[\(adUnitIndex)]: \(adKey)")

        await MainActor.run {
            let loader = InterstitialAdLoader()
            loader.delegate = self
            self.adLoader = loader

            let requestConfig = AdRequestConfiguration(adUnitID: adKey)
            loader.loadAd(with: requestConfig)
        }
    }

    func restartLoading(moment: String? = nil) {
        resetAd()
        startLoading(moment: moment)
    }

    // MARK: - 展示管理

    func showAd(from viewController: UIViewController, moment: String?) {
        guard let activeAd = currentAd else {
            return
        }

        activeAd.show(from: viewController)
    }

    // MARK: - 清理管理

    func resetAd() {
        currentAd = nil
        adLoader = nil
        GVLogger.log("[Ad][EM]", "清空 EM 广告")
    }

    private func notifyLoadFailed() {
        isLoading = false
        onAdFailed?()
    }
}

// MARK: - InterstitialAdLoaderDelegate

extension GVYandexEMInterstitialManager: InterstitialAdLoaderDelegate {

    func interstitialAdLoader(_ loader: InterstitialAdLoader, didLoad ad: InterstitialAd) {
        GVLogger.log("[Ad][EM]", "✅ EM 加载成功 | key: \(ad.adInfo?.adUnitId ?? "")")
        isLoading = false
        currentAd = ad
        currentAd?.delegate = self

        onAdReady?()
    }

    func interstitialAdLoader(_ loader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        GVLogger.log("[Ad][EM]", "❌ EM 加载失败 | error: \(error.error.localizedDescription)")
        adUnitIndex += 1
        Task {
            await tryLoadNext()
        }
    }
}

// MARK: - InterstitialAdDelegate

extension GVYandexEMInterstitialManager: InterstitialAdDelegate {

    func interstitialAdDidShow(_ ad: InterstitialAd) {
        GVLogger.log("[Ad][EM]", "EM 广告已展示")
        GVAdCoordinator.shared.isPresenting = true
        presentingAd = currentAd
        currentAd = nil
    }

    func interstitialAdDidDismiss(_ ad: InterstitialAd) {
        GVLogger.log("[Ad][EM]", "EM 广告已关闭")
        GVAdCoordinator.shared.isPresenting = false
        onAdClosed?()
        // 关闭后再加载下一条，避免展示期间并发加载
        restartLoading(moment: GVAdTrigger.closead)
    }

    func interstitialAdDidClick(_ ad: InterstitialAd) {
        GVLogger.log("[Ad][EM]", "EM 广告点击")
        onAdClicked?()
    }

    func interstitialAd(_ ad: InterstitialAd, didFailToShowWithError error: Error) {
        GVLogger.log("[Ad][EM]", "❌ EM 展示失败 | error: \(error.localizedDescription)")
        restartLoading()
    }
}

