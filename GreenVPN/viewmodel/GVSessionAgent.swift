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
    
    init() {
        backendState = systemGV.driver.connection.status
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
        syncFromSystem()
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
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
            }
        }
        map[.connected] = connected
        
        // 断开 / 无效
        let disconnected: BackendReducer = { agent in
            GVLogger.log("SessionAgent", "NEVPNStatus 更新为 disconnected / invalid")
            agent.phase = .idle
            if agent.pendingUserStop {
                agent.outcome = .disconnectSuccess
                agent.showingProgress = false
                agent.pendingUserStop = false
            }
            agent.awaitingPostCheck = false
        }
        map[ .disconnected ] = disconnected
        map[ .invalid ]      = disconnected
        
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
    
    /// 执行连接后的二次检查（当前是 5 秒模拟，后续可接真检测）
    private func performPostCheck() {
        GVLogger.log("SessionAgent", "开始连接结果检测（当前为 5 秒模拟延迟）")
        
        Task { @MainActor in
            // 这里先简单延迟 5 秒，后续可以替换为真实探测（如访问 Google 等）
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            
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
