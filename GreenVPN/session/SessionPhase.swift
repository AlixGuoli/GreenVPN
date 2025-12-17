//
//  SessionPhase.swift
//  GreenVPN
//
//  Created by sister on 2025/12/16.
//

import Foundation

// 对 UI 暴露的会话阶段（与系统 NEVPNStatus 解耦）
enum SessionPhase {
    case idle        // 未连接
    case inProgress  // 连接中 / 断开中
    case online      // 已连接
    case failed      // 连接失败
}
