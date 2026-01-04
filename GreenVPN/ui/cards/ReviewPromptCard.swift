//
//  ReviewPromptCard.swift
//  GreenVPN
//
//  评价提示卡片：显示标题、描述和5星评价
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
        VStack(spacing: 18) {
            // 标题（带小图标）
            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(appLanguage.localized("gv_review_title", comment: "Review prompt title"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // 描述
            Text(appLanguage.localized("gv_review_body", comment: "Review prompt body"))
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineSpacing(5)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // 星星评分（居中，带装饰）
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { index in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                selectedStars = index
                                starScale[index] = 1.3
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    starScale[index] = 1.0
                                }
                            }
                            
                            // 点击星星后延迟一点再跳转
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                openReviewPage()
                            }
                        }) {
                            ZStack {
                                // 光晕效果（仅点亮时显示）
                                if index <= selectedStars {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color.yellow.opacity(0.3),
                                                    Color.clear
                                                ],
                                                center: .center,
                                                startRadius: 5,
                                                endRadius: 20
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                        .blur(radius: 2)
                                }
                                
                                // 星星图标
                                Image(systemName: index <= selectedStars ? "star.fill" : "star")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(
                                        index <= selectedStars ?
                                        LinearGradient(
                                            colors: [Color.yellow, Color.orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(
                                        color: index <= selectedStars ? Color.yellow.opacity(0.5) : Color.clear,
                                        radius: 8,
                                        x: 0,
                                        y: 2
                                    )
                            }
                            .scaleEffect((starScale[index] ?? 1.0) * (starPulse[index] ?? 1.0))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(22)
        .background(
            ZStack {
                // 渐变背景
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // 边框
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // 顶部装饰光晕
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.yellow.opacity(0.08),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.15, y: 0.15),
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击卡片其他区域也跳转
            openReviewPage()
        }
        .onAppear {
            startStarAnimations()
        }
    }
    
    private func startStarAnimations() {
        // 为每个星星创建错开的呼吸动画
        for index in 1...5 {
            let delay = Double(index - 1) * 0.15 // 每个星星延迟0.15秒
            let duration = 1.5 + Double.random(in: -0.2...0.2) // 随机持续时间，增加自然感
            
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

