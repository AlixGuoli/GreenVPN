//
//  GVAppState.swift
//  GreenVPN
//
//  全局状态管理（用于广告等全局访问，混淆自 AppGlobalStatus）
//

import Foundation

/// 全局状态管理（单例，混淆自 AppGlobalStatus）
final class GVAppState {
    
    static let shared = GVAppState()
    
    private init() {}
    
    /// 全局当前连接状态
    var currentPhase: SessionPhase = .idle
}

