//
//  GreenVPNApp.swift
//  GreenVPN
//
//  Created by sister on 2025/12/15.
//

import SwiftUI
import UIKit
import AppTrackingTransparency

@main
struct GreenVPNApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 全局工具单例：会话门面 + 路由协调器
    @StateObject private var homeSessionModel: GVHomeSessionModel
    @StateObject private var routeCoordinator = GVRouteCoordinator()
    @StateObject private var appLanguage = GVAppLanguage.shared
    
    // 启动引导 & 协议闸门
    @State private var introActive: Bool = true
    @State private var policyActive: Bool = false
    @State private var resumeOverlayActive: Bool = false
    @State private var backgroundFlag: Bool = false
    @State private var setupComplete: Bool = false
    
    @Environment(\.scenePhase) private var scenePhase
    
    private let consentKey = "GreenVPNPolicyAccepted_v1"
    private let attRequestedKey = "GreenVPNATTRequested_v1"
    private let attStatusKey = "GreenVPNATTStatus_v1"
    private let homeBootstrapDoneKey = "GreenVPNHomeBootstrapDone_v1"
    
    init() {
        let agent = GVSessionAgent()
        _homeSessionModel = StateObject(wrappedValue: GVHomeSessionModel(agent: agent))
        
        // 测试服：预热内购管理器，启动时尽早恢复 VIP 状态并检查订阅
        _ = GVPurchaseManager.shared
    }
    
    // MARK: - 辅助方法
    
    private func checkAndShowPolicyIfNeeded() {
        if !UserDefaults.standard.bool(forKey: consentKey) {
            policyActive = true
        }
    }
    
    private func hasConsent() -> Bool {
        return UserDefaults.standard.bool(forKey: consentKey)
    }

    private func hasRequestedATT() -> Bool {
        UserDefaults.standard.bool(forKey: attRequestedKey)
    }

    private func markATTRequested() {
        UserDefaults.standard.set(true, forKey: attRequestedKey)
        UserDefaults.standard.synchronize()
    }

    private func hasATTResult() -> Bool {
        UserDefaults.standard.object(forKey: attStatusKey) != nil
    }

    private func saveATTStatus(_ status: ATTrackingManager.AuthorizationStatus) {
        // 用 rawValue 存，避免后续 enum 变动造成反序列化问题
        UserDefaults.standard.set(status.rawValue, forKey: attStatusKey)
        UserDefaults.standard.synchronize()
    }

    private func hasBootstrappedAtHome() -> Bool {
        UserDefaults.standard.bool(forKey: homeBootstrapDoneKey)
    }

    private func markBootstrappedAtHome() {
        UserDefaults.standard.set(true, forKey: homeBootstrapDoneKey)
        UserDefaults.standard.synchronize()
    }

    /// 闸门：仅在「已同意隐私 + 已有 ATT 结果」时，才初始化 SDK 并触发一次广告加载
    private func bootstrapAdsIfAllowed(moment: String) {
        guard hasConsent() else { return }
        guard hasATTResult() else {
            GVLogger.log("SDK", "ATT 结果未就绪，跳过初始化/加载（闸门）")
            return
        }
        guard !hasBootstrappedAtHome() else { return }
        markBootstrappedAtHome()
        GVSDKBootstrap.shared.startIfNeeded()
        GVAdCoordinator.shared.prepareAll(moment: moment)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(homeSessionModel)
                    .environmentObject(routeCoordinator)
                    .environmentObject(appLanguage)
                    .environmentObject(GVNodeManager.shared)
                    .environmentObject(GVConnectionStatsManager.shared)
                    .environment(\.locale, appLanguage.locale)
                
                // 启动引导（只在首次进入期间覆盖）
                if introActive {
                    GVIntroCurtain(
                        onFinish: {
                            introActive = false
                            setupComplete = true
                            // 启动结束后，如果还没同意隐私，则展示协议闸门
                            checkAndShowPolicyIfNeeded()
                            // 老用户：进入主页时补一次加载（闸门会确保 ATT 已有结果才执行）
                            bootstrapAdsIfAllowed(moment: GVAdTrigger.appSplash)
                        },
                        onFinishWithAd: {
                            introActive = false
                            setupComplete = true
                            // 延迟一点时间后展示媒体
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showStartupContent()
                            }
                            // 启动结束后，如果还没同意隐私，则展示协议闸门
                            checkAndShowPolicyIfNeeded()
                            // 老用户：进入主页时补一次加载（闸门会确保 ATT 已有结果才执行）
                            bootstrapAdsIfAllowed(moment: GVAdTrigger.appSplash)
                        }
                    )
                    .environmentObject(appLanguage)
                    .ignoresSafeArea()
                }
                
                // 协议闸门（仅在未同意时显示）
                if policyActive {
                    GVPolicyGate(
                        onAccept: {
                            UserDefaults.standard.set(true, forKey: consentKey)
                            UserDefaults.standard.synchronize()
                            // 新用户：同意隐私后先请求 ATT，等结果返回后再初始化与进入主页
                            requestATTThenBootstrapAndEnter()
                        },
                        onDecline: {
                            // 保持与参考项目一致的"直接退出"行为
                            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                exit(0)
                            }
                        }
                    )
                    .environmentObject(appLanguage)
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
                
                // 后台返回覆盖页
                if resumeOverlayActive {
                    GVBackgroundSplashView {
                        resumeOverlayActive = false
                    }
                    .background(Color(UIColor.systemBackground).opacity(1.0))
                    .ignoresSafeArea()
                    .onAppear {
                        GVLogger.log("[Ad]", "后台启动页显示")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showResumeContent()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            resumeOverlayActive = false
                        }
                    }
                    .zIndex(9999)
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleSceneUpdate(newPhase)
        }
    }
    
    // MARK: - Scene Phase 处理
    
    private func handleSceneUpdate(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // 老用户：保持原流程（启动即初始化+加载），这里仅补一次 ATT 请求，不改变广告加载顺序
            if hasConsent() && !hasRequestedATT() {
                requestATTOnly()
            }
            enterActiveMode()
        case .inactive:
            break
        case .background:
            enterInactiveMode()
        @unknown default:
            break
        }
    }
    
    // MARK: - 场景状态处理
    
    private func enterActiveMode() {
        Task { [backgroundFlag, setupComplete] in
            // 每次回到前台时先刷新订阅状态，避免 VIP 已过期还按老状态拉广告
            await GVPurchaseManager.shared.checkSubscriptionStatus()
            
            // 只有在 App 启动完成，并且此前确实在后台时，才考虑展示返回页和拉广告
            guard backgroundFlag && setupComplete else { return }
            
            let contentManager = GVAdCoordinator.shared
            
            // 返回前台时检查配置是否过期（基础配置6小时，广告配置4小时）
            GVAPIManager.validateConfigCache()
            
            // 拉广告（会自动根据 VIP / adsOff 判断是否需要加载）
            contentManager.prepareAll(moment: GVAdTrigger.foreground)
            
            if canDisplayResumeOverlay(mediaCoordinator: contentManager) {
                GVLogger.log("[Ad]", "✅ 显示后台启动页")
                activateResumeOverlay()
            }
            
            // 重置后台标记
            self.backgroundFlag = false
        }
    }
    
    private func enterInactiveMode() {
        backgroundFlag = true
    }
    
    private func requestATTThenBootstrapAndEnter() {
        requestATTThenProceed {
            // 新用户：必须点完 ATT 才进入主页；进入后再按闸门触发一次初始化/加载
            policyActive = false
            bootstrapAdsIfAllowed(moment: GVAdTrigger.appSplash)
        }
    }

    private func requestATTOnly() {
        guard #available(iOS 14, *) else { return }
        guard !hasRequestedATT() else { return }

        markATTRequested()
        ATTrackingManager.requestTrackingAuthorization { status in
            self.saveATTStatus(status)
            switch status {
            case .authorized:
                GVLogger.log("App", "ATT 权限已授权")
            case .denied:
                GVLogger.log("App", "ATT 权限被拒绝")
            case .restricted:
                GVLogger.log("App", "ATT 权限受限")
            case .notDetermined:
                GVLogger.log("App", "ATT 权限未确定")
            @unknown default:
                GVLogger.log("App", "ATT 权限未知状态")
            }
        }
    }

    private func requestATTThenProceed(onFinish: (() -> Void)? = nil) {
        // iOS 14 以下没有 ATT：直接继续（并记录一个“已完成 ATT”占位，满足闸门）
        guard #available(iOS 14, *) else {
            // 低版本没有 ATT，认为闸门已满足
            UserDefaults.standard.set(1, forKey: attStatusKey)
            UserDefaults.standard.synchronize()
            onFinish?()
            return
        }

        if hasRequestedATT() {
            onFinish?()
            return
        }

        markATTRequested()
        ATTrackingManager.requestTrackingAuthorization { status in
            self.saveATTStatus(status)
            switch status {
            case .authorized:
                GVLogger.log("App", "ATT 权限已授权")
            case .denied:
                GVLogger.log("App", "ATT 权限被拒绝")
            case .restricted:
                GVLogger.log("App", "ATT 权限受限")
            case .notDetermined:
                GVLogger.log("App", "ATT 权限未确定")
            @unknown default:
                GVLogger.log("App", "ATT 权限未知状态")
            }

            DispatchQueue.main.async {
                onFinish?()
            }
        }
    }
    
    // MARK: - 启动页媒体展示
    
    private func showStartupContent() {
        // 检查隐私同意状态
        guard hasConsent() else {
            GVLogger.log("[Ad]", "⚠️ 隐私未同意，跳过展示")
            return
        }
        
        let contentManager = GVAdCoordinator.shared
        GVLogger.log("[Ad]", "🎬 开始展示启动页媒体")

        if contentManager.queryYa() {
            GVLogger.log("[Ad]", "❤️ 展示 Int/EM")
            contentManager.presentYa()
        } else {
            GVLogger.log("[Ad]", "❌ 无可用插屏媒体")
        }
    }
    
    // MARK: - 后台切前台媒体展示
    
    private func showResumeContent() {
        // 检查隐私同意状态
        guard hasConsent() else {
            GVLogger.log("[Ad]", "⚠️ 隐私未同意，跳过展示")
            return
        }
        
        let contentManager = GVAdCoordinator.shared
        
        if showTopPriorityContent(mediaCoordinator: contentManager) {
            deactivateResumeOverlay(after: 0.1)
        } else {
            GVLogger.log("[Ad]", "❌ 无可用媒体，等待3秒超时关闭")
        }
    }
    
    private func canDisplayResumeOverlay(mediaCoordinator: GVAdCoordinator) -> Bool {
        // 检查隐私状态
        guard hasConsent() else {
            GVLogger.log("[Ad]", "⚠️ 隐私未同意，跳过展示")
            return false
        }
        
        // 检查UI连接状态（如果UI还在连接中，不显示后台页）
        if homeSessionModel.phase == .inProgress {
            GVLogger.log("[Ad]", "⚠️ VPN 正在连接，跳过展示")
            return false
        }
        
        // 检查是否有广告正在展示
        if mediaCoordinator.isPresenting {
            GVLogger.log("[Ad]", "⚠️ 已有媒体在展示，跳过")
            return false
        }
        
        // 检查是否有媒体可以展示
        if mediaCoordinator.hasAny() {
            return true
        } else {
            GVLogger.log("[Ad]", "❌ 无可用媒体，跳过")
            return false
        }
    }
    
    private func activateResumeOverlay() {
        resumeOverlayActive = true
        // 3秒后自动关闭（展示逻辑由 GVBackgroundSplashView.onAppear 触发）
        deactivateResumeOverlay(after: 3.0)
    }
    
    private func deactivateResumeOverlay(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            resumeOverlayActive = false
        }
    }
    
    private func showTopPriorityContent(mediaCoordinator: GVAdCoordinator) -> Bool {
        // 仅保留插屏（Yandex legacy 或 EM）
        if mediaCoordinator.queryYa() {
            GVLogger.log("[Ad]", "❤️ 展示 Yandex Int/EM")
            mediaCoordinator.presentYa()
            return true
        }
        return false
    }
}
