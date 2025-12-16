//
//  VPNStatus.swift
//  GreenVPN
//
//  Created by sister on 2025/12/16.
//

import Foundation

// VPN连接状态枚举
enum VPNStatus {
    case disconnected   // 未连接
    case connecting     // 连接中
    case connected      // 已连接
    case failed         // 连接失败
}
