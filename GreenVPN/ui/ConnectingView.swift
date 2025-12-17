//
//  ConnectingView.swift
//  GreenVPN
//
//  简单连接中页面
//

import SwiftUI

struct ConnectingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            Text("正在连接 VPN ...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("连接中")
    }
}


