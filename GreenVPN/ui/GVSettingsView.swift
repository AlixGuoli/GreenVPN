//
//  GVSettingsView.swift
//  GreenVPN
//
//  设置页面
//

import SwiftUI

struct GVSettingsView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @EnvironmentObject private var routeCoordinator: GVRouteCoordinator
    @EnvironmentObject private var statsManager: GVConnectionStatsManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var showShareSheet: Bool = false
    
    var body: some View {
        ZStack {
            // 背景：与主页一致的深色渐变
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
            
            VStack(spacing: 0) {
                // 顶部标题栏
                HStack {
                    Text(appLanguage.localized("gv_settings_title", comment: "Settings title"))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // 设置内容
                ScrollView {
                    VStack(spacing: 20) {
                        // 顶部 App 信息卡片
                        SettingsAppCard()
                        
                        // 设置项列表（语言入口放在最上方）
                        VStack(spacing: 12) {
                            // 语言设置入口（导航到语言页）
                            NavigationLink {
                                GVLanguageView()
                            } label: {
                                SettingsNavRow(
                                    icon: "globe",
                                    title: appLanguage.localized("gv_lang_nav_title", comment: "Language settings title"),
                                    subtitle: appLanguage.localized("gv_settings_language_subtitle", comment: "Language settings subtitle")
                                )
                            }
                            
                            // 分享 App
                            SettingsSimpleRow(
                                icon: "square.and.arrow.up",
                                title: appLanguage.localized("gv_result_share_title", comment: "Share app"),
                                subtitle: appLanguage.localized("gv_result_share_subtitle", comment: "Share app subtitle")
                            ) {
                                showShareSheet = true
                            }
                            
                            // 加入 TG
                            SettingsSimpleRow(
                                icon: "paperplane.fill",
                                title: appLanguage.localized("gv_result_join_title", comment: "Join us"),
                                subtitle: appLanguage.localized("gv_result_join_subtitle", comment: "Join us subtitle")
                            ) {
                                if let url = URL(string: "https://t.me/+GHEEsuLHJ0I1YTU1") {
                                    openURL(url)
                                }
                            }
                            
                            SettingsSimpleRow(
                                icon: "lock.shield.fill",
                                title: appLanguage.localized("gv_settings_privacy", comment: "Privacy policy"),
                                subtitle: appLanguage.localized("gv_settings_privacy_subtitle", comment: "Privacy policy subtitle")
                            ) {
                                if let url = URL(string: "https://greenshieldvpn7.xyz/p.html") {
                                    openURL(url)
                                }
                            }
                            
                            SettingsSimpleRow(
                                icon: "doc.text.fill",
                                title: appLanguage.localized("gv_settings_terms", comment: "Terms of Service"),
                                subtitle: appLanguage.localized("gv_settings_terms_subtitle", comment: "Terms of Service subtitle")
                            ) {
                                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                    openURL(url)
                                }
                            }
                            
                            SettingsSimpleRow(
                                icon: "info.circle.fill",
                                title: appLanguage.localized("gv_settings_about", comment: "About us"),
                                subtitle: appLanguage.localized("gv_settings_about_subtitle", comment: "About us subtitle")
                            ) {
                                if let url = URL(string: "https://greenshieldvpn7.xyz/") {
                                    openURL(url)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareURL])
        }
    }
    
    private func formatTotalDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d h %d m", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d m", minutes)
        } else {
            return appLanguage.localized("gv_stats_less_than_minute", comment: "Less than a minute")
        }
    }
    
    private var shareURL: URL {
        URL(string: "https://apps.apple.com/app/id6755873784")!
    }
}

// MARK: - 顶部 App 信息卡片

private struct SettingsAppCard: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    var body: some View {
        VStack(spacing: 10) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 8)
            
            Text(GVAppInfo.displayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(appLanguage.localized("gv_intro_subtitle", comment: "App subtitle"))
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
                )
        )
    }
}

// MARK: - 简单设置行

private struct SettingsSimpleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.72))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
}

// 专供 NavigationLink 使用的样式（不自带 Button）
private struct SettingsNavRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.72))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
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

#Preview {
    GVSettingsView()
        .environmentObject(GVAppLanguage.shared)
        .environmentObject(GVRouteCoordinator())
        .environmentObject(GVConnectionStatsManager.shared)
}

