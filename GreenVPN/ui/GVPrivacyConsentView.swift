//
//  GVPolicyGate.swift
//  GreenVPN
//
//  首次启动时展示的隐私协议页：使用完整页面覆盖主页
//

import SwiftUI

struct GVPolicyGate: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack {
            // 与主页统一的深色渐变 + 噪点，完全覆盖后台内容
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
            
            VStack(alignment: .leading, spacing: 18) {
                // 顶部标题区域
                Spacer().frame(height: 64)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(appLanguage.localized("gv_policy_title", comment: "Privacy title"))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(appLanguage.localized("gv_policy_preamble", comment: "Privacy preamble"))
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.80))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Group {
                            Text(appLanguage.localized("gv_policy_section_intro", comment: "Privacy section intro"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(appLanguage.localized("gv_policy_point_device", comment: "Device info point"))
                                Text(appLanguage.localized("gv_policy_point_records", comment: "Connection records point"))
                                Text(appLanguage.localized("gv_policy_point_duration", comment: "Duration & bandwidth point"))
                                Text(appLanguage.localized("gv_policy_point_ads", comment: "Ad service point"))
                            }
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Button {
                            // 跳转到在线隐私政策页面
                            if let url = URL(string: "https://greenshieldvpn7.xyz/p.html") {
                                openURL(url)
                            }
                        } label: {
                            Text(appLanguage.localized("gv_policy_more_link", comment: "Link to full policy"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.green.opacity(0.9))
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    // 同意在上，符合大多数 App 的按钮顺序
                    Button {
                        onAccept()
                    } label: {
                        Text(appLanguage.localized("gv_policy_accept", comment: "Accept and continue"))
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(14)
                    }
                    
                    Button(role: .destructive) {
                        onDecline()
                    } label: {
                        Text(appLanguage.localized("gv_policy_decline", comment: "Decline and exit"))
                            .font(.system(size: 17, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white.opacity(0.10))
                            .foregroundColor(Color.white.opacity(0.9))
                            .cornerRadius(12)
                    }
                }
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct GVPolicyGate_Previews: PreviewProvider {
    static var previews: some View {
        GVPolicyGate(
            onAccept: {},
            onDecline: {}
        )
        .preferredColorScheme(.dark)
        .environmentObject(GVAppLanguage.shared)
    }
}


