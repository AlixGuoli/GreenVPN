//
//  GVAppLanguage.swift
//  GreenVPN
//
//  应用内多语言管理：支持跟随系统 / English / 其他语言
//

import Foundation
import SwiftUI
import Combine

final class GVAppLanguage: ObservableObject {
    
    enum Option: String, CaseIterable, Identifiable {
        case system = "system"
        case en      = "en"
        case ru      = "ru"
        case es      = "es"
        case ptBR    = "pt-BR"
        case de      = "de"
        case fr      = "fr"
        case ja      = "ja"
        case ko      = "ko"
        
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
        case .en:
            return Locale(identifier: "en")
        case .ru:
            return Locale(identifier: "ru")
        case .es:
            return Locale(identifier: "es")
        case .ptBR:
            return Locale(identifier: "pt-BR")
        case .de:
            return Locale(identifier: "de")
        case .fr:
            return Locale(identifier: "fr")
        case .ja:
            return Locale(identifier: "ja")
        case .ko:
            return Locale(identifier: "ko")
        }
    }
    
    /// 返回当前语言对应的 bundle
    private var activeBundle: Bundle {
        let code: String?
        switch option {
        case .system:
            code = nil
        case .en:
            code = "en"
        case .ru:
            code = "ru"
        case .es:
            code = "es"
        case .ptBR:
            code = "pt-BR"
        case .de:
            code = "de"
        case .fr:
            code = "fr"
        case .ja:
            code = "ja"
        case .ko:
            code = "ko"
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


