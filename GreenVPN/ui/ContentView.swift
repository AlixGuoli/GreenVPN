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
    
    // 防止同一个结果被重复展示造成"闪一下又回来"的现象
    @State private var lastOutcomeShown: SessionOutcome? = nil
    
    var body: some View {
        NavigationStack(path: $routeCoordinator.path) {
            HomeScreen()
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
                    GVNodeListView()
                case .settings:
                    GVSettingsView()
                case .toolbox:
                    GVToolboxView()
                case .purchase:
                    GVPurchaseView()
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
            .onChange(of: homeSession.outcome) { newValue in
                if let r = newValue {
                    // 只在"本轮第一次"结果变化时跳转，避免重复 push 同一个结果页
                    if lastOutcomeShown != r {
                        lastOutcomeShown = r
                        routeCoordinator.showResult(r)
                        
                        // 根据结果类型展示媒体
                        switch r {
                        case .connectSuccess:
                            displayMedia(moment: GVAdTrigger.connect)
                        case .disconnectSuccess:
                            displayMedia(moment: GVAdTrigger.disconnect)
                        case .connectFail:
                            // 连接失败不出媒体
                            break
                        }
                    }
                } else {
                    // 结果被清空（例如在结果页点击关闭）后，重置标记，下一轮可以再次展示
                    lastOutcomeShown = nil
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
    
    // MARK: - 媒体展示
    
    /// 展示媒体（根据结果类型）
    private func displayMedia(moment: String) {
        let mediaCoordinator = GVAdCoordinator.shared
        
        // 检查是否有媒体可以展示
        guard mediaCoordinator.hasAny() else {
            GVLogger.log("[Ad]", "无可用媒体，跳过展示")
            return
        }
        
        // 按优先级展示媒体：AdMob > Yandex Banner > Yandex Int
        if mediaCoordinator.queryGa() {
            GVLogger.log("[Ad]", "展示 AdMob")
            mediaCoordinator.presentGa(moment: moment)
        } else if mediaCoordinator.queryBa() {
            GVLogger.log("[Ad]", "展示 Yandex Banner")
            mediaCoordinator.presentBa()
        } else if mediaCoordinator.queryYa() {
            GVLogger.log("[Ad]", "展示 Yandex Int")
            mediaCoordinator.presentYa()
        }
    }
}

// MARK: - 主页面

private struct HomeScreen: View {
    @EnvironmentObject private var homeSession: GVHomeSessionModel
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @EnvironmentObject private var nodeManager: GVNodeManager
    @EnvironmentObject private var routeCoordinator: GVRouteCoordinator
    @EnvironmentObject private var statsManager: GVConnectionStatsManager
    @State private var showSwitchNodeAlert = false
    
    var body: some View {
        ZStack {
            // 背景：深色径向渐变 + 轻微噪点纹理
            ZStack {
                RadialGradient(
                    colors: [
                        Color(red: 6/255, green: 40/255, blue: 45/255),
                        Color(red: 2/255, green: 10/255, blue: 16/255)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.height * 0.8
                )
                .ignoresSafeArea()
                
                NoiseOverlay()
                    .ignoresSafeArea()
                    .blendMode(.overlay)
                    .opacity(0.10)
            }
            
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部栏：Logo + 标题 + 右侧设置入口
                    HStack(spacing: 12) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 5)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(GVAppInfo.displayName)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                    Text(statusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.85))
                }
                
                Spacer()
                
                // 右上角按钮：Premium 入口 + 设置入口
                HStack(spacing: 8) {
                    // Premium 入口（钻石图标）
                    Button {
                        routeCoordinator.showPurchase()
                    } label: {
                        Image("vip")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .padding(5)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                            )
                    }
                    
                    // 设置按钮
                    Button {
                        routeCoordinator.showSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                            )
                    }
                }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    
                    // 卡片1：连接状态卡片（大卡片，包含圆环和按钮）
                    ConnectionStatusCard(
                        phase: homeSession.phase,
                        connectionDuration: homeSession.connectionDuration,
                        detailText: detailText,
                        buttonText: buttonText,
                        onButtonTap: {
                    homeSession.handlePrimaryAction()
                        }
                    )
                    .padding(.horizontal, 20)
                    
                    // 卡片2：当前节点卡片
                    if let selectedNode = nodeManager.selectedNode {
                        CurrentNodeCard(
                            node: selectedNode,
                            onSwitchNodeAlert: {
                                showSwitchNodeAlert = true
                            }
                        )
                            .padding(.horizontal, 20)
                        }
                    
                    // 卡片3：功能入口（2x2 网格）
                    FunctionGridCard(
                        onNodeListTap: {
                            // 如果已连接，显示提示
                            if homeSession.phase == .online {
                                showSwitchNodeAlert = true
                            } else {
                                routeCoordinator.showNodeList()
                            }
                    }
                    )
                    .padding(.horizontal, 20)
                    
                    // 卡片4：工具箱入口卡片
                    ToolboxEntryCard()
                        .padding(.horizontal, 20)
                    
                    // 卡片5：连接统计卡片（直接展示总时长 / 次数 / 今日时长）
                    ConnectionStatsCard(
                        totalDuration: statsManager.totalDuration,
                        totalConnections: statsManager.totalConnections,
                        todayDuration: statsManager.todayDuration
                    )
                    .padding(.horizontal, 20)
                                        
                    // 底部留白，避免被系统手势栏遮挡
                    Spacer()
                        .frame(height: 40)
                }
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
            
            // 切换节点提示弹窗
            if showSwitchNodeAlert {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                SwitchNodeAlertView(
                    onCancel: {
                        showSwitchNodeAlert = false
                    },
                    onConfirm: {
                        showSwitchNodeAlert = false
                    }
                )
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
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
    
    // 格式化连接时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
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
        ZStack {
            VStack(spacing: 18) {
                // 顶部图标：用更克制的红色点缀，保持整体偏冷的深色风格
                ZStack {
                    Circle()
                        .fill(Color(red: 0.5, green: 0.1, blue: 0.1).opacity(0.28))
                        .frame(width: 60, height: 60)
                    Image(systemName: "power")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.98, green: 0.36, blue: 0.36))
                }
                
                // 标题 & 文案
                VStack(spacing: 8) {
                    Text(appLanguage.localized("gv_disconnect_title", comment: "Disconnect confirm title"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(appLanguage.localized("gv_disconnect_message", comment: "Disconnect confirm message"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
            
                // 按钮：上下排列
                VStack(spacing: 10) {
                    Button {
                        onConfirm()
                    } label: {
                        Text(appLanguage.localized("gv_disconnect_action", comment: "Disconnect action"))
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.32, blue: 0.32),
                                        Color(red: 0.82, green: 0.12, blue: 0.24)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button {
                    onCancel()
                    } label: {
                        Text(appLanguage.localized("gv_common_cancel", comment: "Cancel"))
                            .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(Color.white.opacity(0.92))
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 9/255, green: 48/255, blue: 54/255).opacity(0.96),
                                Color(red: 3/255, green: 18/255, blue: 24/255).opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
                    )
            )
            .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 10)
        }
        // 居中弹窗，由外层遮罩负责全屏对齐
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - 自定义图形组件：钥匙徽章 & 语言图标


/// 简化版钥匙图形（头部圆 + 柄 + 齿）
struct KeyGlyphView: View {
    let isOn: Bool
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let headRadius = h * 0.4
            
            ZStack(alignment: .leading) {
                // 柄
                RoundedRectangle(cornerRadius: h * 0.18, style: .continuous)
                    .frame(width: w * 0.6, height: h * 0.28)
                    .offset(x: headRadius * 0.9, y: h * 0.08)
                
                // 齿
                VStack(alignment: .leading, spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .frame(width: w * 0.22, height: h * 0.11)
                    RoundedRectangle(cornerRadius: 2)
                        .frame(width: w * 0.18, height: h * 0.11)
                    RoundedRectangle(cornerRadius: 2)
                        .frame(width: w * 0.22, height: h * 0.11)
                }
                .offset(x: w * 0.72, y: h * 0.18)
                
                // 头部圆
                Circle()
                    .frame(width: headRadius * 2, height: headRadius * 2)
                    .offset(x: 0, y: h * 0.05)
                
                // 中空孔
                Circle()
                    .frame(width: headRadius * 0.9, height: headRadius * 0.9)
                    .blendMode(.destinationOut)
                    .offset(x: headRadius * 0.4, y: h * 0.2)
                
                if isOn {
                    // 已连接时，在钥匙孔内画一个小勾，增加辨识度
                    Image(systemName: "checkmark")
                        .font(.system(size: headRadius * 0.7, weight: .bold))
                        .offset(x: headRadius * 0.38, y: h * 0.19)
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                }
            }
            .compositingGroup()
        }
    }
}

/// 月桂弧线：用于围绕钥匙的金色装饰
private struct LaurelRingView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2.0
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // 左右各画一串简化叶片
        func addSide(_ sign: CGFloat) {
            let leafCount = 6
            for i in 0..<leafCount {
                let t = CGFloat(i) / CGFloat(leafCount - 1)
                let angle = CGFloat.pi * (0.6 + 0.6 * t) * sign
                let leafCenter = CGPoint(
                    x: center.x + cos(angle) * radius * 0.8,
                    y: center.y + sin(angle) * radius * 0.8
                )
                let leafWidth: CGFloat = 14
                let leafHeight: CGFloat = 6
                
                let leafRect = CGRect(
                    x: leafCenter.x - leafWidth / 2,
                    y: leafCenter.y - leafHeight / 2,
                    width: leafWidth,
                    height: leafHeight
                )
                path.addRoundedRect(in: leafRect, cornerSize: CGSize(width: leafHeight / 2, height: leafHeight / 2))
                }
        }
        
        addSide(1)
        addSide(-1)
        return path
    }
}


/// 中央连接图标：立体圆形能量核心（中间灰圆预留给状态图标）
struct CoreOrbView: View {
    let phase: SessionPhase
    
    @State private var glowStrength: Double = 0.3
    @State private var shakePhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let outerRadius = size / 2
            let ringWidth = size * 0.18
            let innerRadius = outerRadius - ringWidth
            
            ZStack {
                // 背后柔光
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                coreColors.first!.opacity(glowStrength),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.9
                        )
                    )
                    .frame(width: size * 1.15, height: size * 1.15)
                    .blur(radius: 26)
                
                // 立体圆环（中空，为后续图标预留空间）
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    coreColors[0],
                                    coreColors[1],
                                    Color.black.opacity(0.95)
                                ],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: outerRadius
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.22), lineWidth: 1.6)
                        )
                    
                    // 中心挖空
                    Circle()
                        .fill(Color.black)
                        .frame(width: innerRadius * 2, height: innerRadius * 2)
                        .blendMode(.destinationOut)
                }
                .frame(width: outerRadius * 2, height: outerRadius * 2)
                .shadow(color: coreColors[0].opacity(0.9), radius: 20, x: 0, y: 10)
                .compositingGroup()
                
                // 中心灰圆 + 状态图标
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                    
                    if let iconName = centerIconName {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: innerRadius * 0.95, height: innerRadius * 0.95)
                            .opacity(centerIconOpacity)
                    }
                }
                .frame(width: innerRadius * 1.4, height: innerRadius * 1.4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(x: phase == .failed ? sin(shakePhase) * 4 : 0)
            .onAppear { startAnimations() }
            .onChange(of: phase) { _ in startAnimations() }
        }
    }
    
    private var coreColors: [Color] {
        switch phase {
        case .idle:
            return [
                Color(red: 28/255, green: 132/255, blue: 108/255),
                Color(red: 8/255, green: 78/255, blue: 70/255)
            ]
        case .inProgress:
            return [
                Color(red: 80/255, green: 230/255, blue: 170/255),
                Color(red: 12/255, green: 160/255, blue: 135/255)
            ]
        case .online:
            return [
                Color(red: 130/255, green: 245/255, blue: 185/255),
                Color(red: 40/255, green: 185/255, blue: 140/255)
            ]
        case .failed:
            return [
                Color(red: 245/255, green: 120/255, blue: 110/255),
                Color(red: 160/255, green: 40/255, blue: 40/255)
            ]
        }
    }
    
    /// 中心图标名称：对应三个状态图标资源
    private var centerIconName: String? {
        switch phase {
        case .online:
            return "connected"
        case .inProgress:
            return "connecting"
        case .idle, .failed:
            return "disconnect"
        }
    }
    
    /// 中心图标透明度：未连接时略微降低亮度
    private var centerIconOpacity: Double {
        switch phase {
        case .online, .inProgress:
            return 0.95
        case .idle:
            return 0.7
        case .failed:
            return 0.8
        }
    }
    
    private func startAnimations() {
        // 仅让背后光晕呼吸，圆本体不缩放
        let duration: Double
        let targetGlow: Double
        
        switch phase {
        case .idle:
            duration = 3.0
            targetGlow = 0.25
        case .inProgress:
            duration = 0.9
            targetGlow = 0.9
        case .online:
            duration = 1.8
            targetGlow = 0.7
        case .failed:
            duration = 1.2
            targetGlow = 0.4
        }
        
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            glowStrength = targetGlow
        }
        
        // 失败时抖动
        if phase == .failed {
            withAnimation(.linear(duration: 0.1).repeatForever(autoreverses: true)) {
                shakePhase = .pi * 2
            }
        } else {
            shakePhase = 0
        }
    }
}

/// 高光弧线，用于立体圆的上方反光
private struct ArcHighlight: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(center: center,
                    radius: radius * 0.7,
                    startAngle: .degrees(210),
                    endAngle: .degrees(330),
                    clockwise: false)
        return path
    }
}

/// 语言图标：手绘简化版地球，而不是系统 SF Symbols
private struct LanguageGlyphView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = min(w, h) / 2
            let center = CGPoint(x: w / 2, y: h / 2)
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.4)
                
                Path { p in
                    // 纵向经线
                    p.addArc(center: center, radius: r * 0.7, startAngle: .degrees(-100), endAngle: .degrees(100), clockwise: false)
                    p.move(to: CGPoint(x: center.x, y: center.y - r * 0.7))
                    p.addArc(center: center, radius: r * 0.7, startAngle: .degrees(80), endAngle: .degrees(280), clockwise: false)
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 0.9)
                
                Path { p in
                    // 水平纬线
                    p.addArc(center: center, radius: r * 0.55, startAngle: .degrees(200), endAngle: .degrees(-20), clockwise: true)
                    p.move(to: CGPoint(x: center.x - r * 0.8, y: center.y))
                    p.addArc(center: center, radius: r * 0.8, startAngle: .degrees(350), endAngle: .degrees(190), clockwise: true)
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 0.8)
            }
        }
    }
}

/// 背景用的简化“节点连线”形状，用几何线条营造 VPN 拓扑感
/// 用于背景的山脉轮廓，根据深浅层次绘制不同轮廓
private struct MountainLayer: Shape {
    enum Depth {
        case far, mid, near
    }
    
    let depth: Depth
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        func y(_ value: CGFloat) -> CGFloat { h * value }
        func x(_ value: CGFloat) -> CGFloat { w * value }
        
        switch depth {
        case .far:
            path.move(to: CGPoint(x: 0, y: y(0.6)))
            path.addCurve(to: CGPoint(x: x(0.35), y: y(0.45)),
                          control1: CGPoint(x: x(0.12), y: y(0.50)),
                          control2: CGPoint(x: x(0.22), y: y(0.40)))
            path.addCurve(to: CGPoint(x: x(0.7), y: y(0.55)),
                          control1: CGPoint(x: x(0.48), y: y(0.52)),
                          control2: CGPoint(x: x(0.6), y: y(0.62)))
            path.addCurve(to: CGPoint(x: w, y: y(0.5)),
                          control1: CGPoint(x: x(0.8), y: y(0.48)),
                          control2: CGPoint(x: x(0.92), y: y(0.46)))
            
        case .mid:
            path.move(to: CGPoint(x: 0, y: y(0.55)))
            path.addCurve(to: CGPoint(x: x(0.3), y: y(0.35)),
                          control1: CGPoint(x: x(0.08), y: y(0.50)),
                          control2: CGPoint(x: x(0.18), y: y(0.32)))
            path.addCurve(to: CGPoint(x: x(0.65), y: y(0.5)),
                          control1: CGPoint(x: x(0.42), y: y(0.40)),
                          control2: CGPoint(x: x(0.55), y: y(0.56)))
            path.addCurve(to: CGPoint(x: w, y: y(0.42)),
                          control1: CGPoint(x: x(0.8), y: y(0.44)),
                          control2: CGPoint(x: x(0.92), y: y(0.38)))
            
        case .near:
            path.move(to: CGPoint(x: 0, y: y(0.5)))
            path.addCurve(to: CGPoint(x: x(0.25), y: y(0.38)),
                          control1: CGPoint(x: x(0.05), y: y(0.46)),
                          control2: CGPoint(x: x(0.14), y: y(0.34)))
            path.addCurve(to: CGPoint(x: x(0.55), y: y(0.52)),
                          control1: CGPoint(x: x(0.36), y: y(0.42)),
                          control2: CGPoint(x: x(0.48), y: y(0.60)))
            path.addCurve(to: CGPoint(x: w, y: y(0.40)),
                          control1: CGPoint(x: x(0.7), y: y(0.45)),
                          control2: CGPoint(x: x(0.88), y: y(0.36)))
        }
        
        // 闭合到底部，形成填充形状
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

/// 细粒度噪点覆盖，用于给深色背景增加一点质感
/// 注意：不要设为 private，其他页面（启动页、隐私页等）也会共用
struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / 8)
            let rows = Int(size.height / 8)
            for x in 0...cols {
                for y in 0...rows {
                    // 简单伪随机：不同位置透明度略有差异
                    let alpha = Double.random(in: 0.02...0.08)
                    let rect = CGRect(
                        x: CGFloat(x) * 8 + CGFloat.random(in: -2...2),
                        y: CGFloat(y) * 8 + CGFloat.random(in: -2...2),
                        width: 1.0,
                        height: 1.0
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(alpha))
                    )
                }
            }
        }
    }
}

// MARK: - 切换节点提示弹窗

private struct SwitchNodeAlertView: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                // 顶部图标
                ZStack {
                    Circle()
                        .fill(Color(red: 0/255, green: 180/255, blue: 120/255).opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 210/255, blue: 150/255))
                }
                
                // 标题 & 文案
                VStack(spacing: 8) {
                    Text(appLanguage.localized("gv_node_switch_title", comment: "Switch node alert title"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(appLanguage.localized("gv_node_switch_message", comment: "Switch node alert message"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
            
                // 按钮：上下排列
                VStack(spacing: 10) {
                    Button {
                        onConfirm()
                    } label: {
                        Text(appLanguage.localized("gv_common_ok", comment: "OK"))
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0/255, green: 210/255, blue: 150/255),
                                        Color(red: 0/255, green: 180/255, blue: 120/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 6/255, green: 40/255, blue: 45/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GVHomeSessionModel(agent: GVSessionAgent()))
        .environmentObject(GVRouteCoordinator())
        .environmentObject(GVAppLanguage.shared)
        .environmentObject(GVNodeManager.shared)
}

