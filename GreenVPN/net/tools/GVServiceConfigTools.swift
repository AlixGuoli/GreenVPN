//
//  GVServiceConfigTools.swift
//  GreenVPN
//
//  服务配置接口的数据管理：解析和存储
//

import Foundation

/// 服务配置数据管理工具（单例）
final class GVServiceConfigTools {
    
    static let shared = GVServiceConfigTools()
    
    private let serviceConfigKey = "GVServiceConfig"
    
    /// 当前使用的加密配置（可能是接口获取的，也可能是 UD 读取的）
    var currentEncrypted: String?
    
    /// 是否来自远程接口（true=接口获取，false=UD读取）
    var isRemote: Bool = true
    
    /// 解析到的IP地址
    var ipService: String?
    
    private init() {}
    
    /// 保存加密配置到 UserDefaults
    /// - Parameter encryptedString: 加密的配置字符串
    func save(_ encryptedString: String) {
        UserDefaults.standard.set(encryptedString, forKey: serviceConfigKey)
        UserDefaults.standard.synchronize()
        
        GVLogger.log("ServiceConfigTools", "加密配置已保存到 UserDefaults")
    }
    
    /// 从 UserDefaults 读取加密配置
    func current() -> String? {
        return UserDefaults.standard.string(forKey: serviceConfigKey)
    }
    
    // MARK: - IP 解析
    
    /// 解析服务配置中的 IP 地址
    /// - Parameters:
    ///   - input: 解密后的配置 JSON 字符串
    ///   - isRemote: IP 是否来自远程接口（true=不加前缀，false=加前缀"f"）
    func extractAddress(from input: String?, isRemote: Bool) {
        guard let data = input?.data(using: .utf8) else {
            GVLogger.log("ServiceConfigTools", "❌ 配置数据为空")
            return
        }
        
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
                  let bounds = parsed["outbounds"] as? [[String: Any]] else {
                GVLogger.log("ServiceConfigTools", "❌ 配置格式错误：未找到 outbounds")
                return
            }
            
            for bound in bounds {
                if let config = bound["settings"] as? [String: Any],
                   let nodes = config["vnext"] as? [[String: Any]] {
                    for node in nodes {
                        if let ip = node["address"] as? String {
                            let finalIp = isRemote ? ip : "f\(ip)"
                            self.ipService = finalIp
                            if ip != finalIp {
                                GVLogger.log("ServiceConfigTools", "解析 IP：\(ip) -> \(finalIp)")
                            } else {
                                GVLogger.log("ServiceConfigTools", "解析 IP：\(ip)（来源：\(isRemote ? "接口" : "缓存")）")
                            }
                            return
                        }
                    }
                }
            }
            
            GVLogger.log("ServiceConfigTools", "❌ 未找到 IP 地址")
        } catch {
            GVLogger.log("ServiceConfigTools", "❌ 解析网络配置失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 配置处理
    
    /// 处理并保存服务配置到 Group UserDefaults
    /// - Parameter isRemote: IP 是否来自远程接口（true=不加前缀，false=加前缀"f"）
    func transformAndPersist(isRemote: Bool) async {
        guard let encryptedConfig = currentEncrypted else {
            GVLogger.log("ServiceConfigTools", "❌ 没有可用的加密配置")
            return
        }
        
        GVLogger.log("ServiceConfigTools", "开始处理连接配置")
        
        // 解密配置
        guard let decryptedConfig = GVConfigDecoder.decode(encryptedConfig) else {
            GVLogger.log("ServiceConfigTools", "❌ 配置解密失败")
            return
        }
        
        // 处理配置管道
        guard let processedConfig = applyModifications(decryptedConfig) else {
            GVLogger.log("ServiceConfigTools", "❌ 配置处理失败")
            return
        }
        
        // 保存到 Group UserDefaults
        await persistToGroup(processedConfig)
        
        GVLogger.log("ServiceConfigTools", "✅ 连接配置处理完成")
    }
    
    // MARK: - 配置处理管道
    
    private func applyModifications(_ jsonString: String) -> String? {
        // 1. 解析配置
        guard let config = deserializeConfig(jsonString) else {
            GVLogger.log("ServiceConfigTools", "❌ 配置解析失败")
            return nil
        }
        
        // 2. 更新 inbound 配置
        let inboundUpdated = modifyInbound(config)
        
        // 3. 增强路由配置
        let routingEnhanced = enrichRouting(inboundUpdated)
        
        // 4. 序列化配置
        guard let finalConfig = encodeConfig(routingEnhanced) else {
            GVLogger.log("ServiceConfigTools", "❌ 配置序列化失败")
            return nil
        }
        
        return finalConfig
    }
    
    // MARK: - 配置解析和序列化
    
    private func deserializeConfig(_ jsonString: String) -> [String: Any]? {
        guard let jsonData = jsonString.data(using: .utf8),
              let config = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }
        return config
    }
    
    private func encodeConfig(_ config: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    // MARK: - 入站配置更新
    
    private func modifyInbound(_ config: [String: Any]) -> [String: Any] {
        var updatedConfig = config
        guard var inbounds = updatedConfig["inbounds"] as? [[String: Any]],
              !inbounds.isEmpty else {
            GVLogger.log("ServiceConfigTools", "未找到 inbounds 配置")
            return updatedConfig
        }
        
        var firstInbound = inbounds[0]
        firstInbound["listen"] = "[::1]"
        firstInbound["port"] = "8080"
        inbounds[0] = firstInbound
        updatedConfig["inbounds"] = inbounds
        
        return updatedConfig
    }
    
    // MARK: - 路由配置增强
    
    private func enrichRouting(_ config: [String: Any]) -> [String: Any] {
        let bypassDomains = gatherDirectDomains()
        let routingRules = buildDirectRules(bypassDomains)
        return injectRoutingRules(config, rules: routingRules)
    }
    
    private func gatherDirectDomains() -> [String] {
        var domains: [String] = []
        
        // 固定域名
        let fixedDomains = ["yastatic", "yandex", "gameanalytics", "mradx.net", "target.my.com", "vk.ru", "vk.me", "vk.com", "mail.ru"]
        domains.append(contentsOf: fixedDomains)
        let fixedList = fixedDomains.joined(separator: ", ")
        GVLogger.log("ServiceConfigTools", "固定域名：\(fixedList)")
        
        // 动态域名
        let hostConfig = GVHostConfig.shared
        let dynamicDomains = resolveHostDomains(from: hostConfig)
        domains.append(contentsOf: dynamicDomains)
        
        if !dynamicDomains.isEmpty {
            let domainList = dynamicDomains.joined(separator: ", ")
            GVLogger.log("ServiceConfigTools", "动态域名：\(domainList)")
        }
        
        return domains
    }
    
    private func resolveHostDomains(from hostConfig: GVHostConfig) -> [String] {
        var domains: [String] = []
        
        // 获取 connReport 域名
        if let connReport = hostConfig.connReport(),
           let connHost = URL(string: connReport)?.host {
            domains.append(connHost)
        }
        
        // 获取 genReport 域名
        if let genReport = hostConfig.genReport(),
           let genHost = URL(string: genReport)?.host {
            domains.append(genHost)
        }
        
        // 获取 hostList 域名
        if let hosts = hostConfig.hostList() {
            let hostDomains = hosts.compactMap { URL(string: $0)?.host }
            domains.append(contentsOf: hostDomains)
        }
        
        return domains
    }
    
    private func buildDirectRules(_ domains: [String]) -> [[String: Any]] {
        var rules: [[String: Any]] = []
        
        // 固定规则：raw.githubusercontent.com 单独处理
        rules.append([
            "type": "field",
            "domain": ["raw.githubusercontent.com"],
            "outboundTag": "direct"
        ])
        
        // 动态规则：其他域名
        if !domains.isEmpty {
            rules.append([
                "type": "field",
                "domain": domains,
                "outboundTag": "direct"
            ])
        }
        
        GVLogger.log("ServiceConfigTools", "构建直连规则：\(rules.count) 条")
        return rules
    }
    
    private func injectRoutingRules(_ config: [String: Any], rules: [[String: Any]]) -> [String: Any] {
        var mergedConfig = config
        
        if mergedConfig["routing"] == nil {
            mergedConfig["routing"] = [
                "domainStrategy": "AsIs",
                "rules": rules
            ]
        } else if var routing = mergedConfig["routing"] as? [String: Any] {
            routing["rules"] = rules
            mergedConfig["routing"] = routing
        }
        
        return mergedConfig
    }
    
    // MARK: - 配置持久化
    
    private func persistToGroup(_ config: String) async {
        guard let groupDefaults = UserDefaults(suiteName: GVSharedStorage.suiteIdentifier) else {
            GVLogger.log("ServiceConfigTools", "❌ 无法创建 Group UserDefaults")
            return
        }
        
        let saveDate = Date()
        groupDefaults.set(saveDate, forKey: GVSharedStorage.timestampKey)
        groupDefaults.set(config, forKey: GVSharedStorage.contentKey)
        groupDefaults.synchronize()
        
        GVLogger.log("ServiceConfigTools", "✅ 配置已保存到 Group UserDefaults")
        GVLogger.log("ServiceConfigTools", "配置内容: \(config)")
    }
}

