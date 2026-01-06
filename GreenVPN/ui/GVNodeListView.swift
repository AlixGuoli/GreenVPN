//
//  GVNodeListView.swift
//  GreenVPN
//
//  节点列表视图
//

import SwiftUI

struct GVNodeListView: View {
    @EnvironmentObject private var nodeManager: GVNodeManager
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @EnvironmentObject private var routeCoordinator: GVRouteCoordinator
    @StateObject private var purchaseManager = GVPurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 背景：与主页一致的深色渐变
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
                // 顶部标题栏
                HStack {
                    Text(appLanguage.localized("gv_node_list_title", comment: "Node list title"))
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
                
                // 节点列表
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(nodeManager.nodes) { node in
                            let isLocked = !purchaseManager.isVIP && node.id != -1
                            
                            NodeRowView(node: node, isLocked: isLocked)
                                .onTapGesture {
                                    // 非会员：除 Auto 外的节点点击跳转到内购页（在当前栈上 push，返回时回到节点列表）
                                    if isLocked {
                                        routeCoordinator.pushPurchase()
                                    } else {
                                        nodeManager.selectNode(node)
                                        dismiss()
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // 每次进入节点列表时，随机更新延迟和负载
            nodeManager.refreshNodeStats()
            
            // 获取节点列表接口
            Task {
                await nodeManager.fetchNodesFromAPI()
            }
        }
    }
}

// MARK: - 节点行视图

private struct NodeRowView: View {
    let node: GVNode
    let isLocked: Bool
    @EnvironmentObject private var nodeManager: GVNodeManager
    @EnvironmentObject private var appLanguage: GVAppLanguage
    
    var isSelected: Bool {
        nodeManager.selectedNodeId == node.id
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 国家/地区标识：使用国旗图标
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0/255, green: 180/255, blue: 120/255).opacity(0.3),
                                Color(red: 0/255, green: 140/255, blue: 100/255).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                GVFlagIcon(countryCode: node.countryCode, size: 28)
            }
            
            // 节点信息
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedNodeName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if node.id != -1 {
                    // Auto 节点不显示延迟和负载
                    HStack(spacing: 12) {
                        // 延迟
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 11))
                            Text("\(node.latency) ms")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        
                        // 负载
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 11))
                            Text(loadText)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(loadColor)
                    }
                } else {
                    // Auto 节点显示说明文字
                    Text(appLanguage.localized("gv_node_auto_desc", comment: "Auto node description"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Spacer()
            
            // 右侧状态：非 VIP 的普通节点显示锁，其他显示选中勾
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0/255, green: 210/255, blue: 150/255))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected
                    ? Color.white.opacity(0.15)
                    : Color.white.opacity(0.08)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSelected
                            ? Color(red: 0/255, green: 210/255, blue: 150/255).opacity(0.6)
                            : Color.white.opacity(0.1),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
        )
    }
    
    private var localizedNodeName: String {
        if node.id == -1 {
            return appLanguage.localized("gv_node_auto", comment: "Auto node name")
        }
        let key = "gv_node_\(node.countryCode.lowercased())"
        let localized = appLanguage.localized(key, comment: "Node name")
        // 如果本地化字符串不存在（返回的是 key），则使用接口返回的 name
        return localized == key ? node.name : localized
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
                        .font(.system(size: 18, weight: .semibold))
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

#Preview {
    GVNodeListView()
        .environmentObject(GVNodeManager.shared)
        .environmentObject(GVAppLanguage.shared)
}

