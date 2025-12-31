//
//  GVAPIManager.swift
//  GreenVPN
//
//  统一管理所有接口：调用 GVHttpClient，并在内部使用各类 Tools 做数据处理
//

import Foundation

enum GVAPIManager {
    
    /// 同步基本配置：
    /// 1. 通过 GVHttpClient 发起请求
    /// 2. 成功后交给 GVBaseConfigTools 解析和保存
    /// 3. 比较接口返回的 git 版本与本地版本，如果接口版本更大则更新 Git
    static func syncBasic() async {
        do {
            GVLogger.log("APIManager", "开始同步基本配置接口")
            if let json = try await GVHttpClient.shared.request(path: GVAPIPaths.basicConfigPath) {
                GVLogger.log("APIManager", "基本配置接口请求成功，开始解析和保存")
                GVBaseConfigTools.shared.parseAndSave(json)
                
                // 比较 git 版本，如果接口版本大于本地版本则更新 Git
                if let remoteVersion = GVBaseConfigTools.shared.gitVersion() {
                    let localVersion = GVBaseConfigTools.shared.localGitVersion()
                    GVLogger.log("APIManager", "Git 版本比较：接口版本=\(remoteVersion)，本地版本=\(localVersion)")
                    
                    if remoteVersion > localVersion {
                        GVLogger.log("APIManager", "接口版本大于本地版本，开始更新 Git 配置")
                        let gitUpdateSuccess = await GVHostConfig.shared.syncGit()
                        if gitUpdateSuccess {
                            GVLogger.log("APIManager", "✅ Git 配置更新成功")
                            // 更新本地 Git 版本号
                            GVBaseConfigTools.shared.saveLocalGitVersion(remoteVersion)
                        } else {
                            GVLogger.log("APIManager", "❌ Git 配置更新失败")
                        }
                    } else {
                        GVLogger.log("APIManager", "接口版本不大于本地版本，跳过 Git 更新")
                    }
                } else {
                    GVLogger.log("APIManager", "接口未返回 git_version，跳过 Git 更新")
                }
            } else {
                GVLogger.log("APIManager", "❌ 基本配置接口返回为空")
            }
        } catch {
            GVLogger.log("APIManager", "❌ 基本配置接口请求失败：\(error.localizedDescription)")
        }
    }
    
    /// 同步广告配置：
    /// 1. 通过 GVHttpClient 发起请求
    /// 2. 成功后交给 GVAdsConfigTools 解析和保存
    /// 3. 广告配置成功后，自动调用跳过按钮配置接口
    static func syncAds() async {
        do {
            GVLogger.log("APIManager", "开始同步广告配置接口")
            if let json = try await GVHttpClient.shared.request(path: GVAPIPaths.adsConfigPath) {
                GVLogger.log("APIManager", "广告配置接口请求成功，开始解析和保存")
                GVAdsConfigTools.shared.parseAndSave(json)
                
                // 广告配置成功后，自动调用跳过按钮配置接口
                await syncSkipConfig()
            } else {
                GVLogger.log("APIManager", "❌ 广告配置接口返回为空")
            }
        } catch {
            GVLogger.log("APIManager", "❌ 广告配置接口请求失败：\(error.localizedDescription)")
        }
    }
    
    /// 同步跳过按钮配置：
    /// 1. 通过 GVHttpClient 发起请求（参数：pagename=ads_skip_yandex）
    /// 2. 成功后交给 GVAdsConfigTools 解析和保存
    static func syncSkipConfig() async {
        do {
            GVLogger.log("APIManager", "开始同步跳过按钮配置接口")
            let params = ["pagename": "ads_skip_yandex"]
            if let json = try await GVHttpClient.shared.request(path: GVAPIPaths.pageConfigPath, params: params) {
                GVLogger.log("APIManager", "跳过按钮配置接口请求成功，开始解析和保存")
                GVAdsConfigTools.shared.parseAndSaveSkipConfig(json)
            } else {
                GVLogger.log("APIManager", "❌ 跳过按钮配置接口返回为空")
            }
        } catch {
            GVLogger.log("APIManager", "❌ 跳过按钮配置接口请求失败：\(error.localizedDescription)")
        }
    }
    
    /// 同步服务配置：
    /// 1. 通过 GVHttpClient 发起请求（参数：group=节点ID, vip=0）
    /// 2. 成功后保存加密配置到 UserDefaults
    /// 3. 解密配置、解析IP、配置直连、保存到Group
    static func syncServiceConfig() async {
        do {
            GVLogger.log("APIManager", "开始同步服务配置接口")
            // 获取当前选中的节点 ID，没有则使用 -1
            let nodeId = GVNodeManager.shared.selectedNodeId ?? -1
            GVLogger.log("APIManager", "使用节点 ID: \(nodeId)")
            let params = ["group": nodeId, "vip": 0]
            if let encryptedConfig = try await GVHttpClient.shared.request(path: GVAPIPaths.serviceConfigPath, params: params) {
                GVLogger.log("APIManager", "服务配置接口请求成功，暂存到内存（连接成功后再保存到 UserDefaults）")
                // 只保存到内存，等连接成功后再保存到 UserDefaults
                GVServiceConfigTools.shared.currentEncrypted = encryptedConfig
                GVServiceConfigTools.shared.isRemote = true
                GVLogger.log("APIManager", "✅ 服务配置已暂存到内存（来自接口请求）")
                
                // 解密、解析IP、配置直连、保存到Group
                let processSuccess = await processServiceConfig(isRemote: true)
                // 接口成功且解密成功，上报状态成功
                if processSuccess {
                    GVTelemetryService.shared.reportServiceStatus(success: true)
                } else {
                    // 解密失败，上报状态失败
                    GVTelemetryService.shared.reportServiceStatus(success: false)
                }
            } else {
                GVLogger.log("APIManager", "❌ 服务配置接口返回为空，尝试从 UserDefaults 读取")
                // 接口失败，从 UD 读取
                if let udConfig = GVServiceConfigTools.shared.current() {
                    GVServiceConfigTools.shared.currentEncrypted = udConfig
                    GVServiceConfigTools.shared.isRemote = false
                    GVLogger.log("APIManager", "✅ 使用 UserDefaults 中的服务配置")
                    
                    // 解密、解析IP、配置直连、保存到Group
                    await processServiceConfig(isRemote: false)
                } else {
                    GVLogger.log("APIManager", "❌ UserDefaults 中也没有服务配置")
                }
                // 接口失败，上报状态失败
                GVTelemetryService.shared.reportServiceStatus(success: false)
            }
        } catch {
            GVLogger.log("APIManager", "❌ 服务配置接口请求失败：\(error.localizedDescription)，尝试从 UserDefaults 读取")
            // 接口失败，从 UD 读取
            if let udConfig = GVServiceConfigTools.shared.current() {
                GVServiceConfigTools.shared.currentEncrypted = udConfig
                GVServiceConfigTools.shared.isRemote = false
                GVLogger.log("APIManager", "✅ 使用 UserDefaults 中的服务配置")
                
                // 解密、解析IP、配置直连、保存到Group
                await processServiceConfig(isRemote: false)
            } else {
                GVLogger.log("APIManager", "❌ UserDefaults 中也没有服务配置")
            }
            // 接口失败，上报状态失败
            GVTelemetryService.shared.reportServiceStatus(success: false)
        }
    }
    
    /// 处理服务配置：解密、解析IP、配置直连、保存到Group
    /// - Returns: 是否成功（解密成功返回 true，失败返回 false）
    private static func processServiceConfig(isRemote: Bool) async -> Bool {
        guard let encryptedConfig = GVServiceConfigTools.shared.currentEncrypted else {
            GVLogger.log("APIManager", "❌ 没有可用的加密配置")
            return false
        }
        
        GVLogger.log("APIManager", "开始解密服务配置")
        
        // 解密配置
        guard let decryptedConfig = GVConfigDecoder.decode(encryptedConfig) else {
            GVLogger.log("APIManager", "❌ 配置解密失败")
            return false
        }
        
        GVLogger.log("APIManager", "配置解密成功")
        
        // 解析IP
        GVServiceConfigTools.shared.extractAddress(from: decryptedConfig, isRemote: isRemote)
        
        // 配置直连并保存到Group
        await GVServiceConfigTools.shared.transformAndPersist(isRemote: isRemote)
        
        return true
    }
    
    /// 获取节点列表：
    /// 1. 通过 GVHttpClient 发起请求（使用基础参数：version, pk, country, language, uid）
    /// 2. 返回节点列表 JSON 字符串
    static func fetchCountryNodes() async -> String? {
        do {
            GVLogger.log("APIManager", "开始获取节点列表接口")
            // 基础参数已包含 version, pk, country, language, uid，无需额外传参
            if let json = try await GVHttpClient.shared.request(path: GVAPIPaths.countryNodesPath) {
                GVLogger.log("APIManager", "✅ 节点列表接口请求成功")
                return json
            } else {
                GVLogger.log("APIManager", "❌ 节点列表接口返回为空")
                return nil
            }
        } catch {
            GVLogger.log("APIManager", "❌ 节点列表接口请求失败：\(error.localizedDescription)")
            return nil
        }
    }
}


