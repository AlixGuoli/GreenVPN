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
    @State private var showIntroCurtain: Bool = true
    @State private var showPolicyGate: Bool = false
    
    @Environment(\.scenePhase) private var scenePhase
    
    private let policyAcceptedKey = "GreenVPNPolicyAccepted_v1"
    
    init() {
        let agent = GVSessionAgent()
        _homeSessionModel = StateObject(wrappedValue: GVHomeSessionModel(agent: agent))
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
                if showIntroCurtain {
                    GVIntroCurtain {
                        showIntroCurtain = false
                        // 启动结束后，如果还没同意隐私，则展示协议闸门
                        if !UserDefaults.standard.bool(forKey: policyAcceptedKey) {
                            showPolicyGate = true
                        }
                    }
                    .environmentObject(appLanguage)
                    .ignoresSafeArea()
                }
                
                // 协议闸门（仅在未同意时显示）
                if showPolicyGate {
                    GVPolicyGate(
                        onAccept: {
                            UserDefaults.standard.set(true, forKey: policyAcceptedKey)
                            showPolicyGate = false
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
            }
        }
        .onChange(of: scenePhase) { newPhase in
            didChangeScenePhase(newPhase)
        }
    }
    
    // MARK: - Scene Phase 处理
    
    private func didChangeScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            askForTrackingAuthorization()
        case .inactive:
            break
        case .background:
            break
        @unknown default:
            break
        }
    }
    
    /// 请求 ATT 追踪权限
    private func askForTrackingAuthorization() {
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
}
