//
//  ResultView.swift
//  GreenVPN
//
//  连接结果页面：成功 / 失败 / 断开成功
//

import SwiftUI

struct ResultView: View {
    let result: SessionOutcome
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                onClose()
            }) {
                Text("关闭")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(primaryColor)
                    .cornerRadius(22)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .navigationTitle("连接结果")
    }
    
    private var title: String {
        switch result {
        case .connectSuccess: return "连接成功"
        case .connectFail: return "连接失败"
        case .disconnectSuccess: return "断开成功"
        }
    }
    
    private var message: String {
        switch result {
        case .connectSuccess: return "VPN 已成功连接，可以开始使用。"
        case .connectFail: return "连接失败，请检查网络或稍后再试。"
        case .disconnectSuccess: return "VPN 已断开连接。"
        }
    }
    
    private var primaryText: String {
        return "关闭"
    }
    
    private var primaryColor: Color {
        switch result {
        case .connectSuccess: return .green
        case .disconnectSuccess: return .blue
        case .connectFail: return .red
        }
    }
}


