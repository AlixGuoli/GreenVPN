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
    
    var body: some View {
        ZStack {
            // 完整不透明背景，彻底遮住主页内容
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                // 顶部留出明显空白，避免文案贴近状态栏 / 刘海
                Spacer().frame(height: 64)
                
                Text(appLanguage.localized("gv_policy_title", comment: "Privacy title"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(appLanguage.localized("gv_policy_preamble", comment: "Privacy preamble"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Group {
                    Text(appLanguage.localized("gv_policy_section_intro", comment: "Privacy section intro"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appLanguage.localized("gv_policy_point_device", comment: "Device info point"))
                        Text(appLanguage.localized("gv_policy_point_records", comment: "Connection records point"))
                        Text(appLanguage.localized("gv_policy_point_duration", comment: "Duration & bandwidth point"))
                        Text(appLanguage.localized("gv_policy_point_ads", comment: "Ad service point"))
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                Button {
                    // 这里可以后续跳转到 WebView 详细条款
                } label: {
                    Text(appLanguage.localized("gv_policy_more_link", comment: "Link to full policy"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.green)
                }
                .padding(.top, 4)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        onDecline()
                    } label: {
                        Text(appLanguage.localized("gv_policy_decline", comment: "Decline and exit"))
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    
                    Button {
                        onAccept()
                    } label: {
                        Text(appLanguage.localized("gv_policy_accept", comment: "Accept and continue"))
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 24)
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


