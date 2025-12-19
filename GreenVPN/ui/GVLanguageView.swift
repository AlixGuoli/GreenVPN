//
//  GVLanguageView.swift
//  GreenVPN
//
//  应用内语言切换页面
//

import SwiftUI

struct GVLanguageView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @State private var isSwitching: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 与主界面统一的深色渐变 + 噪点背景
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
            
            VStack(spacing: 0) {
                // 顶部标题栏（与设置 / 节点列表统一）
                HStack {
                    Text(appLanguage.localized("gv_lang_nav_title", comment: "Language settings title"))
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
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(appLanguage.localized("gv_lang_page_desc", comment: "Language page description"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                ScrollView {
                    VStack(spacing: 12) {
                        languageRow(option: .system,
                                    titleKey: "gv_lang_system",
                                    descriptionKey: "gv_lang_system_desc")
                        
                        languageRow(option: .zhHans,
                                    titleKey: "gv_lang_zh",
                                    descriptionKey: "gv_lang_zh_desc")
                        
                        languageRow(option: .en,
                                    titleKey: "gv_lang_en",
                                    descriptionKey: "gv_lang_en_desc")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                }
            }
            
            if isSwitching {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(appLanguage.localized("gv_lang_switching", comment: "Language switching hint"))
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.8))
                }
            }
        }
        // 使用自定义顶部栏，隐藏系统导航栏
        .navigationBarHidden(true)
    }
    
    private func languageRow(option: GVAppLanguage.Option, titleKey: String, descriptionKey: String) -> some View {
        Button {
            guard appLanguage.option != option else { return }
            isSwitching = true
            // 模拟一次轻量的“切换中”过程
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                appLanguage.option = option
                isSwitching = false
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appLanguage.localized(titleKey))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    Text(appLanguage.localized(descriptionKey))
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.70))
                }
                Spacer()
                if appLanguage.option == option {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct GVLanguageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GVLanguageView()
                .environmentObject(GVAppLanguage.shared)
        }
    }
}


