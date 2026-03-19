//
//  GVAdCoordinator.swift
//  GreenVPN
//
//  广告中心（统一入口 + 配置管理，混淆自 AdCenter/AdHub + AdShow）
//

import Foundation
import UIKit

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
    
    private let yIntHandler = GVYandexInterstitialManager()
    private let yEmIntHandler = GVYandexEMInterstitialManager()
    
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
    
    /// Yandex 插屏广告模式（legacy / EM / none）
    private var yandexMode: GVBaseConfigTools.YandexAdsMode {
        GVBaseConfigTools.shared.yandexAdsMode()
    }

    private var yandexModeLabel: String {
        switch yandexMode {
        case .none: return "none"
        case .legacy: return "yandex"
        case .em: return "em"
        }
    }

    /// Yandex 插屏是否开启（包含 legacy 和 EM 两种模式）
    private var isYandexInterstitialEnabled: Bool {
        switch yandexMode {
        case .none:
            return false
        case .legacy, .em:
            return true
        }
    }
    
    // MARK: - 状态检查方法
    
    /// 检查 Yandex 插屏广告是否可用
    func queryYa() -> Bool {
        guard isYandexInterstitialEnabled else { return false }

        switch yandexMode {
        case .none:
            return false
        case .legacy:
            return yIntHandler.hasReadyAd()
        case .em:
            return yEmIntHandler.hasReadyAd()
        }
    }
    
    /// 检查是否有 Yandex 广告可用
    func hasYa() -> Bool {
        guard isAdsEnabled else { return false }
        return queryYa()
    }
    
    /// 检查是否有任何广告可用
    func hasAny() -> Bool {
        guard isAdsEnabled else { return false }
        return queryYa()
    }
    
    // MARK: - 广告加载管理
    
    /// 预热插屏广告
    /// - Parameter moment: 广告触发时机字符串（可选）
    func prepareAll(moment: String? = nil) {
        GVLogger.log("[Ad]", "加载插屏广告 | moment: \(moment ?? "nil") | mode: \(yandexModeLabel)")
        
        // 展示过程中不再加载下一条，避免“边展示边加载”带来的顺序问题
        if isPresenting {
            GVLogger.log("[Ad]", "当前有广告正在展示，跳过本次预热")
            return
        }

        guard isAdsEnabled else {
            GVLogger.log("[Ad]", "广告已禁用，跳过加载")
            return
        }

        // 仅加载插屏：Yandex legacy 或 EM（取决于 adsType）
        guard isYandexInterstitialEnabled else { return }
        switch yandexMode {
        case .none:
            return
        case .legacy:
            yIntHandler.startLoading(moment: moment)
        case .em:
            yEmIntHandler.startLoading(moment: moment)
        }
    }
    
    /// 预热 Yandex 插屏广告
    /// - Parameters:
    ///   - onAdReady: 加载成功回调
    ///   - onAdFailed: 加载失败回调
    func prepareYa(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        GVLogger.log("[Ad]", "加载插屏 | mode: \(yandexModeLabel)")
        
        // 展示过程中不再加载下一条，保持“关闭后再拉下一条”的语义
        if isPresenting {
            GVLogger.log("[Ad]", "当前有广告正在展示，跳过本次预热")
            return
        }

        guard isAdsEnabled, isYandexInterstitialEnabled else {
            onAdReady?()
            return
        }

        if queryYa() {
            onAdReady?()
            return
        }

        switch yandexMode {
        case .none:
            onAdFailed?()
        case .legacy:
            yIntHandler.onAdReady = onAdReady
            yIntHandler.onAdFailed = onAdFailed
            yIntHandler.startLoading()
        case .em:
            yEmIntHandler.onAdReady = onAdReady
            yEmIntHandler.onAdFailed = onAdFailed
            yEmIntHandler.startLoading()
        }
    }
    
    // MARK: - 广告展示
    
    /// 展示 Yandex 插屏广告
    /// - Parameter onClose: 关闭回调
    func presentYa(onClose: (() -> Void)? = nil) {
        presentYandexInterstitial(onClose: onClose)
    }
    
    // MARK: - 私有展示方法
    
    /// 从根视图控制器展示 Yandex 插屏广告
    private func presentYandexInterstitial(onClose: (() -> Void)? = nil) {
        guard let rootVC = findTopViewController() else { return }
        guard isYandexInterstitialEnabled else { return }

        switch yandexMode {
        case .none:
            return
        case .legacy:
            GVLogger.log("[Ad]", "展示插屏 | mode: yandex")
            yIntHandler.onAdClosed = onClose
            yIntHandler.showAd(from: rootVC, moment: nil)
        case .em:
            GVLogger.log("[Ad]", "展示插屏 | mode: em")
            yEmIntHandler.onAdClosed = onClose
            yEmIntHandler.showAd(from: rootVC, moment: nil)
        }
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
