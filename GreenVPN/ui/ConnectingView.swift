//
//  ConnectingView.swift
//  GreenVPN
//
//  简单连接中页面
//

import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            Text(appLanguage.localized("gv_connecting_message", comment: "Connecting message"))
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle(appLanguage.localized("gv_connecting_nav_title", comment: "Connecting nav title"))
    }
}


