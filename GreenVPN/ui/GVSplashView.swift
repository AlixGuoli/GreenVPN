//
//  GVIntroCurtain.swift
//  GreenVPN
//
//  启动引导页：带进度条，从 0% 递增到 100% 后进入主界面
//

import SwiftUI

struct GVIntroCurtain: View {
    let onFinish: () -> Void
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var progress: Int = 0
    @State private var timer: Timer?
    
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
                
                Text(appLanguage.localized("gv_intro_title", comment: "App name on intro screen"))
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
        }
    }
}

struct GVIntroCurtain_Previews: PreviewProvider {
    static var previews: some View {
        GVIntroCurtain(onFinish: {})
            .environmentObject(GVAppLanguage.shared)
    }
}


