//
//  GreenVPNApp.swift
//  GreenVPN
//
//  Created by sister on 2025/12/15.
//

import SwiftUI
import UIKit

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
                            // 保持与参考项目一致的“直接退出”行为
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
    }
}
