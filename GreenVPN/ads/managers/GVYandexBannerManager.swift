//
//  GVYandexBannerManager.swift
//  GreenVPN
//
//  Yandex 横幅广告管理（混淆自 YanBannerCenter/YanBannerHub）
//

import Foundation
import UIKit
import YandexMobileAds

/// Yandex 横幅广告管理器（混淆自 YanBannerHub）
final class GVYandexBannerManager: NSObject {
    
    private var currentAdView: AdView?
    private var isLoading = false
    private var isReady = false
    private var adUnitList: [String] = []
    private var adUnitIndex = 0
    private var loadStartAt: Date?
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    
    // MARK: - 广告配置和加载
    
    func prepareAdUnits() {
        adUnitList = GVAdsConfigTools.shared.bannerUnit()
            .components(separatedBy: ";")
            .filter { !$0.isEmpty }
        if !adUnitList.isEmpty {
            GVLogger.log("[Ad]", "获取到 keys: \(adUnitList.count) 个 | \(adUnitList)")
        } else {
            GVLogger.log("[Ad]", "未找到 keys")
        }
    }
    
    func hasReadyAd() -> Bool {
        return isReady && currentAdView != nil
    }
    
    func getActiveAdView() -> AdView? {
        return hasReadyAd() ? currentAdView : nil
    }
    
    func resetAd() {
        isReady = false
        currentAdView = nil
        GVLogger.log("[Ad]", "清空广告")
    }
    
    // MARK: - 广告展示
    
    /// 展示 Banner 广告（直接创建 BannerBoard 并展示）
    /// - Parameter viewController: 展示广告的视图控制器
    func showAd(from viewController: UIViewController) {
        guard hasReadyAd() else {
            return
        }
        
        let bannerController = GVBannerDisplayController()
        bannerController.modalPresentationStyle = .fullScreen
        viewController.present(bannerController, animated: true)
    }
    
    // MARK: - 广告加载管理
    
    func startLoading(moment: String? = nil) {
        GVLogger.log("[Ad]", "开始加载")
        
        if canStartLoading() {
            prepareAdUnits()
            if !adUnitList.isEmpty {
                adUnitIndex = 0
                isLoading = true
                loadStartAt = Date()
                Task {
                    await tryLoadNext(moment: moment)
                }
            } else {
                GVLogger.log("[Ad]", "❌ 无可用 keys")
                onAdFailed?()
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
            GVLogger.log("[Ad]", "❌ 所有 keys 加载失败")
            isLoading = false
            onAdFailed?()
            return
        }
        
        if let startTime = loadStartAt, Date().timeIntervalSince(startTime) > 100 {
            GVLogger.log("[Ad]", "加载超时 (100s)")
            isLoading = false
            onAdFailed?()
            return
        }
        
        let adKey = adUnitList[adUnitIndex]
        GVLogger.log("[Ad]", "尝试加载 key[\(adUnitIndex)]: \(adKey)")
        
        await MainActor.run {
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            var safeAreaInsets = UIEdgeInsets.zero
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                safeAreaInsets = window.safeAreaInsets
            } else {
                GVLogger.log("[Ad]", "⚠️ 获取 safe area 失败")
            }
            
            let adjustedHeight = screenHeight - safeAreaInsets.top - safeAreaInsets.bottom
            let bannerSize = BannerAdSize.inlineSize(withWidth: screenWidth, maxHeight: adjustedHeight)
            
            currentAdView = AdView(adUnitID: adKey, adSize: bannerSize)
            currentAdView?.delegate = self
            currentAdView?.translatesAutoresizingMaskIntoConstraints = false
            currentAdView?.loadAd()
        }
    }
    
    private func canStartLoading() -> Bool {
        if isReady { return false }
        if isLoading {
            guard let startTime = loadStartAt else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > 100
        }
        return true
    }
    
    private func loadNextAd() {
        adUnitIndex += 1
        if adUnitIndex < adUnitList.count {
            Task {
                await tryLoadNext()
            }
        } else {
            GVLogger.log("[Ad]", "❌ 所有 keys 加载失败")
            isLoading = false
            onAdFailed?()
        }
    }
}

// MARK: - AdViewDelegate

extension GVYandexBannerManager: AdViewDelegate {
    
    func adViewDidLoad(_ adView: AdView) {
        GVLogger.log("[Ad]", "✅ 加载成功 | key: \(adView.adUnitID)")
        isLoading = false
        isReady = true
        onAdReady?()
    }
    
    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        GVLogger.log("[Ad]", "❌ 加载失败 | key: \(adView.adUnitID) | error: \(error.localizedDescription)")
        loadNextAd()
    }
    
    func adViewDidClick(_ adView: AdView) {
        GVLogger.log("[Ad]", "用户点击广告")
        onAdClicked?()
    }
}
