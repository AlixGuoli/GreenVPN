//
//  GVPurchaseView.swift
//  GreenVPN
//
//  内购页面
//

import SwiftUI
import StoreKit
import UIKit

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
    
    /// 获取计划标签文案
    private func planTagText(for plan: SubscriptionPlan) -> String? {
        switch plan {
        case .weekly: return nil
        case .monthly: return appLanguage.localized("gv_premium_plan_tag_most_popular", comment: "")
        case .annual: return appLanguage.localized("gv_premium_plan_tag_best_value", comment: "")
        }
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
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.white.opacity(0.8))
                            } else {
                                Text(appLanguage.localized("gv_premium_not_subscribed", comment: ""))
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.white.opacity(0.8))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        
                        // 功能特性列表
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(
                                icon: "logoAd",
                                title: appLanguage.localized("gv_premium_feature_no_ads_title", comment: ""),
                                subtitle: appLanguage.localized("gv_premium_feature_no_ads_subtitle", comment: "")
                            )
                            FeatureRow(
                                icon: "logoCon",
                                title: appLanguage.localized("gv_premium_feature_faster_speeds_title", comment: ""),
                                subtitle: appLanguage.localized("gv_premium_feature_faster_speeds_subtitle", comment: "")
                            )
                            FeatureRow(
                                icon: "logoWorld",
                                title: appLanguage.localized("gv_premium_feature_global_servers_title", comment: ""),
                                subtitle: appLanguage.localized("gv_premium_feature_global_servers_subtitle", comment: "")
                            )
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
                                        tagText: planTagText(for: plan),
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
                            
                            AgreementTextView(
                                prefix: appLanguage.localized("gv_premium_agreement_prefix", comment: ""),
                                autoRenewalText: appLanguage.localized("gv_premium_agreement_auto_renewal", comment: ""),
                                andText: appLanguage.localized("gv_premium_agreement_and", comment: ""),
                                membershipText: appLanguage.localized("gv_premium_agreement_membership", comment: ""),
                                autoRenewalURL: URL(string: "https://greenshieldvpn7.xyz/m.html"),
                                membershipURL: URL(string: "https://greenshieldvpn7.xyz/m.html"),
                                onLinkTapped: { url in
                                    openURL(url)
                                }
                            )
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
                            
                            TermsLinkText(
                                prefix: appLanguage.localized("gv_premium_terms_link_prefix", comment: ""),
                                termsOfUseText: appLanguage.localized("gv_premium_terms_of_use", comment: ""),
                                andText: appLanguage.localized("gv_premium_terms_link_and", comment: ""),
                                privacyPolicyText: appLanguage.localized("gv_premium_privacy_policy", comment: ""),
                                termsOfUseURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
                                privacyPolicyURL: URL(string: "https://greenshieldvpn7.xyz/p.html"),
                                onLinkTapped: { url in
                                    openURL(url)
                                }
                            )
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
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            
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
    let tagText: String?
    let onTap: () -> Void
    
    /// 计算每天的价格，保持与总价相同的货币格式
    private var dailyPrice: String? {
        guard let product = product else { return nil }
        
        let days: Int
        switch plan {
        case .weekly: days = 7
        case .monthly: days = 30
        case .annual: days = 365
        }
        
        let displayPrice = product.displayPrice
        
        // 从 displayPrice 中提取货币符号和数字，保持与总价一致的格式
        let currencySymbol = extractCurrencySymbol(from: displayPrice)
        let numberPart = extractNumber(from: displayPrice)
        
        if let numberPart = numberPart, let currencySymbol = currencySymbol {
            let totalPrice = Double(numberPart) ?? 0
            let dailyPriceValue = totalPrice / Double(days)
            
            if let formatted = formatPrice(dailyPriceValue, currencySymbol: currencySymbol, originalFormat: displayPrice) {
                return "\(formatted)/day"
            }
        }
        
        // 备用方案：使用系统 locale
        let priceDouble = NSDecimalNumber(decimal: product.price).doubleValue
        let dailyPriceValue = priceDouble / Double(days)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        
        if let dailyPriceString = formatter.string(from: NSNumber(value: dailyPriceValue)) {
            return "\(dailyPriceString)/day"
        }
        return nil
    }
    
    /// 从价格字符串中提取货币符号
    private func extractCurrencySymbol(from priceString: String) -> String? {
        let cleaned = priceString.replacingOccurrences(of: "[0-9.,\\s]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? nil : cleaned
    }
    
    /// 从价格字符串中提取数字部分
    private func extractNumber(from priceString: String) -> String? {
        let numberString = priceString.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
        return numberString.isEmpty ? nil : numberString
    }
    
    /// 格式化价格，使用相同的货币符号和格式
    private func formatPrice(_ value: Double, currencySymbol: String, originalFormat: String) -> String? {
        let isPrefix = originalFormat.hasPrefix(currencySymbol)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        // 判断小数分隔符（点或逗号）
        if originalFormat.contains(",") && !originalFormat.contains(".") {
            formatter.decimalSeparator = ","
            formatter.groupingSeparator = "."
        } else {
            formatter.decimalSeparator = "."
            formatter.groupingSeparator = ","
        }
        
        if let numberString = formatter.string(from: NSNumber(value: value)) {
            return isPrefix ? "\(currencySymbol)\(numberString)" : "\(numberString) \(currencySymbol)"
        }
        return nil
    }
    
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
                
                // 右侧：标签和每天价格（上下排列，靠右）
                VStack(alignment: .trailing, spacing: 4) {
                    if let tag = tagText {
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(red: 1.0, green: 0.84, blue: 0.0, opacity: 0.15))
                            )
                    }
                    
                    if let dailyPrice = dailyPrice {
                        Text(dailyPrice)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.6))
                            .padding(.trailing, 8)
                    }
                }
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

// MARK: - Agreement Text View (UITextView wrapper)

struct AgreementTextView: UIViewRepresentable {
    let prefix: String
    let autoRenewalText: String
    let andText: String
    let membershipText: String
    let autoRenewalURL: URL?
    let membershipURL: URL?
    let onLinkTapped: (URL) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.maximumNumberOfLines = 0
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.onLinkTapped = onLinkTapped
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 更新闭包引用
        context.coordinator.onLinkTapped = onLinkTapped
        
        // 构建完整文本（prefix 后加空格，符合英文等语言习惯）
        let fullText = "\(prefix) \(autoRenewalText)\(andText)\(membershipText)."
        
        // 检查文本是否改变，避免不必要的重建
        if let currentText = uiView.attributedText?.string, currentText == fullText {
            // 文本未改变，只更新闭包即可
            return
        }
        
        // 创建属性字符串
        let attributedString = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.white
            ]
        )
        
        // 使用 NSString.range(of:) 精确查找文本位置，避免硬编码位置计算
        // 这样可以处理不同语言的空格和标点差异
        let nsFullText = fullText as NSString
        
        // 设置 Auto-Renewal Terms 链接
        if let autoRenewalURL = autoRenewalURL {
            // 查找 autoRenewalText 在完整文本中的位置
            // 使用完整的文本匹配，确保找到正确的位置（即使文本在其他地方也出现）
            let searchRange = NSRange(location: prefix.count + 1, length: fullText.count - prefix.count - 1)
            let autoRenewalRange = nsFullText.range(of: autoRenewalText, options: [], range: searchRange)
            if autoRenewalRange.location != NSNotFound {
                attributedString.addAttribute(.link, value: autoRenewalURL, range: autoRenewalRange)
            }
        }
        
        // 设置 Membership Terms 链接
        if let membershipURL = membershipURL {
            // 查找 membershipText 在完整文本中的位置
            // 从 autoRenewalText 之后开始搜索，确保找到正确的位置
            let searchStart = prefix.count + 1 + autoRenewalText.count + andText.count
            let searchRange = NSRange(location: searchStart, length: fullText.count - searchStart)
            let membershipRange = nsFullText.range(of: membershipText, options: [], range: searchRange)
            if membershipRange.location != NSNotFound {
                attributedString.addAttribute(.link, value: membershipURL, range: membershipRange)
            }
        }
        
        uiView.attributedText = attributedString
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else { return nil }
        
        // 确保 textContainer 的宽度与提案宽度一致
        let containerWidth = uiView.textContainer.size.width
        if abs(containerWidth - width) > 0.1 {
            uiView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        }
        
        // 计算所需大小
        uiView.layoutIfNeeded()
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return size
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTapped: ((URL) -> Void)?
        
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            onLinkTapped?(URL)
            return false // 阻止系统默认行为，使用自定义处理
        }
    }
}

// MARK: - Terms Link Text View

struct TermsLinkText: View {
    let prefix: String
    let termsOfUseText: String
    let andText: String
    let privacyPolicyText: String
    let termsOfUseURL: URL?
    let privacyPolicyURL: URL?
    let onLinkTapped: (URL) -> Void
    
    var body: some View {
        let fullText = "\(prefix)\(termsOfUseText)\(andText)\(privacyPolicyText)."
        var attributedString = AttributedString(fullText)
        attributedString.font = .system(size: 11)
        attributedString.foregroundColor = .white.opacity(0.5)
        
        // 设置 Terms of Use 链接
        if let termsOfUseURL = termsOfUseURL,
           let range = attributedString.range(of: termsOfUseText) {
            attributedString[range].foregroundColor = .blue
            attributedString[range].underlineStyle = .single
            attributedString[range].link = termsOfUseURL
        }
        
        // 设置 Privacy Policy 链接
        if let privacyPolicyURL = privacyPolicyURL,
           let range = attributedString.range(of: privacyPolicyText) {
            attributedString[range].foregroundColor = .blue
            attributedString[range].underlineStyle = .single
            attributedString[range].link = privacyPolicyURL
        }
        
        return Text(attributedString)
            .onOpenURL { url in
                onLinkTapped(url)
            }
    }
}

#Preview {
    GVPurchaseView()
        .environmentObject(GVAppLanguage.shared)
}

