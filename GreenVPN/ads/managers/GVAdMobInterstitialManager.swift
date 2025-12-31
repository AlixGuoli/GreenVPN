//
//  GVAdMobInterstitialManager.swift
//  GreenVPN
//
//  AdMob 插屏广告管理
//

import Foundation
import UIKit
import GoogleMobileAds

/// AdMob 插屏广告管理器
final class GVAdMobInterstitialManager: NSObject {
    
    static let shared = GVAdMobInterstitialManager()
    
    private var currentAd: InterstitialAd?
    private var presentingAd: InterstitialAd?
    private var isLoading = false
    private var adUnitList: [String] = []
    private var adUnitIndex = 0
    private var loadStartAt: Date?
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    var onAdClosed: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    // MARK: - 广告配置和展示
    
    func prepareAdUnits() {
        adUnitList = GVAdsConfigTools.shared.admobUnit()
            .components(separatedBy: ";")
            .filter { !$0.isEmpty }
        if !adUnitList.isEmpty {
            GVLogger.log("[Ad]", "获取到 keys: \(adUnitList.count) 个 | \(adUnitList)")
        } else {
            GVLogger.log("[Ad]", "未找到 keys")
        }
    }
    
    func showAd(from viewController: UIViewController, moment: String?) {
        guard let activeAd = currentAd else {
            return
        }
        
        let adKeyId = activeAd.adUnitID
        activeAd.present(from: viewController)
        
        // 上报展示事件
        GVTelemetryService.shared.reportAdEvent(
            eventKind: GVTelemetryService.kEventAdDisplay,
            adKey: adKeyId,
            adMoment: moment
        )
    }
    
    func hasReadyAd() -> Bool {
        return currentAd != nil
    }
    
    func getActiveAd() -> InterstitialAd? {
        return hasReadyAd() ? currentAd : nil
    }
    
    func resetAd() {
        currentAd = nil
        GVLogger.log("[Ad]", "清空广告")
    }
    
    // MARK: - 广告加载管理
    
    func startLoading(moment: String? = nil) {
        let connState = GVAppState.shared.currentPhase
        GVLogger.log("[Ad]", "开始加载 | 连接状态: \(connState)")
        
        if canStartLoading() && connState == .online {
            prepareAdUnits()
            adUnitIndex = 0
            guard adUnitList.count > adUnitIndex else { return }
            
            GVLogger.log("[Ad]", "启动加载流程")
            isLoading = true
            loadStartAt = Date()
            
            Task {
                await tryLoadNext(moment: moment)
            }
        }
    }
    
    func restartLoading(moment: String? = nil) {
        resetAd()
        startLoading(moment: moment)
    }
    
    // MARK: - 私有方法
    
    private func tryLoadNext(moment: String? = nil) async {
        guard adUnitIndex < adUnitList.count else {
            notifyLoadFailed()
            return
        }
        
        if let startTime = loadStartAt, Date().timeIntervalSince(startTime) > 120 {
            GVLogger.log("[Ad]", "加载超时 (120s)")
            isLoading = false
            notifyLoadFailed()
            return
        }
        
        let adKey = adUnitList[adUnitIndex]
        GVLogger.log("[Ad]", "尝试加载 key[\(adUnitIndex)]: \(adKey)")
        
        // 上报开始加载事件
        GVTelemetryService.shared.reportAdEvent(
            eventKind: GVTelemetryService.kEventAdRequest,
            adKey: adKey,
            adMoment: moment
        )
        
        do {
            let ad = try await InterstitialAd.load(with: adKey, request: Request())
            
            GVLogger.log("[Ad]", "✅ 加载成功 | key: \(ad.adUnitID)")
            isLoading = false
            currentAd = ad
            currentAd?.fullScreenContentDelegate = self
            
            // 上报加载成功事件
            GVTelemetryService.shared.reportAdEvent(
                eventKind: GVTelemetryService.kEventAdReady,
                adKey: ad.adUnitID,
                adMoment: moment
            )
            
            onAdReady?()
        } catch {
            GVLogger.log("[Ad]", "❌ 加载失败 | key: \(adKey) | error: \(error.localizedDescription)")
            adUnitIndex += 1
            await tryLoadNext(moment: moment)
        }
    }
    
    private func canStartLoading() -> Bool {
        if hasReadyAd() { return false }
        if isLoading {
            guard let startTime = loadStartAt else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > 120
        }
        return true
    }
    
    private func notifyLoadFailed() {
        isLoading = false
        onAdFailed?()
    }
}

// MARK: - FullScreenContentDelegate

extension GVAdMobInterstitialManager: FullScreenContentDelegate {
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        GVLogger.log("[Ad]", "广告将展示")
        GVAdCoordinator.shared.isPresenting = true
        presentingAd = currentAd
        currentAd = nil
        restartLoading(moment: GVAdTrigger.closead)
    }
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        GVLogger.log("[Ad]", "广告已展示")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        GVLogger.log("[Ad]", "广告点击")
        onAdClicked?()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        GVLogger.log("[Ad]", "❌ 展示失败 | error: \(error.localizedDescription)")
        restartLoading()
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        GVAdCoordinator.shared.isPresenting = false
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        GVLogger.log("[Ad]", "广告关闭")
    }
}
