//
//  GVAppLanguage.swift
//  GreenVPN
//
//  应用内多语言管理：支持跟随系统 / 简体中文 / English
//

import Foundation
import SwiftUI
import Combine

final class GVAppLanguage: ObservableObject {
    
    enum Option: String, CaseIterable, Identifiable {
        case system = "system"
        case zhHans = "zh-Hans"
        case en = "en"
        
        var id: String { rawValue }
    }
    
    static let shared = GVAppLanguage()
    
    private let storageKey = "GV_AppLanguage_Option"
    
    @Published var option: Option {
        didSet {
            UserDefaults.standard.set(option.rawValue, forKey: storageKey)
        }
    }
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let stored = Option(rawValue: raw) {
            self.option = stored
        } else {
            self.option = .system
        }
    }
    
    /// 当前 SwiftUI Locale（用于 Date 等系统控件）
    var locale: Locale {
        switch option {
        case .system:
            return .current
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
        }
    }
    
    /// 返回当前语言对应的 bundle
    private var activeBundle: Bundle {
        let code: String?
        switch option {
        case .system:
            code = nil
        case .zhHans:
            code = "zh-Hans"
        case .en:
            code = "en"
        }
        
        if let code = code,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }
    
    func localized(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, tableName: nil, bundle: activeBundle, value: "", comment: comment)
    }
}

/// 便捷函数：根据当前 GVAppLanguage 取文案（保留给非 SwiftUI 场景使用）
func GVTr(_ key: String, comment: String = "") -> String {
    GVAppLanguage.shared.localized(key, comment: comment)
}


