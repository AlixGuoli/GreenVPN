//
//  GVBackgroundSplashView.swift
//  GreenVPN
//
//  后台返回覆盖页（用于展示广告前的过渡页面）
//

import SwiftUI

struct GVBackgroundSplashView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // 与启动页一致的背景
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
            }
        }
    }
}

