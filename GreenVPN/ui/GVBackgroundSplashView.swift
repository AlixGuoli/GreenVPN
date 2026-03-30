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
            // 与冷启动启动页、各通用内页一致
            Image(.allbg)
                .resizable()
                .ignoresSafeArea()
            
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

