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
                            policyActive = false
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
            requestTrackingAccess()
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
    
    /// 请求 ATT 追踪权限
    private func requestTrackingAccess() {
        if #available(iOS 14, *) {
            // 延迟一点时间，确保应用完全启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    switch status {
                    case .authorized:
                        GVLogger.log("App", "ATT 权限已授权")
                    case .denied:
                        GVLogger.log("App", "ATT 权限被拒绝")
                    case .notDetermined:
                        GVLogger.log("App", "ATT 权限未确定")
                    case .restricted:
                        GVLogger.log("App", "ATT 权限受限")
                    @unknown default:
                        GVLogger.log("App", "ATT 权限未知状态")
                    }
                }
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
