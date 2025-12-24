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
    static func syncAds() async {
        do {
            GVLogger.log("APIManager", "开始同步广告配置接口")
            if let json = try await GVHttpClient.shared.request(path: GVAPIPaths.adsConfigPath) {
                GVLogger.log("APIManager", "广告配置接口请求成功，开始解析和保存")
                GVAdsConfigTools.shared.parseAndSave(json)
            } else {
                GVLogger.log("APIManager", "❌ 广告配置接口返回为空")
            }
        } catch {
            GVLogger.log("APIManager", "❌ 广告配置接口请求失败：\(error.localizedDescription)")
        }
    }
}


