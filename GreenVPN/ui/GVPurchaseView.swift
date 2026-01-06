//
//  GVPurchaseView.swift
//  GreenVPN
//
//  内购页面
//

import SwiftUI
import StoreKit

struct GVPurchaseView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = GVPurchaseManager.shared
    
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isAgreementChecked: Bool = true  // 默认选中
    @State private var showErrorAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var errorMessage: String = ""
    @Environment(\.openURL) private var openURL
    
    enum SubscriptionPlan: String, CaseIterable {
        case weekly = "weekly"
        case monthly = "monthly"
        case annual = "annual"
        
        init?(productId: String) {
            switch productId {
            case "com.green.fire.vpn.birds.weekly":
                self = .weekly
            case "com.green.fire.vpn.birds.monthly":
                self = .monthly
            case "com.green.fire.vpn.birds.annual":
                self = .annual
            default:
                return nil
            }
        }
        
        var productId: String {
            switch self {
            case .weekly: return "com.green.fire.vpn.birds.weekly"
            case .monthly: return "com.green.fire.vpn.birds.monthly"
            case .annual: return "com.green.fire.vpn.birds.annual"
            }
        }
        
        /// 本地化文案 key
        var displayNameKey: String {
            switch self {
            case .weekly: return "gv_premium_plan_weekly"
            case .monthly: return "gv_premium_plan_monthly"
            case .annual: return "gv_premium_plan_annual"
            }
        }
    }
    
    /// 获取选中计划对应的 Product
    private var selectedProduct: Product? {
        purchaseManager.products.first { $0.id == selectedPlan.productId }
    }
    
    /// 格式化过期日期
    private var expirationDateString: String? {
        guard let date = purchaseManager.expirationDate else { return nil }
        let formatter = DateFormatter()
        // 正式环境：按日期展示到天即可，如需更精细可调整格式
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 主按钮标题
    private var primaryButtonTitle: String {
        if purchaseManager.isVIP {
            return appLanguage.localized("gv_premium_button_change_plan", comment: "")
        } else {
            return appLanguage.localized("gv_premium_button_subscribe", comment: "")
        }
    }
    
    /// 是否处于忙碌状态（购买中或恢复中）
    private var isBusy: Bool {
        purchaseManager.isPurchasing || purchaseManager.isRestoring
    }
    
    var body: some View {
        ZStack {
            // 背景：与主页一致的深色渐变 + 噪点
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
                
                NoiseOverlay()
                    .ignoresSafeArea()
                    .blendMode(.overlay)
                    .opacity(0.10)
                
                // 装饰背景图
                Image("bgvip")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .opacity(0.3)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // 顶部返回按钮
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // 内容区域
                ScrollView {
                    VStack(spacing: 24) {
                        // 标题和会员状态（左对齐）
                        VStack(alignment: .leading, spacing: 8) {
                            // 标题 + 钻石图标
                            HStack(alignment: .center, spacing: 8) {
                                Text(appLanguage.localized("gv_premium_title", comment: ""))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color.green)
                                
                                Spacer()
                                
                                Image("vip")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                            }
                            
                            // 会员状态
                            if purchaseManager.isVIP, let expiration = expirationDateString {
                                let template = appLanguage.localized("gv_premium_expires", comment: "")
                                Text(String(format: template, expiration))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.8))
                            } else {
                                Text(appLanguage.localized("gv_premium_not_subscribed", comment: ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.8))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        
                        // 功能特性列表
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(icon: "logoAd", text: appLanguage.localized("gv_premium_feature_no_ads", comment: ""))
                            FeatureRow(icon: "logoCon", text: appLanguage.localized("gv_premium_feature_faster_speeds", comment: ""))
                            FeatureRow(icon: "logoWorld", text: appLanguage.localized("gv_premium_feature_global_servers", comment: ""))
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        
                        // 订阅选项
                        if purchaseManager.isLoadingProducts {
                            ProgressView()
                                .padding(.top, 20)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                                    SubscriptionPlanCard(
                                        plan: plan,
                                        title: appLanguage.localized(plan.displayNameKey, comment: ""),
                                        product: purchaseManager.products.first { $0.id == plan.productId },
                                        isSelected: selectedPlan == plan,
                                        onTap: {
                                            selectedPlan = plan
                                        }
                                    )
                                }
                            }
                            .padding(.top, 8)
                            .padding(.horizontal, 8)
                        }
                        
                        // Agreement 勾选
                        HStack(alignment: .center, spacing: 4) {
                            Button {
                                isAgreementChecked.toggle()
                            } label: {
                                Image(systemName: isAgreementChecked ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 18))
                                    .foregroundColor(isAgreementChecked ? Color.green : Color.white.opacity(0.5))
                            }
                            .padding(.top, 2)
                            
                            HStack(alignment: .top, spacing: 3) {
                                Text(appLanguage.localized("gv_premium_agreement", comment: ""))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                
                                Button {
                                    if let url = URL(string: "https://greenshieldvpn7.xyz/m.html") {
                                        openURL(url)
                                    }
                                } label: {
                                    Text(appLanguage.localized("gv_premium_agreement_auto_renewal", comment: ""))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.blue)
                                        .underline()
                                }
                                
                                Text(",")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                
                                Button {
                                    if let url = URL(string: "https://greenshieldvpn7.xyz/m.html") {
                                        openURL(url)
                                    }
                                } label: {
                                    Text(appLanguage.localized("gv_premium_agreement_membership", comment: ""))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.blue)
                                        .underline()
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                        .padding(.top, 8)
                        
                        // 购买按钮
                        Button {
                            guard let product = selectedProduct else {
                                alertTitle = appLanguage.localized("gv_premium_error", comment: "")
                                errorMessage = appLanguage.localized("gv_premium_error_product_not_loaded", comment: "")
                                showErrorAlert = true
                                return
                            }
                            
                            Task {
                                do {
                                    let success = try await purchaseManager.purchase(product)
                                    if success {
                                        // 购买成功，状态会自动更新
                                    }
                                } catch {
                                    await MainActor.run {
                                        alertTitle = appLanguage.localized("gv_premium_error", comment: "")
                                        errorMessage = error.localizedDescription
                                        showErrorAlert = true
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if purchaseManager.isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(primaryButtonTitle)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isAgreementChecked && !purchaseManager.isPurchasing
                                          ? Color.green
                                          : Color.gray.opacity(0.5))
                            )
                        }
                        .disabled(!isAgreementChecked ||
                                  purchaseManager.isPurchasing ||
                                  selectedProduct == nil)
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        
                        // 恢复购买
                        Button {
                            Task {
                                let result = await purchaseManager.restorePurchases()
                                await MainActor.run {
                                    switch result {
                                    case .restored:
                                        alertTitle = appLanguage.localized("gv_premium_restore_success_title", comment: "")
                                        errorMessage = appLanguage.localized("gv_premium_restore_success_message", comment: "")
                                        showErrorAlert = true
                                    case .none:
                                        alertTitle = appLanguage.localized("gv_premium_restore_none_title", comment: "")
                                        errorMessage = appLanguage.localized("gv_premium_restore_none_message", comment: "")
                                        showErrorAlert = true
                                    case .failed(let error):
                                        alertTitle = appLanguage.localized("gv_premium_error", comment: "")
                                        errorMessage = error.localizedDescription.isEmpty ? appLanguage.localized("gv_premium_error_restore_failed", comment: "") : error.localizedDescription
                                        showErrorAlert = true
                                    }
                                }
                            }
                        } label: {
                            Text(appLanguage.localized("gv_premium_button_restore", comment: ""))
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 8)
                        
                        // Terms & Conditions
                        VStack(alignment: .leading, spacing: 8) {
                            Text(appLanguage.localized("gv_premium_terms_title", comment: ""))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(appLanguage.localized("gv_premium_terms_payment", comment: ""))
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.5))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                        openURL(url)
                                    }
                                } label: {
                                    Text(appLanguage.localized("gv_premium_terms_of_use", comment: ""))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.blue)
                                        .underline()
                                }
                                
                                Button {
                                    if let url = URL(string: "https://greenshieldvpn7.xyz/p.html") {
                                        openURL(url)
                                    }
                                } label: {
                                    Text(appLanguage.localized("gv_premium_privacy_policy", comment: ""))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.blue)
                                        .underline()
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 8)
                }
            }
            
            // 全局遮罩（购买 / 恢复购买过程中禁止操作）
            if isBusy {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(appLanguage.localized("gv_premium_button_processing", comment: ""))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            // 页面加载时刷新订阅状态并加载产品（不再根据结果自动切换选中套餐）
            await purchaseManager.checkSubscriptionStatus()
            await purchaseManager.loadProducts()
        }
        .alert(alertTitle, isPresented: $showErrorAlert) {
            Button(appLanguage.localized("gv_premium_button_ok", comment: ""), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - 功能特性行

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - 订阅选项卡片

private struct SubscriptionPlanCard: View {
    let plan: GVPurchaseView.SubscriptionPlan
    let title: String
    let product: Product?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let product = product {
                        Text(product.displayPrice)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.green)
                    } else {
                        // 加载中占位文案，这里直接用本地化 key，走统一语言机制
                        Text("gv_premium_button_loading")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

#Preview {
    GVPurchaseView()
        .environmentObject(GVAppLanguage.shared)
}

