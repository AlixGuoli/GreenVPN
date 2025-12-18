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
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
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
                Text(appLanguage.localized("gv_common_close", comment: "Close button"))
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
        .navigationTitle(appLanguage.localized("gv_result_nav_title", comment: "Result nav title"))
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
    
    private var primaryText: String {
        return appLanguage.localized("gv_common_close", comment: "Close button")
    }
    
    private var primaryColor: Color {
        switch result {
        case .connectSuccess: return .green
        case .disconnectSuccess: return .blue
        case .connectFail: return .red
        }
    }
}


