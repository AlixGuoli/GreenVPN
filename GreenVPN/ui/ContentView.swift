//
//  ContentView.swift
//  GreenVPN
//
//  Created by sister on 2025/12/15.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var homeSession: GVHomeSessionModel
    @EnvironmentObject private var routeCoordinator: GVRouteCoordinator
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    var body: some View {
        NavigationStack(path: $routeCoordinator.path) {
            HomeView()
            .navigationDestination(for: GVRoute.self) { route in
                switch route {
                case .connecting:
                    ConnectingView()
                case .result(let result):
                    ResultView(
                        result: result,
                        onClose: {
                            // 关闭结果页
                            routeCoordinator.reset()
                            homeSession.clearOutcome()
                        }
                    )
                case .nodeList:
                    // 预留节点列表页面，占位实现
                    Text(appLanguage.localized("gv_node_list_title", comment: "Node list placeholder"))
                }
            }
            // 根据 ViewModel 状态自动跳转
            .onChange(of: homeSession.showingProgress) { show in
                if show {
                    routeCoordinator.showConnecting()
                } else {
                    routeCoordinator.dismissConnectingIfNeeded()
                }
            }
            .onChange(of: homeSession.outcome) { result in
                if let r = result {
                    routeCoordinator.showResult(r)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        GVLanguageView()
                    } label: {
                        Image(systemName: "globe")
                    }
                }
            }
        }
    }
}

// MARK: - 主页面（状态 + 按钮）

private struct HomeView: View {
    @EnvironmentObject private var homeSession: GVHomeSessionModel
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Spacer()
                
                // 状态显示
                VStack(spacing: 15) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: statusIcon)
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        )
                        .shadow(color: statusColor.opacity(0.3), radius: 20)
                    
                    Text(statusText)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(detailText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    homeSession.handlePrimaryAction()
                } label: {
                    HStack {
                        if homeSession.phase == .inProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(buttonText)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(buttonColor)
                    .cornerRadius(28)
                    .shadow(color: buttonColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(homeSession.phase == .inProgress)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            
            // 覆盖在主页上的断开确认视图（不是单独页面）
            if homeSession.showDisconnectConfirm {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                DisconnectConfirmView(
                    onCancel: {
                        homeSession.cancelDisconnect()
                    },
                    onConfirm: {
                        homeSession.confirmDisconnect()
                    }
                )
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle(appLanguage.localized("gv_home_title", comment: "Home navigation title"))
    }
    
    // 状态颜色
    private var statusColor: Color {
        switch homeSession.phase {
        case .online:
            return .green
        case .inProgress:
            return .orange
        case .idle:
            return .gray
        case .failed:
            return .red
        }
    }
    
    // 状态图标
    private var statusIcon: String {
        switch homeSession.phase {
        case .online:
            return "checkmark.shield.fill"
        case .inProgress:
            return "arrow.triangle.2.circlepath"
        case .idle:
            return "shield.slash.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    // 状态文字
    private var statusText: String {
        switch homeSession.phase {
        case .online:
            return appLanguage.localized("gv_home_status_connected", comment: "Status connected")
        case .inProgress:
            return appLanguage.localized("gv_home_status_connecting", comment: "Status connecting")
        case .idle:
            return appLanguage.localized("gv_home_status_disconnected", comment: "Status disconnected")
        case .failed:
            return appLanguage.localized("gv_home_status_failed", comment: "Status failed")
        }
    }
    
    // 详细状态
    private var detailText: String {
        switch homeSession.phase {
        case .online:
            return appLanguage.localized("gv_home_detail_connected", comment: "Detail text connected")
        case .inProgress:
            return appLanguage.localized("gv_home_detail_connecting", comment: "Detail text connecting")
        case .idle:
            return appLanguage.localized("gv_home_detail_idle", comment: "Detail text idle")
        case .failed:
            return appLanguage.localized("gv_home_detail_failed", comment: "Detail text failed")
        }
    }
    
    // 按钮文字
    private var buttonText: String {
        switch homeSession.phase {
        case .online:
            return appLanguage.localized("gv_home_button_disconnect", comment: "Button disconnect")
        case .inProgress:
            return appLanguage.localized("gv_home_button_connecting", comment: "Button connecting")
        case .idle, .failed:
            return appLanguage.localized("gv_home_button_connect", comment: "Button connect")
        }
    }
    
    // 按钮颜色
    private var buttonColor: Color {
        switch homeSession.phase {
        case .online:
            return .red
        case .inProgress:
            return .orange
        case .idle, .failed:
            return .blue
        }
    }
}

// MARK: - 连接页 / 结果页
// ConnectingView 与 ResultView 已迁移到单独文件 ConnectingView.swift / ResultView.swift

// MARK: - 断开确认页

private struct DisconnectConfirmView: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    var body: some View {
        VStack(spacing: 20) {
            Text(appLanguage.localized("gv_disconnect_title", comment: "Disconnect confirm title"))
                .font(.title2)
                .fontWeight(.semibold)
            Text(appLanguage.localized("gv_disconnect_message", comment: "Disconnect confirm message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button(appLanguage.localized("gv_common_cancel", comment: "Cancel")) {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(22)
                
                Button(appLanguage.localized("gv_disconnect_action", comment: "Disconnect action")) {
                    onConfirm()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.red)
                .cornerRadius(22)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .navigationTitle(appLanguage.localized("gv_disconnect_nav_title", comment: "Disconnect nav title"))
    }
}

#Preview {
    ContentView()
        .environmentObject(GVHomeSessionModel(agent: GVSessionAgent()))
        .environmentObject(GVRouteCoordinator())
}
