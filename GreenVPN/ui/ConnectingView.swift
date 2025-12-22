//
//  ConnectingView.swift
//  GreenVPN
//
//  连接中页面：统一深色渐变 + 中央圆环 + 过渡动画
//

import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    // 轻微呼吸
    @State private var orbScale: CGFloat = 1.0
    // 旋转高亮环
    @State private var ringRotation: Double = 0
    // 背景光晕闪动
    @State private var haloOpacity: Double = 0.35
    
    var body: some View {
        ZStack {
            // 背景：与首页统一的深色径向渐变 + 噪点
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
                
                // 细噪点
                ConnectingNoiseOverlay()
                    .ignoresSafeArea()
                    .blendMode(.overlay)
                    .opacity(0.10)
            }
            
            VStack(spacing: 28) {
                Spacer()
                
                ZStack {
                    // 柔和光晕：轻微闪动
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.25),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 180
                            )
                        )
                        .frame(width: 260, height: 260)
                        .opacity(haloOpacity)
                    
                    // 旋转高亮环
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.0)
                                ]),
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 240, height: 240)
                        .rotationEffect(.degrees(ringRotation))
                        .blur(radius: 0.5)
                        .opacity(0.9)
                    
                    // 中央 3D 圆：使用 inProgress 状态，整体略微呼吸
                    CoreOrbView(phase: .inProgress)
                        .frame(width: 220, height: 220)
                        .scaleEffect(orbScale)
                }
                
                // 提示文案
                Text(appLanguage.localized("gv_connecting_message", comment: "Connecting message"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // 小号进度指示（去掉多余的小点，只保留简洁的转圈）
            ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.0)
                
                Spacer()
            }
        }
        // 连接流程由状态驱动，页面不提供系统返回
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // 中央轻微呼吸（幅度小，不打扰主视觉）
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            orbScale = 1.04
        }
        // 旋转高亮环
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        // 光晕轻微闪烁
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            haloOpacity = 0.55
        }
    }
}

/// 连接页专用噪点覆盖（和首页风格一致）
private struct ConnectingNoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / 8)
            let rows = Int(size.height / 8)
            for x in 0...cols {
                for y in 0...rows {
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

