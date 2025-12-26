//
//  GVIntroCurtain.swift
//  GreenVPN
//
//  启动引导页：带进度条，从 0% 递增到 100% 后进入主界面
//

import SwiftUI
import Network

struct GVIntroCurtain: View {
    let onFinish: () -> Void
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var progress: Int = 0
    @State private var timer: Timer?
    @State private var networkMonitor: NWPathMonitor?
    @State private var networkQueue: DispatchQueue?
    
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
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.green)
                            .frame(width: CGFloat(progress) / 100.0 * 180.0,
                                   height: 4)
                    }
                    .frame(width: 180, alignment: .leading)
                    
                    Text(String(format: appLanguage.localized("gv_intro_progress", comment: "Intro loading progress"),
                                progress))
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
            
            // 检测网络类型，触发网络授权
            checkNetworkType()
            
            // 测试接口调用
            testAPICall()
            
            // 进度从 0 递增到 100
            timer = Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { t in
                if progress >= 100 {
                    t.invalidate()
                    timer = nil
                    return
                }
                progress += 1
            }
            
            // 启动页停留时间，可按需要微调（与进度条时长保持大致一致）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.25)) {
                    opacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onFinish()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            networkMonitor?.cancel()
            networkMonitor = nil
            networkQueue = nil
        }
    }
    
    /// 检测当前网络类型（WiFi、蜂窝、无网络），用于触发网络授权
    private func checkNetworkType() {
        // 如果已经有监控器在运行，先取消
        if let existingMonitor = networkMonitor {
            existingMonitor.cancel()
        }
        
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.greenvpn.network.monitor")
        
        monitor.pathUpdateHandler = { [weak monitor] path in
            // 检测网络类型
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    print("[GVIntroCurtain] 网络类型: WiFi")
                } else if path.usesInterfaceType(.cellular) {
                    print("[GVIntroCurtain] 网络类型: 蜂窝网络")
                } else if path.usesInterfaceType(.wiredEthernet) {
                    print("[GVIntroCurtain] 网络类型: 有线网络")
                } else {
                    print("[GVIntroCurtain] 网络类型: 其他")
                }
            } else {
                print("[GVIntroCurtain] 网络类型: 无网络连接")
            }
            
            // 检测一次后取消监控（避免持续占用资源）
            monitor?.cancel()
        }
        
        monitor.start(queue: queue)
        
        // 保存引用以便后续清理
        networkMonitor = monitor
        networkQueue = queue
    }
    
    /// 测试 API 接口调用（通过 APIManager 统一入口）
    private func testAPICall() {
        Task {
            GVLogger.log("SplashView", "开始测试同步基本配置接口...")
            await GVAPIManager.syncBasic()
            
            // 基本配置成功后，调用广告配置接口
            GVLogger.log("SplashView", "基本配置完成，开始同步广告配置接口...")
            await GVAPIManager.syncAds()
            
            // 所有接口完成后，最后调用服务配置接口
            GVLogger.log("SplashView", "所有配置完成，开始同步服务配置接口...")
            await GVAPIManager.syncServiceConfig()
        }
    }
}

struct GVIntroCurtain_Previews: PreviewProvider {
    static var previews: some View {
        GVIntroCurtain(onFinish: {})
            .environmentObject(GVAppLanguage.shared)
    }
}


