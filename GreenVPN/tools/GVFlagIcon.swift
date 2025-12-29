//
//  GVFlagIcon.swift
//  GreenVPN
//
//  国旗图标工具
//

import SwiftUI

/// 根据国家代码返回对应的国旗图标
struct GVFlagIcon: View {
    let countryCode: String
    let size: CGFloat
    
    init(countryCode: String, size: CGFloat = 24) {
        self.countryCode = countryCode
        self.size = size
    }
    
    var body: some View {
        Group {
            if countryCode.lowercased() == "auto" {
                // 自动选择：使用地球图标
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: size * 0.85, weight: .medium))
                    .foregroundColor(.white)
            } else {
                // 使用 SF Symbols 的国旗图标（iOS 17+ 支持）
                // 格式：flag.2.crossed.fill 或 flag.fill，但更准确的是使用 emoji
                // 为了更好的兼容性，我们使用 emoji 国旗
                Text(flagEmoji(for: countryCode))
                    .font(.system(size: size))
            }
        }
        .frame(width: size, height: size)
    }
    
    /// 根据国家代码返回对应的 emoji 国旗
    private func flagEmoji(for countryCode: String) -> String {
        let code = countryCode.uppercased()
        
        // 国家代码到 emoji 的映射
        let flagMap: [String: String] = [
            "SG": "🇸🇬",  // 新加坡
            "US": "🇺🇸",  // 美国
            "JP": "🇯🇵",  // 日本
            "KR": "🇰🇷",  // 韩国
            "GB": "🇬🇧",  // 英国
            "DE": "🇩🇪",  // 德国
            "FR": "🇫🇷",  // 法国
            "NL": "🇳🇱",  // 荷兰
            "CA": "🇨🇦",  // 加拿大
            "AU": "🇦🇺",  // 澳大利亚
            "IN": "🇮🇳",  // 印度
            "BR": "🇧🇷",  // 巴西
            "RU": "🇷🇺",  // 俄罗斯
        ]
        
        return flagMap[code] ?? "🏳️"  // 默认返回白色旗帜
    }
}

