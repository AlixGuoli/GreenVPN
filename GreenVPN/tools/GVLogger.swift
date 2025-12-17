//
//  GVLogger.swift
//  GreenVPN
//
//  统一日志输出：所有内部调试打印带统一前缀，方便过滤
//

import Foundation

enum GVLogger {
    
    private static let prefix = "[GreenVPN]"
    
    /// 统一封装的调试打印
    /// - Parameters:
    ///   - tag: 可选模块标签，例如 "SessionAgent"、"VPNManager"
    ///   - message: 日志内容
    static func log(_ tag: String? = nil, _ message: String) {
        if let tag, !tag.isEmpty {
            debugPrint("\(prefix)[\(tag)] \(message)")
        } else {
            debugPrint("\(prefix) \(message)")
        }
    }
}


