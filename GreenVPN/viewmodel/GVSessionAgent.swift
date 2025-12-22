//
//  GVSessionAgent.swift
//  GreenVPN
//
//  Created by sister on 2025/12/16.
//

import Foundation
import Combine
import NetworkExtension

// 连接流程结果（供结果页展示使用）
enum SessionOutcome: Hashable {
    case connectSuccess      // 连接成功
    case connectFail         // 连接失败
    case disconnectSuccess   // 断开成功
}

class GVSessionAgent : ObservableObject {
   
    /// 系统层 VPN 管理
    var systemGV = GVSystem.shared()
    
    /// 标记当前是否需要执行连接后的二次校验（比如网络探测、广告等）
    private var awaitingPostCheck: Bool = false
    
    /// 标记当前断开操作是否由用户主动触发，用于决定结果文案
    private var pendingUserStop: Bool = false
    
    // UI 绑定：是否显示“连接中”流程页
    @Published var showingProgress: Bool = false
    
    // UI 绑定：结果页（成功/失败/断开成功）
    @Published var outcome: SessionOutcome? = nil
    
    // UI 绑定：断开确认
    @Published var showDisconnectConfirm: Bool = false
    
    // UI 绑定：连接时长（秒）
    @Published var connectionDuration: TimeInterval = 0
    
    // 连接开始时间
    private var connectionStartTime: Date?
    
    // 连接时长计时器
    private var durationTimer: Timer?
    
    // UserDefaults key 用于保存连接开始时间
    private let connectionTimestampKey = "GreenVPNConnectionStartTime"
    
    init() {
        backendState = systemGV.driver.connection.status
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
        syncFromSystem()
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
        // 应用退出时只停止计时器，不清除 UserDefaults（VPN 可能还在连接）
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        backendState = GVSystem.shared().driver.connection.status
        GVLogger.log("SessionAgent", "收到 NEVPNStatusDidChange 通知，当前状态 rawValue=\(backendState.rawValue)")
    }
   
    // UI 绑定：连接状态（列表页）
    @Published var phase: SessionPhase = .idle {
        didSet {
            // 同步到GlobalStatus
        }
    }
    
    /// 内部记录的底层连接状态（直接映射 NEVPNStatus）
    @Published var backendState: NEVPNStatus = GVSystem.shared().driver.connection.status {
        didSet {
            guard oldValue != backendState else { return }
            // 统一由映射方法驱动 UI 状态
            foldBackendState(backendState)
        }
    }
    
    /// 将底层状态折叠为 UI 使用的 SessionPhase & 结果（表驱动映射）
    private typealias BackendReducer = (GVSessionAgent) -> Void
    
    private lazy var backendReducers: [NEVPNStatus: BackendReducer] = {
        var map: [NEVPNStatus: BackendReducer] = [:]
        
        // 已连接
        let connected: BackendReducer = { agent in
            GVLogger.log("SessionAgent", "NEVPNStatus 更新为 connected")
            if agent.awaitingPostCheck {
                agent.performPostCheck()      // 仅用户主动流程触发结果页/广告
            } else {
                agent.phase = .online
                // 如果计时器未启动，则恢复或启动（可能是从系统恢复的状态）
                if agent.connectionStartTime == nil {
                    agent.restoreOrStartConnectionTimer()
                }
            }
        }
        map[.connected] = connected
        
        // 断开 / 无效
        let disconnected: BackendReducer = { agent in
            GVLogger.log("SessionAgent", "NEVPNStatus 更新为 disconnected / invalid")
            // 只在真正断开时清除计时器和 UserDefaults
            agent.stopConnectionTimer()
            agent.phase = .idle
            // 防止重复设置 outcome（如果已经设置过，就不再设置）
            if agent.pendingUserStop && agent.outcome == nil {
                agent.outcome = .disconnectSuccess
                agent.showingProgress = false
                agent.pendingUserStop = false
            }
            agent.awaitingPostCheck = false
        }
        map[ .disconnected ] = disconnected
        // 注意：.invalid 不应该触发断开成功结果页，只在 .disconnected 时触发
        let invalid: BackendReducer = { agent in
            GVLogger.log("SessionAgent", "NEVPNStatus 更新为 invalid")
            agent.stopConnectionTimer()
            agent.phase = .idle
            // invalid 状态不设置断开成功结果页
            agent.pendingUserStop = false
            agent.awaitingPostCheck = false
        }
        map[ .invalid ] = invalid
        
        // 连接中
        let connecting: BackendReducer = { agent in
            GVLogger.log("SessionAgent", "NEVPNStatus 更新为 connecting")
            agent.phase = .inProgress
        }
        map[ .connecting ] = connecting
        
        // 断开中 / 重连中
        let tearingDown: BackendReducer = { agent in
            GVLogger.log("SessionAgent", "NEVPNStatus 更新为 disconnecting / reasserting")
            agent.phase = .inProgress
        }
        map[ .disconnecting ] = tearingDown
        map[ .reasserting ]   = tearingDown
        
        return map
    }()
    
    private func foldBackendState(_ newState: NEVPNStatus) {
        if let reducer = backendReducers[newState] {
            reducer(self)
        } else {
            GVLogger.log("SessionAgent", "NEVPNStatus 未知状态，按失败处理")
            phase = .failed
            awaitingPostCheck = false
        }
    }
    
    /// 主按钮触发：由 UI 调用
    func handlePrimaryAction() {
        switch phase {
        case .online:
            // 已连接：先弹出确认框
            showDisconnectConfirm = true
        case .idle, .failed, .inProgress:
            beginConnectFlow()
        }
    }
    
    /// 发起连接前的准备工作：加载配置并获取系统权限
    private func beginConnectFlow() {
        systemGV.prepareEngine() { error in
            GVLogger.log("SessionAgent", "开始加载 VPN 配置（loadAllFromPreferences）")
            if let error = error {
                GVLogger.log("SessionAgent", "加载 VPN 配置失败：\(error)")
            }else{
                GVLogger.log("SessionAgent", "加载 VPN 配置成功，已获取系统权限，开始连接流程")
                self.awaitingPostCheck = true
                self.phase = .inProgress
                self.showingProgress = true
                self.outcome = nil
                self.activateTunnel()
            }
        }
    }
    
    /// 启动时从系统恢复已有配置和状态
    func syncFromSystem() {
        systemGV.restoreEngineIfAvailable { hasConfig, error in
            if let error = error {
                GVLogger.log("SessionAgent", "resetVPN 时仅恢复配置失败：\(error)")
            }
            
            guard hasConfig else {
                // 首次启动或用户从未连接过：不创建配置，也不弹权限，保持默认未连接状态
                GVLogger.log("SessionAgent", "resetVPN：未检测到已保存的 VPN 配置，保持未连接 UI")
                DispatchQueue.main.async {
                    self.phase = .idle
                    self.backendState = .invalid
                }
                return
            }
            
            // 已有配置：根据系统当前状态恢复 UI
            let current = self.systemGV.driver.connection.status
            DispatchQueue.main.async {
                if self.backendState != current {
                    self.backendState = current
                } else {
                    self.foldBackendState(current)
                }
            }
        }
    }
    
    /// 真正发起 VPN 隧道连接
    private func activateTunnel() {
        systemGV.applyEngineConfig() { error in
            guard error == nil else {
                GVLogger.log("SessionAgent", "保存/启用 VPN 配置失败：\(String(describing: error))")
                return
            }
            self.systemGV.startEngine() { error in
                guard error == nil else {
                    GVLogger.log("SessionAgent", "启动 VPN 连接失败：\(String(describing: error))")
                    return
                }
            }
        }
    }
    
    /// 停止 VPN 隧道连接
    private func haltTunnel() {
        systemGV.applyEngineConfig() { error in
            guard error == nil else {
                GVLogger.log("SessionAgent", "停止连接时保存/启用 VPN 配置失败：\(String(describing: error))")
                return
            }
            
            self.systemGV.stopEngine() { error in
                guard error == nil else {
                    GVLogger.log("SessionAgent", "停止 VPN 连接失败：\(String(describing: error))")
                    return
                }
            }
        }
    }
    
    /// 执行连接后的二次检查（当前是 3 秒模拟，后续可接真检测）
    private func performPostCheck() {
        GVLogger.log("SessionAgent", "开始连接结果检测（当前为 3 秒模拟延迟）")
        
        Task { @MainActor in
            // 这里先简单延迟 3 秒，后续可以替换为真实探测（如访问 Google 等）
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            let isSuccess = true
            if isSuccess {
                markConnectSucceeded()
            } else {
                markConnectFailed()
            }
            awaitingPostCheck = false
        }
    }
    
    // 用户确认断开
    func confirmDisconnect() {
        showDisconnectConfirm = false
        pendingUserStop = true
        showingProgress = true
        phase = .inProgress
        // 清除之前的结果页状态，避免重复显示
        outcome = nil
        haltTunnel()
    }
    
    // 用户取消断开
    func cancelDisconnect() {
        showDisconnectConfirm = false
        pendingUserStop = false
    }
    
    private func markConnectSucceeded() {
        GVLogger.log("SessionAgent", "连接结果：成功，更新 UI 为已连接")
        phase = .online
        showingProgress = false
        outcome = .connectSuccess
        awaitingPostCheck = false
        startConnectionTimer()
        // 记录连接次数
        GVConnectionStatsManager.shared.recordConnection()
    }
    
    // MARK: - 连接时长追踪
    
    /// 恢复或启动连接计时器（优先从 UserDefaults 恢复开始时间）
    private func restoreOrStartConnectionTimer() {
        // 只停止计时器，不清除 UserDefaults（因为 VPN 可能还在连接）
        durationTimer?.invalidate()
        durationTimer = nil
        
        // 尝试从 UserDefaults 恢复开始时间
        let savedTimestamp = UserDefaults.standard.double(forKey: connectionTimestampKey)
        if savedTimestamp > 0 {
            let savedStartTime = Date(timeIntervalSince1970: savedTimestamp)
            // 如果保存的时间在合理范围内（不超过7天前），则恢复
            let daysSince = Date().timeIntervalSince(savedStartTime) / 86400
            if daysSince >= 0 && daysSince < 7 {
                connectionStartTime = savedStartTime
                GVLogger.log("SessionAgent", "从 UserDefaults 恢复连接开始时间，已过时长：\(Int(Date().timeIntervalSince(savedStartTime)))秒")
            } else {
                // 时间不合理，重新开始
                connectionStartTime = Date()
                UserDefaults.standard.set(connectionStartTime!.timeIntervalSince1970, forKey: connectionTimestampKey)
                GVLogger.log("SessionAgent", "保存的开始时间不合理，重新开始计时")
            }
        } else {
            // 没有保存的时间，重新开始
            connectionStartTime = Date()
            UserDefaults.standard.set(connectionStartTime!.timeIntervalSince1970, forKey: connectionTimestampKey)
            GVLogger.log("SessionAgent", "没有保存的开始时间，开始新计时")
        }
        
        // 立即计算一次当前时长
        if let startTime = connectionStartTime {
            connectionDuration = Date().timeIntervalSince(startTime)
        }
        
        // 启动定时器
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.connectionStartTime else { return }
            self.connectionDuration = Date().timeIntervalSince(startTime)
        }
        if let timer = durationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// 启动新的连接计时器（用于新连接）
    private func startConnectionTimer() {
        stopConnectionTimer()
        connectionStartTime = Date()
        connectionDuration = 0
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(connectionStartTime!.timeIntervalSince1970, forKey: connectionTimestampKey)
        GVLogger.log("SessionAgent", "开始新连接计时，保存开始时间")
        
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.connectionStartTime else { return }
            self.connectionDuration = Date().timeIntervalSince(startTime)
        }
        if let timer = durationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopConnectionTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        
        // 记录连接时长到统计管理器
        if let startTime = connectionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration > 0 {
                GVConnectionStatsManager.shared.recordDuration(duration)
            }
        }
        
        // 清除保存的开始时间
        UserDefaults.standard.removeObject(forKey: connectionTimestampKey)
        
        connectionStartTime = nil
        connectionDuration = 0
    }
    
    private func markConnectFailed() {
        GVLogger.log("SessionAgent", "连接结果：失败，更新 UI 为失败并断开 VPN")
        haltTunnel()
        phase = .failed
        showingProgress = false
        outcome = .connectFail
        awaitingPostCheck = false
    }
}
