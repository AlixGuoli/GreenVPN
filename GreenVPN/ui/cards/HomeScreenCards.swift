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
        VStack(spacing: 24) {
            // 圆环（中间灰圆预留给状态图标）
            CoreOrbView(phase: phase)
                .frame(width: 210, height: 210)
            
            // 连接时长显示：放在圆外面，但通过透明度保持占位
            Group {
                let displayText = connectionDuration > 0
                    ? formatDuration(connectionDuration)
                    : formatDuration(0)
                
                Text(displayText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.9))
                    .monospacedDigit()
                    .opacity(phase == .online && connectionDuration > 0 ? 1 : 0)
            }
            // 文案说明
            Text(detailText)
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            // 主按钮
            Button(action: onButtonTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: phase == .online
                                ? [Color.red, Color.orange]
                                : [Color(red: 0/255, green: 180/255, blue: 120/255),
                                   Color(red: 0/255, green: 210/255, blue: 150/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
                    
                    HStack(spacing: 10) {
                        if phase == .inProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            KeyGlyphView(isOn: phase == .online)
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                        
                        Text(buttonText)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
            }
            .disabled(phase == .inProgress)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(cardBackground)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
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
    
    var body: some View {
        Button {
            routeCoordinator.showNodeList()
        } label: {
            HStack(spacing: 16) {
                // 国旗图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0/255, green: 180/255, blue: 120/255).opacity(0.2),
                                    Color(red: 0/255, green: 140/255, blue: 100/255).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    if node.id == -1 {
                        Image(systemName: "globe.asia.australia.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    } else {
                        GVFlagIcon(countryCode: node.countryCode, size: 32)
                    }
                }
                
                // 节点信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(node.id == -1 
                         ? appLanguage.localized("gv_node_auto", comment: "Auto node")
                         : appLanguage.localized("gv_node_\(node.countryCode.lowercased())", comment: "Node name"))
                        .font(.system(size: 18, weight: .semibold))
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
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(loadColor)
                        }
                    } else {
                        Text(appLanguage.localized("gv_node_auto_desc", comment: "Auto node description"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(20)
        }
        .background(cardBackground)
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
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

/// 功能入口网格卡片（2x2）
struct FunctionGridCard: View {
    let onNodeListTap: () -> Void
    let onLanguageTap: (() -> Void)?
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
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
                    icon: "globe.asia.australia.fill",
                    title: appLanguage.localized("gv_node_list_title", comment: "Node list"),
                    action: onNodeListTap
                )
                
                NavigationLink {
                    GVLanguageView()
                } label: {
                    FunctionButtonContent(
                        icon: "globe",
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
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0/255, green: 180/255, blue: 120/255).opacity(0.2),
                                Color(red: 0/255, green: 140/255, blue: 100/255).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 16) {
            Text(appLanguage.localized("gv_settings_stats", comment: "Connection stats"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                StatRow(
                    icon: "clock.fill",
                    title: appLanguage.localized("gv_stats_total_duration", comment: "Total duration"),
                    value: formatDuration(totalDuration)
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                StatRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: appLanguage.localized("gv_stats_total_connections", comment: "Total connections"),
                    value: "\(totalConnections)"
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                StatRow(
                    icon: "calendar",
                    title: appLanguage.localized("gv_stats_today_duration", comment: "Today duration"),
                    value: formatDuration(todayDuration)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(appLanguage.localized("gv_toolbox_title", comment: "Toolbox title"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(appLanguage.localized("gv_toolbox_subtitle", comment: "Toolbox subtitle"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

/// 统计行
private struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0/255, green: 210/255, blue: 150/255))
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.85))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

