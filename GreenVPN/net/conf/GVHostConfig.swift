//
//  GVHostConfig.swift
//  GreenVPN
//
//  域名配置管理：负责配置的读取、解密、Git 更新
//

import Foundation

/// 域名配置管理器（单例）
final class GVHostConfig {
    
    static let shared = GVHostConfig()
    
    /// UserDefaults 存储键
    private let configKey = "GVHostConfig"
    
    private init() {}
    
    /// 获取当前配置（返回解析好的字典）
    /// 优先从 UD 读取 JSON 字符串，没有则从本地文件读取并解密后写入 UD
    func config() -> [String: Any]? {
        // 1. 先尝试从 UserDefaults 读取（已解密的 JSON 字符串）
        if let udJson = UserDefaults.standard.string(forKey: configKey), !udJson.isEmpty {
            GVLogger.log("HostConfig", "从 UserDefaults 读取配置")
            if let config = parseConfigJson(udJson) {
                GVLogger.log("HostConfig", "UserDefaults 配置解析成功")
                return config
            } else {
                GVLogger.log("HostConfig", "UserDefaults 配置解析失败，尝试使用本地文件")
            }
        }
        
        // 2. UD 没有或解析失败，尝试从本地文件读取
        if let localEncrypted = loadLocalEncryptedConfig() {
            GVLogger.log("HostConfig", "从本地文件读取加密配置（前100字符）: \(String(localEncrypted.prefix(100)))...")
            if let jsonString = GVConfigDecoder.decode(localEncrypted),
               let config = parseConfigJson(jsonString) {
                GVLogger.log("HostConfig", "本地配置解密成功")
                GVLogger.log("HostConfig", "解密后的配置内容: \(jsonString)")
                // 保存到 UD（保存解密后的 JSON 字符串）
                UserDefaults.standard.set(jsonString, forKey: configKey)
                GVLogger.log("HostConfig", "配置已保存到 UserDefaults")
                return config
            }
        }
        
        GVLogger.log("HostConfig", "❌ 配置加载失败：UD 和本地文件都不可用")
        return nil
    }
    
    /// 从本地 Bundle 读取加密配置
    private func loadLocalEncryptedConfig() -> String? {
        // 先尝试从 net/fo 目录读取
        if let url = Bundle.main.url(forResource: "cool", withExtension: "fo", subdirectory: "net/fo"),
           let content = try? String(contentsOf: url, encoding: .utf8),
           !content.isEmpty {
            let line = content.split(whereSeparator: \.isNewline).first.map(String.init) ?? content
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 如果上面失败，尝试直接读取（不指定目录）
        if let url = Bundle.main.url(forResource: "cool", withExtension: "fo"),
           let content = try? String(contentsOf: url, encoding: .utf8),
           !content.isEmpty {
            let line = content.split(whereSeparator: \.isNewline).first.map(String.init) ?? content
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        GVLogger.log("HostConfig", "本地配置文件读取失败：cool.fo")
        return nil
    }
    
    /// 解析配置 JSON 字符串为字典
    private func parseConfigJson(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    /// 从 Git 更新配置（轮询 git 数组）
    func syncGit() async -> Bool {
        guard let config = config(),
              let apiDict = config["api"] as? [String: Any],
              let gitSources = apiDict["git"] as? [String],
              !gitSources.isEmpty else {
            GVLogger.log("HostConfig", "❌ Git 更新失败：git 数组为空")
            return false
        }
        
        GVLogger.log("HostConfig", "开始通过 Git 更新配置，git 源数量：\(gitSources.count)")
        return await trySyncGit(sources: gitSources, index: 0)
    }
    
    /// 递归轮询 git 数组更新配置
    private func trySyncGit(sources: [String], index: Int) async -> Bool {
        guard index < sources.count else {
            GVLogger.log("HostConfig", "❌ Git 更新失败：所有 git 源都失败")
            return false
        }
        
        let gitUrl = sources[index]
        GVLogger.log("HostConfig", "尝试从 Git 更新配置 [\(index + 1)/\(sources.count)]: \(gitUrl)")
        
        let success = await fetchFromGit(urlString: gitUrl)
        if success {
            return true
        } else {
            return await trySyncGit(sources: sources, index: index + 1)
        }
    }
    
    /// 从单个 Git URL 拉取加密配置并解密
    private func fetchFromGit(urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            GVLogger.log("HostConfig", "Git URL 格式错误")
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        var isCompleted = false
        // 打印 5 秒倒计时
        DispatchQueue.global().async {
            for i in (1...5).reversed() {
                if isCompleted { break }
                GVLogger.log("HostConfig", "Git 请求倒计时：\(i) 秒")
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                isCompleted = true
                
                guard error == nil,
                      let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let data = data,
                      let encryptedString = String(data: data, encoding: .utf8),
                      !encryptedString.isEmpty else {
                    GVLogger.log("HostConfig", "❌ 从 Git 拉取配置失败：\(urlString)")
                    continuation.resume(returning: false)
                    return
                }
                
                // 打印 Git 返回的加密内容
                GVLogger.log("HostConfig", "Git 返回的加密配置（前100字符）: \(String(encryptedString.prefix(100)))...")
                
                // 解密配置
                guard let jsonString = GVConfigDecoder.decode(encryptedString),
                      let config = self?.parseConfigJson(jsonString) else {
                    GVLogger.log("HostConfig", "❌ Git 配置解密失败")
                    continuation.resume(returning: false)
                    return
                }
                
                // 打印解密后的内容
                GVLogger.log("HostConfig", "Git 解密后的配置内容: \(jsonString)")
                
                // 保存到 UD（保存解密后的 JSON 字符串）
                UserDefaults.standard.set(jsonString, forKey: self?.configKey ?? "GVHostConfig")
                
                GVLogger.log("HostConfig", "✅ Git 更新成功，配置已保存到 UserDefaults")
                continuation.resume(returning: true)
            }
            task.resume()
        }
    }
    
    // MARK: - 域名提取方法
    
    /// 获取 connReport URL
    func connReport() -> String? {
        guard let config = config(),
              let apiDict = config["api"] as? [String: Any],
              let connReport = apiDict["connreport"] as? String else {
            return nil
        }
        return connReport
    }
    
    /// 获取 genReport URL
    func genReport() -> String? {
        guard let config = config(),
              let apiDict = config["api"] as? [String: Any],
              let genReport = apiDict["greport"] as? String else {
            return nil
        }
        return genReport
    }
    
    /// 获取 host 列表
    func hostList() -> [String]? {
        guard let config = config(),
              let apiDict = config["api"] as? [String: Any],
              let hosts = apiDict["host"] as? [String] else {
            return nil
        }
        return hosts
    }
}

