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

// MARK: - 主页面

private struct HomeScreen: View {
    @EnvironmentObject private var homeSession: GVHomeSessionModel
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @EnvironmentObject private var nodeManager: GVNodeManager
    @EnvironmentObject private var routeCoordinator: GVRouteCoordinator
    
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
            
            VStack(spacing: 32) {
                // 自定义顶部栏：Logo + 标题 + 语言按钮
                HStack(spacing: 12) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 5)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appLanguage.localized("gv_home_title", comment: "Home title"))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(statusText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        // 节点选择按钮
                        Button {
                            routeCoordinator.showNodeList()
                        } label: {
                            HStack(spacing: 6) {
                                if let selected = nodeManager.selectedNode {
                                    if selected.id == -1 {
                                        // Auto 节点：显示地球图标 + "A"
                                        Image(systemName: "globe.asia.australia.fill")
                                            .font(.system(size: 13, weight: .medium))
                                        Text("A")
                                            .font(.system(size: 11, weight: .bold))
                                    } else {
                                        // 普通节点：显示国旗图标
                                        GVFlagIcon(countryCode: selected.countryCode, size: 16)
                                    }
                                } else {
                                    // 未选择：显示地球图标 + "A"
                                    Image(systemName: "globe.asia.australia.fill")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("A")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            )
                        }
                        
                        // 语言切换按钮
                        NavigationLink {
                            GVLanguageView()
                        } label: {
                            LanguageGlyphView()
                                .frame(width: 16, height: 16)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // 中央连接图标：立体能量圆，后续可由 UI 替换内部图标
                CoreOrbView(phase: homeSession.phase)
                    .frame(width: 210, height: 210)
                    .offset(y: -20)
                
                // 文案说明区
                VStack(spacing: 8) {
                    Text(detailText)
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.9))
                    
                    // 预留：可以后续放 fake 延迟/带宽的小 pill
                }
                .padding(.horizontal, 32)
                .multilineTextAlignment(.center)
                
                Spacer()
                
                // 底部主按钮
                Button {
                    homeSession.handlePrimaryAction()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: homeSession.phase == .online
                                    ? [Color.red, Color.orange]
                                    : [Color(red: 0/255, green: 180/255, blue: 120/255),
                                       Color(red: 0/255, green: 210/255, blue: 150/255)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
                        
                        HStack(spacing: 10) {
                            if homeSession.phase == .inProgress {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                KeyGlyphView(isOn: homeSession.phase == .online)
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                            }
                            
                            Text(buttonText)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                }
                .disabled(homeSession.phase == .inProgress)
                .padding(.horizontal, 32)
                .padding(.bottom, 26)
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

// MARK: - 自定义图形组件：钥匙徽章 & 语言图标


/// 简化版钥匙图形（头部圆 + 柄 + 齿）
private struct KeyGlyphView: View {
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


/// 中央连接图标：立体圆形能量核心（简洁版本，方便后续替换为 UI 图标）
private struct CoreOrbView: View {
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
                
                // 立体圆环（中空，为后续图标和文字预留空间）
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
                
                // 中心预留区：以后由 UI 放自定义图标 / 状态 / 时间
                Circle()
                    .fill(Color.white.opacity(0.08))
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
private struct NoiseOverlay: View {
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

#Preview {
    ContentView()
        .environmentObject(GVHomeSessionModel(agent: GVSessionAgent()))
        .environmentObject(GVRouteCoordinator())
        .environmentObject(GVAppLanguage.shared)
        .environmentObject(GVNodeManager.shared)
}

