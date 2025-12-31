//
//  GVBannerDisplayController.swift
//  GreenVPN
//
//  自定义 Banner 展示页面（混淆自 BannerScreen/BannerBoard）
//

import Foundation
import UIKit
import YandexMobileAds

/// 自定义 Banner 展示控制器（混淆自 BannerBoard）
final class GVBannerDisplayController: UIViewController {
    
    var didClickAd = false
    private var delayFlag = false
    private var penetrateFlag = false
    private var remainSeconds = 6
    private let skipBox = UIView()
    private let skipText = UILabel()
    private var timer: Timer?
    
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAdLogic()
        setupUI()
        setupObservers()
        startCountdown()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }
    
    // MARK: - 广告系统配置
    
    private func setupAdLogic() {
        GVAdCoordinator.shared.isPresenting = true
        
        let delayThreshold = Int.random(in: 1...100)
        let penetrationThreshold = Int.random(in: 1...100)
        
        let penetration = GVAdsConfigTools.shared.penetration()
        let clickDelay = GVAdsConfigTools.shared.delay()
        
        penetrateFlag = penetration >= penetrationThreshold
        delayFlag = clickDelay >= delayThreshold
        
        GVLogger.log("[Ad]", "穿透率: \(penetration)% | 随机值: \(penetrationThreshold)")
        GVLogger.log("[Ad]", "点击延迟: \(clickDelay)% | 随机值: \(delayThreshold)")
        
        // 如果未命中穿透率，直接关闭
        if !penetrateFlag {
            dismissAd()
            return
        }
        
        guard let bannerView = GVAdCoordinator.shared.obtainBa() else {
            dismissAd()
            return
        }
        
        // 设置广告点击回调（对应旧代码 BannerEnv.onBannerClicked）
        GVAdCoordinator.shared.setBannerClickCallback { [weak self] in
            self?.didClickAd = true
        }
        
        attachBanner(bannerView)
    }
    
    private func attachBanner(_ bannerView: UIView) {
        view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - 界面创建
    
    private func setupUI() {
        view.backgroundColor = .white
        setupSkipBox()
        setupSkipText()
        layoutSkipBox()
    }
    
    private func setupSkipBox() {
        skipBox.translatesAutoresizingMaskIntoConstraints = false
        skipBox.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        skipBox.layer.cornerRadius = 10
        view.addSubview(skipBox)
    }
    
    private func setupSkipText() {
        skipText.textAlignment = .center
        skipText.textColor = .white
        skipText.font = UIFont.systemFont(ofSize: 14)
        skipText.text = String(format: NSLocalizedString("gv_banner_wait_text", comment: ""), remainSeconds)
        
        let interactionEnabled = !penetrateFlag
        skipText.isUserInteractionEnabled = interactionEnabled
        skipBox.isUserInteractionEnabled = interactionEnabled
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(skipButtonTapped))
        skipText.addGestureRecognizer(tapGesture)
    }
    
    private func layoutSkipBox() {
        skipBox.addSubview(skipText)
        skipText.translatesAutoresizingMaskIntoConstraints = false
        
        let config = GVAdsConfigTools.shared.skipConfig()
        
        var containerConstraints: [NSLayoutConstraint] = []
        
        switch config.location {
        case 0: // topLeft
            containerConstraints = [
                skipBox.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.y)),
                skipBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.x))
            ]
        case 1: // topRight
            containerConstraints = [
                skipBox.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.y)),
                skipBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.x))
            ]
        case 2: // centerLeft
            containerConstraints = [
                skipBox.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(config.y)),
                skipBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.x))
            ]
        case 3: // centerRight
            containerConstraints = [
                skipBox.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(config.y)),
                skipBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.x))
            ]
        case 4: // bottomLeft
            containerConstraints = [
                skipBox.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -CGFloat(config.y)),
                skipBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.x))
            ]
        case 5: // bottomRight
            containerConstraints = [
                skipBox.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -CGFloat(config.y)),
                skipBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.x))
            ]
        default: // 默认 topLeft
            containerConstraints = [
                skipBox.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.y)),
                skipBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.x))
            ]
        }
        
        let labelConstraints = [
            skipText.topAnchor.constraint(equalTo: skipBox.topAnchor, constant: 4),
            skipText.leadingAnchor.constraint(equalTo: skipBox.leadingAnchor, constant: 10),
            skipText.bottomAnchor.constraint(equalTo: skipBox.bottomAnchor, constant: -4),
            skipText.trailingAnchor.constraint(equalTo: skipBox.trailingAnchor, constant: -10),
            skipText.heightAnchor.constraint(equalToConstant: 30)
        ]
        
        NSLayoutConstraint.activate(containerConstraints + labelConstraints)
    }
    
    // MARK: - 通知注册
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        guard didClickAd else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismissAd()
        }
    }
    
    // MARK: - 用户交互
    
    @objc private func skipButtonTapped() {
        let canSkip = remainSeconds <= 1
        if canSkip {
            dismissAd()
        }
    }
    
    // MARK: - 广告关闭
    
    private func dismissAd() {
        dismiss(animated: true) {
            GVAdCoordinator.shared.isPresenting = false
            self.onDismiss?()
            GVLogger.log("[Ad]", "关闭广告")
        }
    }
    
    // MARK: - 倒计时管理
    
    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.processCountdownTick(timer)
        }
    }
    
    private func processCountdownTick(_ timer: Timer) {
        if remainSeconds > 0 {
            remainSeconds -= 1
            refreshSkipButtonText()
        } else {
            skipText.isUserInteractionEnabled = true
            skipBox.isUserInteractionEnabled = true
            refreshSkipButtonText()
            timer.invalidate()
        }
    }
    
    private func enableSkipButton() {
        let shouldEnable = !delayFlag || !penetrateFlag
        if shouldEnable {
            skipText.isUserInteractionEnabled = true
            skipBox.isUserInteractionEnabled = true
        }
    }
    
    private func refreshSkipButtonText() {
        if remainSeconds <= 0 {
            enableSkipButton()
            skipText.text = NSLocalizedString("gv_banner_skip_text", comment: "")
        } else {
            skipText.text = String(format: NSLocalizedString("gv_banner_wait_text", comment: ""), remainSeconds)
        }
    }
}
