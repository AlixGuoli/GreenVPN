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
    
    var clicked = false
    private var delayEnabled = false
    private var penetrateEnabled = false
    private var countdown = 6
    private let container = UIView()
    private let label = UILabel()
    private var countdownTimer: Timer?
    
    var completion: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeAd()
        prepareInterface()
        registerObservers()
        beginCountdown()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        countdownTimer?.invalidate()
    }
    
    // MARK: - 广告系统配置
    
    private func initializeAd() {
        GVAdCoordinator.shared.isPresenting = true
        
        let delayThreshold = Int.random(in: 1...100)
        let penetrationThreshold = Int.random(in: 1...100)
        
        let penetration = GVAdsConfigTools.shared.penetration()
        let clickDelay = GVAdsConfigTools.shared.delay()
        
        penetrateEnabled = penetration >= penetrationThreshold
        delayEnabled = clickDelay >= delayThreshold
        
        GVLogger.log("[Ad]", "穿透率: \(penetration)% | 随机值: \(penetrationThreshold)")
        GVLogger.log("[Ad]", "点击延迟: \(clickDelay)% | 随机值: \(delayThreshold)")
        
        // 如果未命中穿透率，直接关闭
        if !penetrateEnabled {
            close()
            return
        }
        
        guard let bannerView = GVAdCoordinator.shared.obtainBa() else {
            close()
            return
        }
        
        // 设置广告点击回调（对应旧代码 BannerEnv.onBannerClicked）
        GVAdCoordinator.shared.setBannerClickCallback { [weak self] in
            self?.clicked = true
        }
        
        embedBanner(bannerView)
    }
    
    private func embedBanner(_ bannerView: UIView) {
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
    
    private func prepareInterface() {
        view.backgroundColor = .white
        createContainer()
        createLabel()
        arrangeContainer()
    }
    
    private func createContainer() {
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        container.layer.cornerRadius = 10
        view.addSubview(container)
    }
    
    private func createLabel() {
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.text = String(format: NSLocalizedString("gv_banner_wait_text", comment: ""), countdown)
        
        let interactionEnabled = !penetrateEnabled
        label.isUserInteractionEnabled = interactionEnabled
        container.isUserInteractionEnabled = interactionEnabled
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(skipButtonTapped))
        label.addGestureRecognizer(tapGesture)
    }
    
    private func arrangeContainer() {
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let config = GVAdsConfigTools.shared.skipConfig()
        
        var containerConstraints: [NSLayoutConstraint] = []
        
        switch config.location {
        case 0: // topLeft
            containerConstraints = [
                container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.y)),
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.x))
            ]
        case 1: // topRight
            containerConstraints = [
                container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.y)),
                container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.x))
            ]
        case 2: // centerLeft
            containerConstraints = [
                container.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(config.y)),
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.x))
            ]
        case 3: // centerRight
            containerConstraints = [
                container.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(config.y)),
                container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.x))
            ]
        case 4: // bottomLeft
            containerConstraints = [
                container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -CGFloat(config.y)),
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.x))
            ]
        case 5: // bottomRight
            containerConstraints = [
                container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -CGFloat(config.y)),
                container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.x))
            ]
        default: // 默认 topLeft
            containerConstraints = [
                container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.y)),
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.x))
            ]
        }
        
        let labelConstraints = [
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.heightAnchor.constraint(equalToConstant: 30)
        ]
        
        NSLayoutConstraint.activate(containerConstraints + labelConstraints)
    }
    
    // MARK: - 倒计时管理
    
    private func beginCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.handleTick(timer)
        }
    }
    
    private func handleTick(_ timer: Timer) {
        if countdown > 0 {
            countdown -= 1
            updateLabelText()
        } else {
            label.isUserInteractionEnabled = true
            container.isUserInteractionEnabled = true
            updateLabelText()
            timer.invalidate()
        }
    }
    
    private func activateButton() {
        let shouldEnable = !delayEnabled || !penetrateEnabled
        if shouldEnable {
            label.isUserInteractionEnabled = true
            container.isUserInteractionEnabled = true
        }
    }
    
    private func updateLabelText() {
        if countdown <= 0 {
            activateButton()
            label.text = NSLocalizedString("gv_banner_skip_text", comment: "")
        } else {
            label.text = String(format: NSLocalizedString("gv_banner_wait_text", comment: ""), countdown)
        }
    }
    
    // MARK: - 通知注册
    
    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        guard clicked else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.close()
        }
    }
    
    // MARK: - 用户交互
    
    @objc private func skipButtonTapped() {
        let canSkip = countdown <= 1
        if canSkip {
            close()
        }
    }
    
    // MARK: - 广告关闭
    
    private func close() {
        dismiss(animated: true) {
            GVAdCoordinator.shared.isPresenting = false
            self.completion?()
            GVLogger.log("[Ad]", "关闭广告")
        }
    }
}
