//
//  ContentView.swift
//  GreenVPN
//
//  Created by sister on 2025/12/15.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var connectTools = ConnectTools()
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 状态显示
            VStack(spacing: 15) {
                // 状态图标
                Circle()
                    .fill(statusColor)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: statusIcon)
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    )
                    .shadow(color: statusColor.opacity(0.3), radius: 20)
                
                // 状态文字
                Text(statusText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // 详细状态
                Text(detailText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 连接/断开按钮
            Button(action: {
                connectTools.handleButtonAction()
            }) {
                HStack {
                    if connectTools.connectionStatus == .connecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(buttonText)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(buttonColor)
                .cornerRadius(28)
                .shadow(color: buttonColor.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(connectTools.connectionStatus == .connecting)
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .onAppear {
            connectTools.resetVPN()
        }
    }
    
    // 状态颜色
    private var statusColor: Color {
        switch connectTools.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }
    
    // 状态图标
    private var statusIcon: String {
        switch connectTools.connectionStatus {
        case .connected:
            return "checkmark.shield.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .disconnected:
            return "shield.slash.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    // 状态文字
    private var statusText: String {
        switch connectTools.connectionStatus {
        case .connected:
            return "已连接"
        case .connecting:
            return "连接中..."
        case .disconnected:
            return "未连接"
        case .failed:
            return "连接失败"
        }
    }
    
    // 详细状态
    private var detailText: String {
        switch connectTools.connectionStatus {
        case .connected:
            return "VPN 已成功连接"
        case .connecting:
            return "正在建立连接..."
        case .disconnected:
            return "点击下方按钮开始连接"
        case .failed:
            return "连接失败，请重试"
        }
    }
    
    // 按钮文字
    private var buttonText: String {
        switch connectTools.connectionStatus {
        case .connected:
            return "断开连接"
        case .connecting:
            return "连接中..."
        case .disconnected, .failed:
            return "连接 VPN"
        }
    }
    
    // 按钮颜色
    private var buttonColor: Color {
        switch connectTools.connectionStatus {
        case .connected:
            return .red
        case .connecting:
            return .orange
        case .disconnected, .failed:
            return .blue
        }
    }
}

#Preview {
    ContentView()
}
