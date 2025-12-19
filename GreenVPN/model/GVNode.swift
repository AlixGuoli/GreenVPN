//
//  GVNode.swift
//  GreenVPN
//
//  节点数据模型
//

import Foundation

/// VPN 节点数据模型
struct GVNode: Identifiable, Hashable, Codable {
    /// 节点唯一标识符
    let id: Int
    
    /// 节点显示名称（如 "新加坡 #1"）
    let name: String
    
    /// 国家/地区代码（如 "sg", "us", "jp"）
    let countryCode: String
    
    /// 国家/地区显示名称（如 "新加坡", "美国"）
    let countryName: String
    
    /// 假延迟（毫秒），用于 UI 显示
    var latency: Int
    
    /// 节点是否可用（假数据中默认都是 true）
    var isAvailable: Bool
    
    /// 节点负载（0.0 - 1.0），用于显示负载情况
    var load: Double
    
    init(
        id: Int,
        name: String,
        countryCode: String,
        countryName: String,
        latency: Int = 0,
        isAvailable: Bool = true,
        load: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.countryName = countryName
        self.latency = latency
        self.isAvailable = isAvailable
        self.load = load
    }
}

