//
//  GVAdCoordinator.swift
//  GreenVPN
//
//  广告中心（统一入口 + 配置管理，混淆自 AdCenter/AdHub + AdShow）
//

import Foundation
import UIKit
import YandexMobileAds

/// 广告总管理器（单例，混淆自 AdHub）
final class GVAdCoordinator {
    
    static let shared = GVAdCoordinator()
    
    /// 是否有广告正在展示
    var isPresenting = false
    
    /// VIP 标志：与内购管理器同步
    private var premiumStatus: Bool {
        GVPurchaseManager.shared.isVIP
    }
    
    // MARK: - 广告管理器实例
    
    private let gAdHandler = GVAdMobInterstitialManager.shared
    private let yBanHandler = GVYandexBannerManager()
    private let yIntHandler = GVYandexInterstitialManager()
    
    private init() {}
    
    // MARK: - 广告开关检查
    
    /// 广告总开关（检查 VIP 和 adsOff）
    private var isAdsEnabled: Bool {
        if premiumStatus {
            GVLogger.log("[Ad]", "广告关闭 | 原因: VIP用户")
            return false
        }
        
        let isAdsOff = GVBaseConfigTools.shared.getAdsOff() ?? false
        GVLogger.log("[Ad]", "广告开关: \(isAdsOff ? "关闭" : "开启")")
        
        return !isAdsOff
    }
    
    /// Yandex 广告是否开启（检查 adsType 是否包含 "y"）
    private var isYandexEnabled: Bool {
        guard let adType = GVBaseConfigTools.shared.adsType() else {
            return false
        }
        let types = adType.components(separatedBy: ";")
        if types.contains("y") {
            return true
        }
        GVLogger.log("[Ad]", "Yandex 关闭")
        return false
    }
    
    /// AdMob 广告是否开启（检查 adsType 是否包含 "a" 且已连接）
    private var isAdmobEnabled: Bool {
        guard let adType = GVBaseConfigTools.shared.adsType() else {
            return false
        }
        let types = adType.components(separatedBy: ";")
        if types.contains("a") {
            if GVAppState.shared.currentPhase == .online {
                return true
            }
        }
        GVLogger.log("[Ad]", "Admob 关闭 | 原因: 未连接或类型不匹配")
        return false
    }
    
    // MARK: - 状态检查方法
    
    /// 检查 Yandex Banner 广告是否可用
    func queryBa() -> Bool {
        return yBanHandler.hasReadyAd()
    }
    
    /// 检查 Yandex 插屏广告是否可用
    func queryYa() -> Bool {
        return yIntHandler.hasReadyAd()
    }
    
    /// 检查 AdMob 插屏广告是否可用（需要已连接）
    func queryGa() -> Bool {
        if GVAppState.shared.currentPhase == .online {
            return gAdHandler.hasReadyAd()
        } else {
            gAdHandler.resetAd()
            return false
        }
    }
    
    /// 检查是否有 Yandex 广告可用
    func hasYa() -> Bool {
        guard isAdsEnabled else { return false }
        return queryBa() || queryYa()
    }
    
    /// 检查是否有任何广告可用
    func hasAny() -> Bool {
        guard isAdsEnabled else { return false }
        return hasYa() || queryGa()
    }
    
    // MARK: - 广告加载管理
    
    /// 预热所有广告
    /// - Parameter moment: 广告触发时机字符串（可选）
    func prepareAll(moment: String? = nil) {
        GVLogger.log("[Ad]", "加载所有广告 | moment: \(moment ?? "nil")")
        
        guard isAdsEnabled else {
            GVLogger.log("[Ad]", "广告已禁用，跳过加载")
            return
        }
        
        if isYandexEnabled {
            yBanHandler.startLoading(moment: moment)
            yIntHandler.startLoading(moment: moment)
        }
        
        if isAdmobEnabled {
            gAdHandler.startLoading(moment: moment)
        }
    }
    
    /// 预热 Yandex Banner 广告
    /// - Parameters:
    ///   - onAdReady: 加载成功回调
    ///   - onAdFailed: 加载失败回调
    func prepareBa(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        GVLogger.log("[Ad]", "加载 Yandex Banner")
        
        if isAdsEnabled && isYandexEnabled {
            if queryBa() {
                onAdReady?()
            } else {
                yBanHandler.onAdReady = onAdReady
                yBanHandler.onAdFailed = onAdFailed
                yBanHandler.startLoading()
            }
        } else {
            onAdReady?()
        }
    }
    
    /// 预热 Yandex 插屏广告
    /// - Parameters:
    ///   - onAdReady: 加载成功回调
    ///   - onAdFailed: 加载失败回调
    func prepareYa(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        GVLogger.log("[Ad]", "加载 Yandex Int")
        
        if isAdsEnabled && isYandexEnabled {
            if queryYa() {
                onAdReady?()
            } else {
                yIntHandler.onAdReady = onAdReady
                yIntHandler.onAdFailed = onAdFailed
                yIntHandler.startLoading()
            }
        } else {
            onAdReady?()
        }
    }
    
    /// 预热 AdMob 插屏广告
    /// - Parameters:
    ///   - moment: 广告触发时机字符串（可选）
    ///   - onAdReady: 加载成功回调
    ///   - onAdFailed: 加载失败回调
    func prepareGa(moment: String? = nil, onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        GVLogger.log("[Ad]", "加载 Admob Int")
        
        if isAdsEnabled && isAdmobEnabled {
            gAdHandler.onAdReady = onAdReady
            gAdHandler.onAdFailed = onAdFailed
            gAdHandler.startLoading(moment: moment)
        } else {
            onAdReady?()
        }
    }
    
    // MARK: - 广告展示
    
    /// 展示 Yandex Banner 广告
    func presentBa() {
        presentBannerAd()
    }
    
    /// 展示 Yandex 插屏广告
    /// - Parameter onClose: 关闭回调
    func presentYa(onClose: (() -> Void)? = nil) {
        presentYandexInterstitial(onClose: onClose)
    }
    
    /// 展示 AdMob 插屏广告
    /// - Parameter moment: 广告触发时机字符串
    func presentGa(moment: String?) {
        presentAdmobInterstitial(moment: moment)
    }
    
    /// 获取 Banner 广告视图（用于自定义展示）
    /// - Returns: Banner 广告视图，如果可用
    func obtainBa() -> AdView? {
        let adView = yBanHandler.getActiveAdView()
        yBanHandler.restartLoading()
        return adView
    }
    
    /// 设置 Banner 广告点击回调（用于 BannerBoard）
    /// - Parameter callback: 点击回调
    func setBannerClickCallback(_ callback: @escaping () -> Void) {
        yBanHandler.onAdClicked = callback
    }
    
    // MARK: - 私有展示方法
    
    /// 从根视图控制器展示 Yandex 插屏广告
    private func presentYandexInterstitial(onClose: (() -> Void)? = nil) {
        guard let rootVC = findTopViewController() else { return }
        yIntHandler.onAdClosed = onClose
        yIntHandler.showAd(from: rootVC, moment: nil)
    }
    
    /// 从根视图控制器展示 Banner 广告
    private func presentBannerAd() {
        guard let rootVC = findTopViewController() else { return }
        yBanHandler.showAd(from: rootVC)
    }
    
    /// 从根视图控制器展示 AdMob 插屏广告
    private func presentAdmobInterstitial(moment: String?) {
        guard let rootVC = findTopViewController() else { return }
        gAdHandler.showAd(from: rootVC, moment: moment)
    }
    
    // MARK: - 工具方法
    
    /// 获取根视图控制器
    private func findTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var rootVC = window.rootViewController
        while let presented = rootVC?.presentedViewController {
            rootVC = presented
        }
        
        return rootVC
    }
}
