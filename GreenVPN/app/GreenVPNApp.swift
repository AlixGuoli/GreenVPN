//
//  GreenVPNApp.swift
//  GreenVPN
//
//  Created by sister on 2025/12/15.
//

import SwiftUI

@main
struct GreenVPNApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 全局工具单例：会话门面 + 路由协调器
    @StateObject private var homeSessionModel: GVHomeSessionModel
    @StateObject private var routeCoordinator = GVRouteCoordinator()
    
    init() {
        let agent = GVSessionAgent()
        _homeSessionModel = StateObject(wrappedValue: GVHomeSessionModel(agent: agent))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(homeSessionModel)
                .environmentObject(routeCoordinator)
        }
    }
}
