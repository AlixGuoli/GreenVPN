//
//  GVHttpClient.swift
//  GreenVPN
//
//  统一请求执行：负责 host 轮询、重试、Git 更新
//

import Foundation
import Alamofire

/// HTTP 请求客户端（单例）
final class GVHttpClient {
    
    static let shared = GVHttpClient()
    
    private let hostConfig = GVHostConfig.shared
    
    private init() {}
    
    /// 统一请求入口
    /// - Parameters:
    ///   - path: 接口路径（如 "/game/setting/sync"）
    ///   - params: 额外参数（会自动合并基础参数）
    /// - Returns: 响应 JSON 字符串，失败返回 nil
    func request(path: String, params: [String: Any] = [:]) async throws -> String? {
        // 1. 获取当前配置
        guard let config = hostConfig.config(),
              let apiDict = config["api"] as? [String: Any],
              let hosts = apiDict["host"] as? [String],
              !hosts.isEmpty else {
            GVLogger.log("HttpClient", "❌ 请求失败：配置或 host 数组为空")
            throw NSError(domain: "GVHttpClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "配置或 host 数组为空"])
        }
        
        // 2. 合并参数：基础参数 + 业务参数
        var allParams = GVBaseParameters.parameters()
        allParams.merge(params) { (_, new) in new }
        
        GVLogger.log("HttpClient", "开始请求接口：\(path)")
        
        // 3. 尝试请求（host 轮询）
        if let response = await tryRequestWithHosts(hosts: hosts, path: path, params: allParams) {
            return response
        }
        
        // 4. 所有 host 都失败，更新 Git 配置
        GVLogger.log("HttpClient", "所有 host 都失败，开始通过 Git 更新配置")
        let gitSuccess = await hostConfig.syncGit()
        
        if !gitSuccess {
            GVLogger.log("HttpClient", "❌ Git 更新失败，请求终止")
            return nil
        }
        
        // 5. Git 更新成功，重新获取配置并重试一次
        guard let newConfig = hostConfig.config(),
              let newApiDict = newConfig["api"] as? [String: Any],
              let newHosts = newApiDict["host"] as? [String],
              !newHosts.isEmpty else {
            GVLogger.log("HttpClient", "❌ Git 更新后配置仍无效")
            return nil
        }
        
        GVLogger.log("HttpClient", "✅ Git 更新成功，使用新配置重试请求")
        return await tryRequestWithHosts(hosts: newHosts, path: path, params: allParams)
    }
    
    /// 轮询 host 数组发起请求
    private func tryRequestWithHosts(hosts: [String], path: String, params: [String: Any], index: Int = 0) async -> String? {
        guard index < hosts.count else {
            GVLogger.log("HttpClient", "所有 host 都失败")
            return nil
        }
        
        let host = hosts[index]
        let baseURL = host.hasSuffix("/") ? String(host.dropLast()) : host
        let apiPath = path.hasPrefix("/") ? path : "/\(path)"
        let fullURL = buildFullURL(base: "\(baseURL)\(apiPath)", params: params)
        
        GVLogger.log("HttpClient", "准备请求域名：\(host)")
        GVLogger.log("HttpClient", "完整 URL：\(fullURL)")
        
        let response = await executeRequest(url: fullURL, hostIndex: index + 1, totalHosts: hosts.count)
        
        if let response = response {
            return response
        } else {
            // 尝试下一个 host
            return await tryRequestWithHosts(hosts: hosts, path: path, params: params, index: index + 1)
        }
    }
    
    /// 执行单个 HTTP 请求
    private func executeRequest(url: String, hostIndex: Int, totalHosts: Int) async -> String? {
        guard let urlObj = URL(string: url) else {
            GVLogger.log("HttpClient", "❌ URL 格式错误：\(url)")
            return nil
        }
        
        var request = URLRequest(url: urlObj)
        request.timeoutInterval = 5.0
        
        var isCompleted = false
        
        // 启动倒计时任务
        DispatchQueue.global().async {
            for i in (1...5).reversed() {
                if isCompleted { break }
                GVLogger.log("HttpClient", "接口请求倒计时：\(i) 秒")
                Thread.sleep(forTimeInterval: 1.0)
            }
            if !isCompleted {
                GVLogger.log("HttpClient", "请求超时（5秒）")
            }
        }
        
        return await withCheckedContinuation { continuation in
            AF.request(request)
                .responseData { response in
                    isCompleted = true
                    
                    // 检查 HTTP 状态码
                    if let httpResponse = response.response {
                        let statusCode = httpResponse.statusCode
                        GVLogger.log("HttpClient", "HTTP 状态码：\(statusCode)")
                        
                        if statusCode >= 200 && statusCode < 300 {
                            // 状态码正确
                            if let data = response.data,
                               let result = String(data: data, encoding: .utf8) {
                                GVLogger.log("HttpClient", "✅ 请求成功，域名：\(urlObj.host ?? "unknown")")
                                // 打印响应内容（前500字符）
                                let preview = result.count > 500 ? String(result.prefix(500)) + "..." : result
                                GVLogger.log("HttpClient", "响应内容：\(preview)")
                                continuation.resume(returning: result)
                                return
                            } else {
                                GVLogger.log("HttpClient", "❌ 响应数据解析失败")
                                continuation.resume(returning: nil)
                                return
                            }
                        } else {
                            GVLogger.log("HttpClient", "❌ HTTP 状态码错误：\(statusCode)")
                            continuation.resume(returning: nil)
                            return
                        }
                    }
                    
                    // 检查是否有错误
                    if let error = response.error {
                        var errorType = "未知错误"
                        if let afError = error.asAFError {
                            switch afError {
                            case .sessionTaskFailed(let sessionError):
                                if let urlError = sessionError as? URLError {
                                    switch urlError.code {
                                    case .timedOut:
                                        errorType = "超时失败"
                                    case .notConnectedToInternet, .networkConnectionLost:
                                        errorType = "网络连接失败"
                                    default:
                                        errorType = "网络错误: \(urlError.localizedDescription)"
                                    }
                                } else {
                                    errorType = "会话任务失败: \(sessionError.localizedDescription)"
                                }
                            case .responseValidationFailed(let reason):
                                if case .unacceptableStatusCode(let code) = reason {
                                    errorType = "状态码错误: \(code)"
                                } else {
                                    errorType = "响应验证失败: \(reason)"
                                }
                            default:
                                errorType = "请求失败: \(afError.localizedDescription)"
                            }
                        } else {
                            errorType = "请求失败: \(error.localizedDescription)"
                        }
                        GVLogger.log("HttpClient", "❌ 请求失败，域名：\(urlObj.host ?? "unknown")，失败原因：\(errorType)")
                    } else {
                        GVLogger.log("HttpClient", "❌ 响应为空，没有 HTTP 响应")
                    }
                    
                    continuation.resume(returning: nil)
                }
        }
    }
    
    /// 构建完整 URL（包含参数）
    private func buildFullURL(base: String, params: [String: Any]) -> String {
        guard !params.isEmpty else {
            return base
        }
        
        var components = URLComponents(string: base)
        components?.queryItems = params.map { key, value in
            URLQueryItem(name: key, value: String(describing: value))
        }
        return components?.url?.absoluteString ?? base
    }
}

