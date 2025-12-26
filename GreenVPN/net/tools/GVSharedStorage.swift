//
//  GVSharedStorage.swift
//  GreenVPN
//
//  共享存储常量定义
//

import Foundation

/// 共享存储常量
enum GVSharedStorage {
    
    /// Group UserDefaults 的 suite name
    static let suiteIdentifier = "group.com.green.fire.vpn.birds"
    
    /// 配置数据 key
    static let contentKey = "GVServiceGroupConfig"
    
    /// 保存时间 key
    static let timestampKey = "GVServiceGroupDate"
}

