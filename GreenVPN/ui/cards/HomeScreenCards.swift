//
//  HomeScreenCards.swift
//  GreenVPN
//
//  主页卡片组件
//

import SwiftUI

/// 连接状态卡片（第一个大卡片，包含圆环和按钮）
struct ConnectionStatusCard: View {
    let phase: SessionPhase
    let connectionDuration: TimeInterval
    let detailText: String
    let buttonText: String
    let onButtonTap: () -> Void
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    var body: some View {
        // 上半段（可点击）
        Button(action: onButtonTap) {
            ZStack {
                Image(upperImageName)
                    .resizable()
                    .scaledToFit()
                
                VStack {
                    Spacer()
                    
                    Text(centerDisplayText)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(phase == .inProgress)
    }

    private var upperImageName: String {
        isConnectedStyle ? "connected_up" : "connect_up"
    }

    private var isConnectedStyle: Bool {
        phase == .inProgress || phase == .online
    }

    private var centerDisplayText: String {
        switch phase {
        case .online:
            return formatDuration(connectionDuration)
        case .inProgress:
            return appLanguage.localized("gv_home_button_connecting", comment: "Connect button center connecting")
        case .idle, .failed:
            return appLanguage.localized("gv_home_button_connect", comment: "Connect button center idle")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

/// 当前节点卡片
struct CurrentNodeCard: View {
    let node: GVNode
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @EnvironmentObject private var routeCoordinator: GVRouteCoordinator
    @EnvironmentObject private var homeSession: GVHomeSessionModel
    let onSwitchNodeAlert: () -> Void
    
    var body: some View {
        Button {
            // 如果已连接，显示提示
            if homeSession.phase == .online {
                onSwitchNodeAlert()
            } else {
                routeCoordinator.showNodeList()
            }
        } label: {
            HStack(spacing: 16) {
                // 国旗图标
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 60, height: 60)
                    
                    if node.id == -1 {
                        Image("world")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    } else {
                        GVFlagIcon(countryCode: node.countryCode, size: 32)
                    }
                }
                
                // 节点信息
                VStack(alignment: .leading, spacing: 6) {
                    Text({
                        if node.id == -1 {
                            return appLanguage.localized("gv_node_auto", comment: "Auto node")
                        }
                        let key = "gv_node_\(node.countryCode.lowercased())"
                        let localized = appLanguage.localized(key, comment: "Node name")
                        // 如果本地化字符串不存在（返回的是 key），则使用接口返回的 name
                        return localized == key ? node.name : localized
                    }())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if node.id != -1 {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 12))
                                Text("\(node.latency) ms")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 12))
                                Text(loadText)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(loadColor)
                        }
                    } else {
                        Text(appLanguage.localized("gv_node_auto_desc", comment: "Auto node description"))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .background(cardBackground)
        }
        
    }
    
    private var loadText: String {
        if node.load < 0.3 {
            return appLanguage.localized("gv_node_load_low", comment: "Low load")
        } else if node.load < 0.7 {
            return appLanguage.localized("gv_node_load_medium", comment: "Medium load")
        } else {
            return appLanguage.localized("gv_node_load_high", comment: "High load")
        }
    }
    
    private var loadColor: Color {
        if node.load < 0.3 {
            return .green.opacity(0.8)
        } else if node.load < 0.7 {
            return .orange.opacity(0.8)
        } else {
            return .red.opacity(0.8)
        }
    }
    
    private var cardBackground: some View {
        let image: ImageResource = (homeSession.phase == .inProgress || homeSession.phase == .online)
            ? .bgnodeCon
            : .bgnodeDis
        
        return Image(image)
            .resizable()
    }
}

// MARK: - 切换节点提示弹窗

private struct SwitchNodeAlertView: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                // 顶部图标
                ZStack {
                    Circle()
                        .fill(Color(red: 0/255, green: 180/255, blue: 120/255).opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 210/255, blue: 150/255))
                }
                
                // 标题 & 文案
                VStack(spacing: 8) {
                    Text(appLanguage.localized("gv_node_switch_title", comment: "Switch node alert title"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(appLanguage.localized("gv_node_switch_message", comment: "Switch node alert message"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
            
                // 按钮：上下排列
                VStack(spacing: 10) {
                    Button {
                        onConfirm()
                    } label: {
                        Text(appLanguage.localized("gv_common_ok", comment: "OK"))
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0/255, green: 210/255, blue: 150/255),
                                        Color(red: 0/255, green: 180/255, blue: 120/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 6/255, green: 40/255, blue: 45/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

/// 功能入口网格卡片（2x2）
struct FunctionGridCard: View {
    let onNodeListTap: () -> Void
    let onLanguageTap: (() -> Void)?
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @EnvironmentObject private var routeCoordinator: GVRouteCoordinator
    
    init(
        onNodeListTap: @escaping () -> Void,
        onLanguageTap: (() -> Void)? = nil
    ) {
        self.onNodeListTap = onNodeListTap
        self.onLanguageTap = onLanguageTap
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                FunctionButton(
                    icon: "nodelist",
                    title: appLanguage.localized("gv_node_list_title", comment: "Node list"),
                    action: {
                        // 需求调整：节点锁放到列表内部，入口始终可以进入节点页
                        onNodeListTap()
                    }
                )
                
                NavigationLink {
                    GVLanguageView()
                } label: {
                    FunctionButtonContent(
                        icon: "language",
                        title: appLanguage.localized("gv_lang_nav_title", comment: "Language")
                    )
                }
            }
        }
    }
}

/// 功能按钮
private struct FunctionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            FunctionButtonContent(icon: icon, title: title)
        }
    }
}

/// 功能按钮内容（可复用）
private struct FunctionButtonContent: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 12) {
            Group {
                if icon == "nodelist" || icon == "language" {
                    // 资源图自带背景，不再套圆形灰底
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(red: 45/255, green: 49/255, blue: 52/255))
                            .frame(width: 50, height: 50)
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 13/255, green: 14/255, blue: 14/255)) // #0D0E0E
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

/// 连接统计卡片
struct ConnectionStatsCard: View {
    let totalDuration: TimeInterval
    let totalConnections: Int
    let todayDuration: TimeInterval
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(appLanguage.localized("gv_settings_stats", comment: "Connection stats"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 22) {
                StatRow(
                    imageName: "totalDur",
                    title: appLanguage.localized("gv_stats_total_duration", comment: "Total duration"),
                    value: formatDuration(totalDuration)
                )
                
                StatRow(
                    imageName: "totalCon",
                    title: appLanguage.localized("gv_stats_total_connections", comment: "Total connections"),
                    value: "\(totalConnections)"
                )

                StatRow(
                    imageName: "todayDur",
                    title: appLanguage.localized("gv_stats_today_duration", comment: "Today duration"),
                    value: formatDuration(todayDuration)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 13/255, green: 14/255, blue: 14/255)) // #0D0E0E
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d h %d m", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d m", minutes)
        } else {
            return appLanguage.localized("gv_stats_less_than_minute", comment: "Less than a minute")
        }
    }
}

/// 工具箱入口卡片
struct ToolboxEntryCard: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @EnvironmentObject private var routeCoordinator: GVRouteCoordinator
    
    var body: some View {
        Button {
            routeCoordinator.showToolbox()
        } label: {
            HStack(spacing: 16) {
                // 资源图自带背景，不再套灰色圆角底
                Image("toolbox")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(appLanguage.localized("gv_toolbox_title", comment: "Toolbox title"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(appLanguage.localized("gv_toolbox_subtitle", comment: "Toolbox subtitle"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 13/255, green: 14/255, blue: 14/255)) // #0D0E0E
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

/// 统计行（左侧为带背景的资源图，不另加底）
private struct StatRow: View {
    let imageName: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

