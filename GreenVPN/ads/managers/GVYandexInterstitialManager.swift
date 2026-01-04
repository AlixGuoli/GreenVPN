//
//  GVYandexInterstitialManager.swift
//  GreenVPN
//
//  Yandex 插屏广告管理（混淆自 YanIntCenter/YanSlotHub）
//

import Foundation
import UIKit
import YandexMobileAds

/// Yandex 插屏广告管理器（混淆自 YanSlotHub）
final class GVYandexInterstitialManager: NSObject {
    
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
        adUnitList = GVAdsConfigTools.shared.interstitialUnit()
            .components(separatedBy: ";")
            .filter { !$0.isEmpty }
        if !adUnitList.isEmpty {
            GVLogger.log("[Ad]", "获取到 keys: \(adUnitList.count) 个 | \(adUnitList)")
        } else {
            GVLogger.log("[Ad]", "未找到 keys")
        }
    }
    
    // MARK: - 加载流程
    
    func startLoading(moment: String? = nil) {
        GVLogger.log("[Ad]", "开始加载")
        
        if canStartLoading() {
            beginLoadProcess(moment: moment)
        }
    }
    
    private func beginLoadProcess(moment: String? = nil) {
        prepareAdUnits()
        adUnitIndex = 0
        guard adUnitList.count > adUnitIndex else { return }
        
        GVLogger.log("[Ad]", "启动加载流程")
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
            GVLogger.log("[Ad]", "加载超时 (100s)")
            isLoading = false
            notifyLoadFailed()
            return
        }
        
        let adKey = adUnitList[adUnitIndex]
        GVLogger.log("[Ad]", "尝试加载 key[\(adUnitIndex)]: \(adKey)")
        
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
        GVLogger.log("[Ad]", "清空广告")
    }
    
    private func notifyLoadFailed() {
        isLoading = false
        onAdFailed?()
    }
}

// MARK: - InterstitialAdLoaderDelegate

extension GVYandexInterstitialManager: InterstitialAdLoaderDelegate {
    
    func interstitialAdLoader(_ loader: InterstitialAdLoader, didLoad ad: InterstitialAd) {
        GVLogger.log("[Ad]", "✅ 加载成功 | key: \(ad.adInfo?.adUnitId ?? "")")
        isLoading = false
        currentAd = ad
        currentAd?.delegate = self
        
        onAdReady?()
    }
    
    func interstitialAdLoader(_ loader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        GVLogger.log("[Ad]", "❌ 加载失败 | error: \(error.error.localizedDescription)")
        adUnitIndex += 1
        Task {
            await tryLoadNext()
        }
    }
}

// MARK: - InterstitialAdDelegate

extension GVYandexInterstitialManager: InterstitialAdDelegate {
    
    func interstitialAdDidShow(_ ad: InterstitialAd) {
        GVLogger.log("[Ad]", "广告已展示")
        GVAdCoordinator.shared.isPresenting = true
        presentingAd = currentAd
        currentAd = nil
        restartLoading(moment: GVAdTrigger.closead)
    }
    
    func interstitialAdDidDismiss(_ ad: InterstitialAd) {
        GVLogger.log("[Ad]", "广告已关闭")
        GVAdCoordinator.shared.isPresenting = false
        onAdClosed?()
    }
    
    func interstitialAdDidClick(_ ad: InterstitialAd) {
        GVLogger.log("[Ad]", "广告点击")
        onAdClicked?()
    }
    
    func interstitialAd(_ ad: InterstitialAd, didFailToShowWithError error: Error) {
        GVLogger.log("[Ad]", "❌ 展示失败 | error: \(error.localizedDescription)")
        restartLoading()
    }
}

