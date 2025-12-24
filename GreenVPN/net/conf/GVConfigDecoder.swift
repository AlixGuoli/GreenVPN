//
//  GVConfigDecoder.swift
//  GreenVPN
//
//  解密本地或 Git 返回的加密配置，得到 JSON 文本
//

import Foundation
import CryptoKit

enum GVConfigDecoder {
    
    /// AES 密钥字符串（固定值）
    private static let rawAESKey = "f92mUj0K1uBnMlXGFQKrYP07Emgc4yFmWYS8WRgy4IY="
    
    /// 解密加密配置字符串，得到 JSON 文本
    ///
    /// - Parameter encoded: 形如 `"base64Cipher,hexIV,extra"` 的字符串
    /// - Returns: 解密后的 JSON 字符串，失败返回 nil
    static func decode(_ encoded: String) -> String? {
        // 拆分为三段
        let segments = encoded.split(separator: ",")
        guard segments.count >= 2 else {
            GVLogger.log("ConfigDecoder", "解密失败：格式错误（段数不足）")
            return nil
        }
        
        let base64Cipher = segments[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let hexIV = segments[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 生成对称密钥：取 aesKey 的前 32 字节
        guard let keyDataAll = rawAESKey.data(using: .utf8),
              keyDataAll.count >= 16 else {
            GVLogger.log("ConfigDecoder", "解密失败：AES 密钥数据异常")
            return nil
        }
        let keyData = keyDataAll.subdata(in: 0..<min(32, keyDataAll.count))
        let symmetricKey = SymmetricKey(data: keyData)
        
        guard let ivData = data(fromHex: hexIV),
              let cipherData = Data(base64Encoded: base64Cipher) else {
            GVLogger.log("ConfigDecoder", "解密失败：IV 或密文转换失败")
            return nil
        }
        
        do {
            // AES-GCM: nonce(12字节) + cipher + tag
            let combined = ivData + cipherData
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)
            let result = String(data: decrypted, encoding: .utf8)
            return result
        } catch {
            GVLogger.log("ConfigDecoder", "解密失败：\(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从十六进制字符串构造 Data
    private static func data(fromHex hex: String) -> Data? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}

