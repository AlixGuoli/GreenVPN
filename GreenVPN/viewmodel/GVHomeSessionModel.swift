//
//  GVHomeSessionModel.swift
//  GreenVPN
//
//  轻量级 ViewModel：为首页提供包装后的会话状态与操作
//

import Foundation
import Combine

final class GVHomeSessionModel: ObservableObject {
    
    // 对 UI 暴露的状态（从 GVSessionAgent 映射而来）
    @Published private(set) var phase: SessionPhase = .idle
    @Published private(set) var showingProgress: Bool = false
    @Published private(set) var outcome: SessionOutcome? = nil
    @Published private(set) var showDisconnectConfirm: Bool = false
    
    private let agent: GVSessionAgent
    private var cancellables = Set<AnyCancellable>()
    
    init(agent: GVSessionAgent) {
        self.agent = agent
        bindAgent()
    }
    
    private func bindAgent() {
        agent.$phase
            .receive(on: RunLoop.main)
            .assign(to: &$phase)
        
        agent.$showingProgress
            .receive(on: RunLoop.main)
            .assign(to: &$showingProgress)
        
        agent.$outcome
            .receive(on: RunLoop.main)
            .assign(to: &$outcome)
        
        agent.$showDisconnectConfirm
            .receive(on: RunLoop.main)
            .assign(to: &$showDisconnectConfirm)
    }
    
    // MARK: - UI 交互入口
    
    func handlePrimaryAction() {
        agent.handlePrimaryAction()
    }
    
    func confirmDisconnect() {
        agent.confirmDisconnect()
    }
    
    func cancelDisconnect() {
        agent.cancelDisconnect()
    }
    
    func clearOutcome() {
        agent.outcome = nil
    }
}


