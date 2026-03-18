//
//  GVIntroCurtain.swift
//  GreenVPN
//
//  启动引导页：带进度条，从 0% 递增到 100% 后进入主界面
//

import SwiftUI
import Network
import Alamofire

struct GVIntroCurtain: View {
    let onFinish: () -> Void
    let onFinishWithAd: (() -> Void)?
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var progress: Int = 0           // 0 ~ 100
    @State private var isDone = false              // 启动流程是否完成（接口成功或超时）
    @State private var mediaReady = false          // 媒体资源是否加载成功
    @State private var progressTimer: Timer?
    @State private var networkMonitor: NWPathMonitor?
    @State private var networkQueue: DispatchQueue?
    
    private let maxWaitTime: TimeInterval = 20.0
    
    init(onFinish: @escaping () -> Void, onFinishWithAd: (() -> Void)? = nil) {
        self.onFinish = onFinish
        self.onFinishWithAd = onFinishWithAd
    }
    
    var body: some View {
        ZStack {
            // 与主页统一的深色径向渐变 + 噪点
            ZStack {
                RadialGradient(
                    colors: [
                        Color(red: 6/255, green: 40/255, blue: 45/255),
                        Color(red: 2/255, green: 10/255, blue: 16/255)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.height * 0.9
                )
                .ignoresSafeArea()
                
                NoiseOverlay()
                    .ignoresSafeArea()
                    .blendMode(.overlay)
                    .opacity(0.10)
            }
            
            VStack(spacing: 16) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Color.green.opacity(0.6), radius: 18, x: 0, y: 10)
                
                Text(GVAppInfo.displayName)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(appLanguage.localized("gv_intro_subtitle", comment: "Intro subtitle"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.top, 4)
                
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0/255, green: 210/255, blue: 150/255),
                                            Color(red: 0/255, green: 180/255, blue: 120/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(progress) / 100.0, height: 6)
                        }
                    }
                    .frame(height: 6)
                    .frame(width: 180)
                    
                    // 百分比文案：直接使用 0~100 的整数
                    Text(
                        String(
                            format: appLanguage.localized("gv_intro_progress", comment: "Intro loading progress"),
                            progress
                        )
                    )
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(.top, 18)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0.5)) {
                scale = 1.0
                opacity = 1.0
            }
            
            beginSetup()
        }
        .onChange(of: isDone) { done in
            // 只有在标记完成时，才统一处理进度和跳转
            if done {
                completeSplash()
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
            networkMonitor?.cancel()
            networkMonitor = nil
            networkQueue = nil
        }
    }
    
    // MARK: - 初始化流程
    
    private func beginSetup() {
        // 重置进度
        progress = 0
        
        // 启动 20 秒进度条：每 0.2 秒 +1，一共 100 步
        progressTimer?.invalidate()
        let stepInterval = maxWaitTime / 100.0
        progressTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { timer in
            if progress >= 100 {
                timer.invalidate()
                progressTimer = nil
            } else {
                progress += 1
            }
        }
        if let timer = progressTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        // 检查网络并初始化
        checkNetwork()
        
        // 20秒超时
        DispatchQueue.main.asyncAfter(deadline: .now() + maxWaitTime) {
            if !isDone {
                GVLogger.log("SplashView", "⏱️ 20秒超时，进入主页")
                isDone = true
            }
        }
    }
    
    private func checkNetwork() {
        let netMgr = NetworkReachabilityManager()
        netMgr?.startListening(onUpdatePerforming: { status in
            switch status {
            case .reachable(.ethernetOrWiFi), .reachable(.cellular):
                GVLogger.log("SplashView", "🌐 网络可用，开始初始化")
                Task {
                    await setupConfig()
                    DispatchQueue.main.async {
                        // 接口完成：标记完成，剩下交给 completeSplash 处理
                        if !isDone {
                            isDone = true
                        }
                    }
                }
                netMgr?.stopListening()
            case .notReachable:
                break
            case .unknown:
                break
            }
        })
    }
    
    private func setupConfig() async {
        // 1. 先获取基础配置（必须等待完成）
        GVLogger.log("SplashView", "开始请求基础配置")
        await GVAPIManager.syncBasic()
        GVLogger.log("SplashView", "基础配置请求完成")
        
        // 2. 同步广告配置（不等待完成，后台进行）
        Task {
            await GVAPIManager.syncAds()
        }
        
        // 3. 加载媒体资源（仅加载 Interstitial：Yandex/EM）
        let resourceReady = await loadMediaResources()
        DispatchQueue.main.async {
            if !isDone {
                mediaReady = resourceReady
                isDone = true
            }
        }
    }
    
    private func loadMediaResources() async -> Bool {
        // 只加载插屏（Yandex legacy 或 EM，取决于 adsType）
        return await loadInterstitialResource()
    }
    
    private func loadInterstitialResource() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var resumed = false
                
                GVAdCoordinator.shared.prepareYa(onAdReady: {
                    if !resumed {
                        resumed = true
                        GVLogger.log("[Ad]", "✅ Int/EM 执行完成")
                        continuation.resume(returning: true)
                    }
                }, onAdFailed: {
                    if !resumed {
                        resumed = true
                        GVLogger.log("[Ad]", "❌ Int/EM 加载失败")
                        continuation.resume(returning: false)
                    }
                })
            }
        }
    }
    
    // MARK: - 完成启动页
    
    /// 接口完成或超时之后统一调用：先把进度条补到 100%，再进入主页
    private func completeSplash() {
        // 如果提前完成，进度条跳到100%
        if progress < 100 {
            withAnimation(.easeOut(duration: 0.3)) {
                progress = 100
            }
        }
        
        // 延迟一点再进入主页，确保进度条动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if mediaReady {
                onFinishWithAd?()
            } else {
                onFinish()
            }
        }
    }
    
}

struct GVIntroCurtain_Previews: PreviewProvider {
    static var previews: some View {
        GVIntroCurtain(onFinish: {})
            .environmentObject(GVAppLanguage.shared)
    }
}


