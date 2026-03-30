//
//  ResultView.swift
//  GreenVPN
//
//  连接结果页面：成功 / 失败 / 断开成功
//  全屏背景图自带顶部状态图案；分享/加入卡片用 bgResultCard + 资源图标
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
            Image(resultBackgroundAsset)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(title.uppercased())
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                    
//                    Text(message)
//                        .font(.system(size: 14))
//                        .foregroundColor(Color.white.opacity(0.7))
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal, 32)
                }
                .padding(.top, 150)
                
                VStack(spacing: 20) {
                    ResultActionCard(
                        title: appLanguage.localized("gv_result_share_title", comment: "Share app title"),
                        subtitle: appLanguage.localized("gv_result_share_subtitle", comment: "Share app subtitle"),
                        leadingAsset: "resultShare"
                    ) {
                        showShareSheet = true
                    }
                    
                    ResultActionCard(
                        title: appLanguage.localized("gv_result_join_title", comment: "Join us title"),
                        subtitle: appLanguage.localized("gv_result_join_subtitle", comment: "Join us subtitle"),
                        leadingAsset: "resultTg"
                    ) {
                        if let url = URL(string: "https://t.me/+GHEEsuLHJ0I1YTU1") {
                            openURL(url)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                if result != .connectFail {
                    ReviewPromptCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { onClose() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18)
            .padding(.top, 12)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareURL])
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private var resultBackgroundAsset: String {
        switch result {
        case .connectSuccess:
            return "bgResultSuccess"
        case .disconnectSuccess:
            return "bgResultDisconnect"
        case .connectFail:
            return "bgResultFail"
        }
    }
    
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
    
    private var shareURL: URL {
        URL(string: "https://apps.apple.com/app/id6756861853")!
    }
}

// MARK: - 结果页操作卡片

private struct ResultActionCard: View {
    let title: String
    let subtitle: String
    let leadingAsset: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(leadingAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(height: 120)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Image("bgResultCard")
                    .resizable()
                    .scaledToFill()
            }
        }
        .buttonStyle(.plain)
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
