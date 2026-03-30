//
//  ConnectingView.swift
//  GreenVPN
//
//  连接中页面：与主页连接态相同背景 + Lottie 动效（资源 anim/connecting.json）
//

import SwiftUI
import UIKit
import Lottie

struct ConnectingView: View {
    @EnvironmentObject private var appLanguage: GVAppLanguage
    @EnvironmentObject private var homeSession: GVHomeSessionModel
    
    @State private var timeoutTask: DispatchWorkItem?
    
    var body: some View {
        ZStack {
            Image(.bgConnect)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                GVLottieLoopView(resourceName: "connecting")
                    .frame(width: connectingLottieSide, height: connectingLottieSide)
                
                Text(appLanguage.localized("gv_connecting_message", comment: "Connecting message"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                ReviewPromptCard()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            GVLogger.log("ConnectingView", "onAppear - 启动40秒超时计时器")
            let task = DispatchWorkItem {
                GVLogger.log("ConnectingView", "40秒超时，自动关闭连接页")
                homeSession.closeConnectingView()
            }
            timeoutTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 40.0, execute: task)
        }
        .onDisappear {
            GVLogger.log("ConnectingView", "onDisappear - 页面消失，取消计时器")
            timeoutTask?.cancel()
            timeoutTask = nil
        }
    }
    
    /// 与 UI 稿一致：圆形动效约屏宽 50%～60%，并限制高度避免顶到评价卡
    private var connectingLottieSide: CGFloat {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let fromWidth = w * 0.56
        let maxByHeight = h * 0.42
        let maxBySafeMargin = w - 40
        return min(fromWidth, maxByHeight, maxBySafeMargin)
    }
}

// MARK: - Lottie（仅 UI，供连接页使用）

private enum GVLottieConnectingResources {
    /// 同步进 App 的资源可能是 `anim/connecting.json`，也可能被扁平成根目录 `connecting.json`，都试一遍。
    static func animation(named name: String) -> LottieAnimation? {
        let bundle = Bundle.main
        let paths: [(subdir: String?, label: String)] = [
            ("anim", "anim/connecting.json"),
            (nil, "根目录 connecting.json"),
        ]
        for (subdir, label) in paths {
            if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: subdir) {
                do {
                    let data = try Data(contentsOf: url)
                    let anim = try JSONDecoder().decode(LottieAnimation.self, from: data)
                    GVLogger.log("ConnectingView", "Lottie 已加载 (\(label)) path=\(url.lastPathComponent)")
                    return anim
                } catch {
                    GVLogger.log("ConnectingView", "Lottie JSON 解析失败 (\(label)): \(error.localizedDescription)")
                }
            }
        }
        if let anim = LottieAnimation.named(name, bundle: bundle, subdirectory: "anim") {
            GVLogger.log("ConnectingView", "Lottie 已通过 named(subdir: anim) 加载")
            return anim
        }
        if let anim = LottieAnimation.named(name, bundle: bundle) {
            GVLogger.log("ConnectingView", "Lottie 已通过 named(根目录) 加载")
            return anim
        }
        GVLogger.log("ConnectingView", "Lottie 未找到 \(name).json：请确认文件已勾选 Target、且名为 connecting.json")
        return nil
    }
}

private struct GVLottieLoopView: UIViewRepresentable {
    let resourceName: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    /// `LottieAnimationView` 自带很大的 intrinsic size，直接交给 SwiftUI 会导致 frame 不生效；用容器 + 四边约束铺满 SwiftUI 给定的区域。
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true
        
        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore
        
        if let animation = GVLottieConnectingResources.animation(named: resourceName) {
            animationView.animation = animation
            animationView.play()
        }
        
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        
        context.coordinator.animationView = animationView
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let av = context.coordinator.animationView else { return }
        guard av.animation != nil else { return }
        if !av.isAnimationPlaying {
            av.play()
        }
    }
    
    final class Coordinator {
        var animationView: LottieAnimationView?
    }
}
