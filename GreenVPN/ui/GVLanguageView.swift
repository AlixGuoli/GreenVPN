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
            List {
                Section {
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
            }
            .listStyle(.insetGrouped)
            .disabled(isSwitching)
            
            if isSwitching {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text(appLanguage.localized("gv_lang_switching", comment: "Language switching hint"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(appLanguage.localized("gv_lang_nav_title", comment: "Language settings title"))
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appLanguage.localized(titleKey))
                        .foregroundColor(.primary)
                    Text(appLanguage.localized(descriptionKey))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if appLanguage.option == option {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)
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


