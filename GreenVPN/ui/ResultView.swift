//
//  ResultView.swift
//  GreenVPN
//
//  连接结果页面：成功 / 失败 / 断开成功
//  布局：结果提示 + 两个功能卡片（分享 App / 加入我们）+ 底部关闭按钮
//

import SwiftUI

struct ResultView: View {
    let result: SessionOutcome
    let onClose: () -> Void
    
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @Environment(\.openURL) private var openURL
    
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            // 深色背景，与主页/连接页统一
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
            
            VStack(spacing: 24) {
                // 顶部结果图标 + 提示
                VStack(spacing: 12) {
                    ResultStatusIcon(result: result)
                    
            Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
            Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)
                
                // 功能卡片区域
                VStack(spacing: 16) {
                    // 分享 App 卡片
                    ResultActionCard(
                        title: appLanguage.localized("gv_result_share_title", comment: "Share app title"),
                        subtitle: appLanguage.localized("gv_result_share_subtitle", comment: "Share app subtitle"),
                        systemImage: "square.and.arrow.up",
                        accentColor: Color.green.opacity(0.9)
                    ) {
                        showShareSheet = true
                    }
                    
                    // 加入我们（跳转 TG）卡片
                    ResultActionCard(
                        title: appLanguage.localized("gv_result_join_title", comment: "Join us title"),
                        subtitle: appLanguage.localized("gv_result_join_subtitle", comment: "Join us subtitle"),
                        systemImage: "paperplane.fill",
                        accentColor: Color.blue.opacity(0.9)
                    ) {
                        if let url = URL(string: "https://t.me/+GHEEsuLHJ0I1YTU1") {
                            openURL(url)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 底部关闭按钮（自定义，而不是系统返回）
            Button(action: {
                onClose()
            }) {
                    Text(appLanguage.localized("gv_common_close", comment: "Close button"))
                        .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    .background(primaryColor)
                        .cornerRadius(24)
            }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareURL])
        }
        // 结果页不使用系统导航返回
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // MARK: - 文案 & 配色
    
    private var title: String {
        switch result {
        case .connectSuccess:
            return appLanguage.localized("gv_result_title_connect_success", comment: "Connect success title")
        case .connectFail:
            return appLanguage.localized("gv_result_title_connect_fail", comment: "Connect fail title")
        case .disconnectSuccess:
            return appLanguage.localized("gv_result_title_disconnect_success", comment: "Disconnect success title")
        }
    }
    
    private var message: String {
        switch result {
        case .connectSuccess:
            return appLanguage.localized("gv_result_body_connect_success", comment: "Connect success body")
        case .connectFail:
            return appLanguage.localized("gv_result_body_connect_fail", comment: "Connect fail body")
        case .disconnectSuccess:
            return appLanguage.localized("gv_result_body_disconnect_success", comment: "Disconnect success body")
        }
    }
    
    private var primaryColor: Color {
        switch result {
        case .connectSuccess: return Color.green
        case .disconnectSuccess: return Color.blue
        case .connectFail: return Color.red
        }
    }
    
    private var shareURL: URL {
        // 直接分享 App Store 应用链接
        return URL(string: "https://apps.apple.com/app/id6755873784")!
    }
}

// MARK: - 顶部结果图标

private struct ResultStatusIcon: View {
    let result: SessionOutcome
    
    var body: some View {
        ZStack {
            Circle()
                .fill(outerColor.opacity(0.18))
                .frame(width: 74, height: 74)
                .blur(radius: 1.0)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [outerColor.opacity(0.85), outerColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .shadow(color: outerColor.opacity(0.6), radius: 14, x: 0, y: 10)
            
            Image(systemName: iconName)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var outerColor: Color {
        switch result {
        case .connectSuccess: return .green
        case .disconnectSuccess: return .blue
        case .connectFail: return .red
        }
    }
    
    private var iconName: String {
        switch result {
        case .connectSuccess: return "checkmark"
        case .disconnectSuccess: return "power"
        case .connectFail: return "xmark"
        }
    }
}

// MARK: - 结果页操作卡片

private struct ResultActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - UIKit 分享封装

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


