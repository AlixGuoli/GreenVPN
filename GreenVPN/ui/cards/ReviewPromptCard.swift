//
//  ReviewPromptCard.swift
//  GreenVPN
//
//  评价提示卡片：与设计稿一致（rateLogo 标题图、starYes/starNo 评分）
//

import SwiftUI

struct ReviewPromptCard: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @Environment(\.openURL) private var openURL
    
    @State private var selectedStars: Int = 4
    @State private var starScale: [Int: CGFloat] = [:]
    @State private var starPulse: [Int: CGFloat] = [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0]
    
    private let reviewURL = "https://apps.apple.com/app/id6756861853?action=write-review"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image("rateLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                
                Text(appLanguage.localized("gv_review_title", comment: "Review prompt title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer(minLength: 0)
            }
            
            Text(appLanguage.localized("gv_review_body", comment: "Review prompt body"))
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 20) {
                ForEach(1...5, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            selectedStars = index
                            starScale[index] = 1.12
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                starScale[index] = 1.0
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            openReviewPage()
                        }
                    }) {
                        Image(index <= selectedStars ? "starYes" : "starNo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .scaleEffect((starScale[index] ?? 1.0) * (starPulse[index] ?? 1.0))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 5)
            .padding(.bottom, 15)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180)
        .background {
            Image("bgrate")
                .resizable()
                .scaledToFill()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openReviewPage()
        }
        .onAppear {
            startStarAnimations()
        }
    }
    
    private func startStarAnimations() {
        for index in 1...5 {
            let delay = Double(index - 1) * 0.15
            let duration = 1.5 + Double.random(in: -0.2...0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    starPulse[index] = 1.2
                }
            }
        }
    }
    
    private func openReviewPage() {
        if let url = URL(string: reviewURL) {
            openURL(url)
        }
    }
}
