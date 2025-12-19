//
//  GVToolboxView.swift
//  GreenVPN
//
//  工具箱页面：包含 Ping 测试、端口检测、Base64 文本工具
//

import SwiftUI
import Network

struct GVToolboxView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 背景与主页一致
            RadialGradient(
                colors: [
                    Color(red: 6/255, green: 40/255, blue: 45/255),
                    Color(red: 2/255, green: 10/255, blue: 16/255)
                ],
                center: .center,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.8
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Text(appLanguage.localized("gv_toolbox_title", comment: "Toolbox title"))
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
                
                ScrollView {
                    VStack(spacing: 16) {
                        Text(appLanguage.localized("gv_toolbox_desc", comment: "Toolbox description"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 4)
                        
                        NavigationLink {
                            PingToolView()
                        } label: {
                            ToolboxRow(
                                icon: "waveform.path.ecg",
                                title: appLanguage.localized("gv_toolbox_ping_title", comment: "Ping tool title"),
                                subtitle: appLanguage.localized("gv_toolbox_ping_subtitle", comment: "Ping tool subtitle")
                            )
                        }
                        
                        NavigationLink {
                            PortCheckToolView()
                        } label: {
                            ToolboxRow(
                                icon: "terminal.fill",
                                title: appLanguage.localized("gv_toolbox_port_title", comment: "Port tool title"),
                                subtitle: appLanguage.localized("gv_toolbox_port_subtitle", comment: "Port tool subtitle")
                            )
                        }
                        
                        NavigationLink {
                            Base64ToolView()
                        } label: {
                            ToolboxRow(
                                icon: "textformat.abc",
                                title: appLanguage.localized("gv_toolbox_base64_title", comment: "Base64 tool title"),
                                subtitle: appLanguage.localized("gv_toolbox_base64_subtitle", comment: "Base64 tool subtitle")
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - 工具箱行

private struct ToolboxRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0/255, green: 210/255, blue: 150/255),
                                Color(red: 0/255, green: 160/255, blue: 120/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Ping 工具

private struct PingResult {
    var samples: [Double] = []
    
    var latest: Double? { samples.last }
    var min: Double? { samples.min() }
    var max: Double? { samples.max() }
    var avg: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }
}

struct PingToolView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @Environment(\.dismiss) private var dismiss
    
    @State private var host: String = "example.com"
    @State private var isTesting: Bool = false
    @State private var result = PingResult()
    @State private var statusText: String = ""
    
    var body: some View {
        FormLikeBackground {
            VStack(alignment: .leading, spacing: 16) {
                // 自定义顶部返回 + 标题，避免系统返回样式
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    
                    Text(appLanguage.localized("gv_toolbox_ping_title", comment: "Ping tool title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text(appLanguage.localized("gv_toolbox_ping_hint", comment: "Ping hint"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                TextField("example.com", text: $host)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                
                Button {
                    startPing()
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isTesting
                             ? appLanguage.localized("gv_toolbox_ping_running", comment: "Ping running")
                             : appLanguage.localized("gv_toolbox_ping_start", comment: "Ping start"))
                        .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0/255, green: 210/255, blue: 150/255),
                                        Color(red: 0/255, green: 160/255, blue: 120/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .disabled(isTesting || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let latest = result.latest {
                    VStack(alignment: .leading, spacing: 8) {
                        StatLine(label: appLanguage.localized("gv_toolbox_ping_latest", comment: "Ping latest"),
                                 value: "\(Int(latest)) ms")
                        if let min = result.min {
                            StatLine(label: appLanguage.localized("gv_toolbox_ping_min", comment: "Ping min"),
                                     value: "\(Int(min)) ms")
                        }
                        if let max = result.max {
                            StatLine(label: appLanguage.localized("gv_toolbox_ping_max", comment: "Ping max"),
                                     value: "\(Int(max)) ms")
                        }
                        if let avg = result.avg {
                            StatLine(label: appLanguage.localized("gv_toolbox_ping_avg", comment: "Ping avg"),
                                     value: "\(Int(avg)) ms")
                        }
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func startPing() {
        let target = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        
        isTesting = true
        statusText = appLanguage.localized("gv_toolbox_ping_running", comment: "Ping running")
        result = PingResult()
        
        // 简单实现：连续发起数次 TCP 连接来估算延迟
        let attempts = 5
        let port: NWEndpoint.Port = 80
        var completed = 0
        
        for _ in 0..<attempts {
            let start = Date()
            let connection = NWConnection(host: NWEndpoint.Host(target), port: port, using: .tcp)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let rtt = Date().timeIntervalSince(start) * 1000
                    DispatchQueue.main.async {
                        result.samples.append(rtt)
                        completed += 1
                        if completed == attempts {
                            isTesting = false
                            statusText = appLanguage.localized("gv_toolbox_ping_done", comment: "Ping done")
                        }
                    }
                    connection.cancel()
                case .failed, .cancelled:
                    DispatchQueue.main.async {
                        completed += 1
                        if completed == attempts {
                            isTesting = false
                            if result.samples.isEmpty {
                                statusText = appLanguage.localized("gv_toolbox_ping_error", comment: "Ping error")
                            } else {
                                statusText = appLanguage.localized("gv_toolbox_ping_done", comment: "Ping done")
                            }
                        }
                    }
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
}

// MARK: - 端口检测工具

struct PortCheckToolView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @Environment(\.dismiss) private var dismiss
    
    @State private var host: String = "example.com"
    @State private var portText: String = "443"
    @State private var isChecking: Bool = false
    @State private var resultText: String = ""
    
    var body: some View {
        FormLikeBackground {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    
                    Text(appLanguage.localized("gv_toolbox_port_title", comment: "Port tool title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text(appLanguage.localized("gv_toolbox_port_hint", comment: "Port hint"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                TextField("example.com", text: $host)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                
                TextField("443", text: $portText)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                
                Button {
                    checkPort()
                } label: {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isChecking
                             ? appLanguage.localized("gv_toolbox_port_running", comment: "Port running")
                             : appLanguage.localized("gv_toolbox_port_start", comment: "Port start"))
                        .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0/255, green: 210/255, blue: 150/255),
                                        Color(red: 0/255, green: 160/255, blue: 120/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .disabled(isChecking || !canStart)
                
                if !resultText.isEmpty {
                    Text(resultText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private var canStart: Bool {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let port = UInt16(portText), port > 0 else {
            return false
        }
        return true
    }
    
    private func checkPort() {
        let target = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let portValue = UInt16(portText),
              let port = NWEndpoint.Port(rawValue: portValue) else { return }
        
        isChecking = true
        resultText = ""
        
        let connection = NWConnection(host: NWEndpoint.Host(target), port: port, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    isChecking = false
                    resultText = appLanguage.localized("gv_toolbox_port_open", comment: "Port open")
                }
                connection.cancel()
            case .failed:
                DispatchQueue.main.async {
                    isChecking = false
                    resultText = appLanguage.localized("gv_toolbox_port_closed", comment: "Port closed")
                }
                connection.cancel()
            case .cancelled:
                DispatchQueue.main.async {
                    if isChecking {
                        isChecking = false
                        resultText = appLanguage.localized("gv_toolbox_port_closed", comment: "Port closed")
                    }
                }
            default:
                break
            }
        }
        connection.start(queue: .global())
    }
}

// MARK: - Base64 工具

struct Base64ToolView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorText: String = ""
    
    var body: some View {
        FormLikeBackground {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    
                    Text(appLanguage.localized("gv_toolbox_base64_title", comment: "Base64 tool title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text(appLanguage.localized("gv_toolbox_base64_hint", comment: "Base64 hint"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                TextEditor(text: $inputText)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    Button {
                        encode()
                    } label: {
                        Text(appLanguage.localized("gv_toolbox_base64_encode", comment: "Base64 encode"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.16))
                            )
                    }
                    
                    Button {
                        decode()
                    } label: {
                        Text(appLanguage.localized("gv_toolbox_base64_decode", comment: "Base64 decode"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                }
                
                TextEditor(text: $outputText)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .foregroundColor(.white.opacity(0.95))
                    .disabled(true)
                
                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundColor(Color.red.opacity(0.9))
                }
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func encode() {
        errorText = ""
        let data = inputText.data(using: .utf8) ?? Data()
        outputText = data.base64EncodedString()
    }
    
    private func decode() {
        errorText = ""
        guard let data = Data(base64Encoded: inputText) else {
            errorText = appLanguage.localized("gv_toolbox_base64_error", comment: "Base64 error")
            outputText = ""
            return
        }
        outputText = String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - 通用背景包装

private struct FormLikeBackground<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 6/255, green: 40/255, blue: 45/255),
                    Color(red: 2/255, green: 10/255, blue: 16/255)
                ],
                center: .center,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.8
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 统计行组件

private struct StatLine: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}


