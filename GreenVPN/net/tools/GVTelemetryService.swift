//
//  GVTelemetryService.swift
//  GreenVPN
//
//  事件上报服务（连接事件、广告事件、状态上报）
//

import Foundation

/// 事件上报服务（单例）
final class GVTelemetryService {
    
    static let shared = GVTelemetryService()
    private init() {}
    
    // MARK: - 配置常量
    
    private static let deviceType = "iPhone"
    
    // MARK: - 事件类型常量（与后台定义一致，不能改）
    
    static let kEventConnectStart = "start_connect"
    static let kEventConnectFailed = "connect_failed"
    static let kEventConnectSuccess = "connect_success"
    static let kEventDisconnect = "disconnect"
    static let kEventAdRequest = "start_get_ad"
    static let kEventAdReady = "get_ad_success"
    static let kEventAdDisplay = "show_ad"
    
    // MARK: - 上报端点类型
    
    private enum EndpointType {
        case logReport      // 日志上报
        case statusReport   // 状态上报
    }
    
    // MARK: - 会话管理
    
    /// 当前会话ID（连接开始时生成，断开时清除）
    private var currentSessionId: String?
    
    /// 生成新的会话ID
    private func generateSessionId() -> String {
        return String(UUID().uuidString.prefix(8))
    }
    
    // MARK: - 公共接口：连接事件上报
    
    /// 上报连接事件
    /// - Parameters:
    ///   - eventKind: 事件类型（kEventConnectStart/kEventConnectFailed/kEventConnectSuccess/kEventDisconnect）
    ///   - ipAddress: IP地址（可选）
    ///   - sessionId: 会话ID（可选，不传则使用内部管理的）
    func reportConnectionEvent(eventKind: String, ipAddress: String? = nil, sessionId: String? = nil) {
        let message = buildConnectionEventMessage(eventKind: eventKind, ipAddress: ipAddress, sessionId: sessionId)
        guard let message = message else { return }
        submitEventMessage(message: message, eventKind: eventKind)
    }
    
    // MARK: - 公共接口：广告事件上报
    
    /// 上报广告事件
    /// - Parameters:
    ///   - eventKind: 事件类型（kEventAdRequest/kEventAdReady/kEventAdDisplay）
    ///   - adKey: 广告Key（可选）
    ///   - adMoment: 广告时刻（可选）
    func reportAdEvent(eventKind: String, adKey: String? = nil, adMoment: String? = nil) {
        let message = buildAdEventMessage(eventKind: eventKind, adKey: adKey, adMoment: adMoment)
        guard let message = message else { return }
        submitEventMessage(message: message, eventKind: eventKind)
    }
    
    // MARK: - 公共接口：状态上报
    
    /// 上报服务状态
    /// - Parameter success: 是否成功（true=0, false=1）
    func reportServiceStatus(success: Bool) {
        Task.detached {
            await self.executeStatusReport(success: success)
        }
    }
    
    // MARK: - 消息构建
    
    /// 构建连接事件消息
    private func buildConnectionEventMessage(eventKind: String, ipAddress: String?, sessionId: String?) -> String? {
        // 连接开始时生成并保存会话ID（必须在构建 identifier 之前）
        if eventKind == GVTelemetryService.kEventConnectStart && currentSessionId == nil {
            currentSessionId = generateSessionId()
        }
        
        let timestamp = generateTimeStamp()
        let sid = sessionId ?? currentSessionId ?? ""
        let identifier = "\(timestamp)-\(sid)"
        
        // 断开时清除会话ID
        if eventKind == GVTelemetryService.kEventDisconnect {
            currentSessionId = nil
        }
        
        switch eventKind {
        case GVTelemetryService.kEventConnectStart:
            return "\(GVTelemetryService.kEventConnectStart),\(identifier),0.0.0.0"
            
        case GVTelemetryService.kEventConnectFailed:
            return "\(GVTelemetryService.kEventConnectFailed),\(identifier),\(ipAddress ?? "0.0.0.0")"
            
        case GVTelemetryService.kEventConnectSuccess:
            return "\(GVTelemetryService.kEventConnectSuccess),0,\(identifier),\(ipAddress ?? "0.0.0.0")"
            
        case GVTelemetryService.kEventDisconnect:
            return "\(GVTelemetryService.kEventDisconnect),\(identifier),\(ipAddress ?? "0.0.0.0")"
            
        default:
            GVLogger.log("TelemetryService", "[连接事件] 未知类型: \(eventKind)")
            return nil
        }
    }
    
    /// 构建广告事件消息
    private func buildAdEventMessage(eventKind: String, adKey: String?, adMoment: String?) -> String? {
        let ipAddress = fetchCurrentIPAddress()
        
        switch eventKind {
        case GVTelemetryService.kEventAdRequest:
            return "\(GVTelemetryService.kEventAdRequest),\(adMoment ?? ""),\(ipAddress),ad"
            
        case GVTelemetryService.kEventAdReady:
            return "\(GVTelemetryService.kEventAdReady),\(adMoment ?? ""),\(ipAddress),ad,\(adKey ?? "")"
            
        case GVTelemetryService.kEventAdDisplay:
            return "\(GVTelemetryService.kEventAdDisplay),\(adMoment ?? ""),\(ipAddress),ad,\(adKey ?? "empty")"
            
        default:
            GVLogger.log("TelemetryService", "[广告事件] 未知类型: \(eventKind)")
            return nil
        }
    }
    
    // MARK: - 网络请求执行
    
    /// 提交事件消息（日志上报）
    private func submitEventMessage(message: String, eventKind: String) {
        Task.detached {
            await self.executeLogReport(message: message, eventKind: eventKind)
        }
    }
    
    /// 执行日志上报
    private func executeLogReport(message: String, eventKind: String) async {
        guard let endpoint = GVHostConfig.shared.connReport(),
              !endpoint.isEmpty else {
            GVLogger.log("TelemetryService", "[日志上报] ❌ 无上报端点")
            return
        }
        
        guard let url = buildEndpointURL(type: .logReport, baseURL: endpoint, message: message) else {
            GVLogger.log("TelemetryService", "[日志上报] ❌ URL构建失败")
            return
        }
        
        let requestIdentifier = String(UUID().uuidString.prefix(8))
        GVLogger.log("TelemetryService", "[日志上报] [\(requestIdentifier)] 开始 | 事件: \(eventKind) | URL: \(url)")
        await performNetworkRequest(urlString: url, requestType: "日志上报", requestIdentifier: requestIdentifier)
    }
    
    /// 执行状态上报
    private func executeStatusReport(success: Bool) async {
        guard let endpoint = GVHostConfig.shared.genReport() else {
            GVLogger.log("TelemetryService", "[状态上报] ❌ 无上报端点")
            return
        }
        
        let statusCode = success ? "0" : "1"
        guard let url = buildEndpointURL(type: .statusReport, baseURL: endpoint, status: statusCode) else {
            GVLogger.log("TelemetryService", "[状态上报] ❌ URL构建失败")
            return
        }
        
        let requestIdentifier = String(UUID().uuidString.prefix(8))
        GVLogger.log("TelemetryService", "[状态上报] [\(requestIdentifier)] 开始 | status: \(statusCode) | URL: \(url)")
        await performNetworkRequest(urlString: url, requestType: "状态上报", requestIdentifier: requestIdentifier)
    }
    
    // MARK: - URL构建
    
    /// 构建上报URL（统一入口）
    private func buildEndpointURL(type: EndpointType, baseURL: String, message: String? = nil, status: String? = nil) -> String? {
        let targetURL: String
        var queryItems: [URLQueryItem] = []
        let ctx = GVBaseParameters.parameters()
        
        switch type {
        case .logReport:
            targetURL = baseURL
            queryItems = [
                URLQueryItem(name: "imei", value: ctx["uid"] as? String ?? ""),
                URLQueryItem(name: "country", value: ctx["country"] as? String ?? ""),
                URLQueryItem(name: "lang", value: ctx["language"] as? String ?? ""),
                URLQueryItem(name: "mobile", value: GVTelemetryService.deviceType),
                URLQueryItem(name: "pk", value: ctx["pk"] as? String ?? ""),
                URLQueryItem(name: "version", value: ctx["version"] as? String ?? ""),
                URLQueryItem(name: "info", value: message ?? "")
            ]
            
        case .statusReport:
            targetURL = baseURL + "/report_total"
            queryItems = [
                URLQueryItem(name: "name", value: "getService"),
                URLQueryItem(name: "cty", value: ctx["country"] as? String ?? ""),
                URLQueryItem(name: "pk", value: ctx["pk"] as? String ?? ""),
                URLQueryItem(name: "v", value: ctx["version"] as? String ?? ""),
                URLQueryItem(name: "asn", value: "0"),
                URLQueryItem(name: "isf", value: status ?? ""),
                URLQueryItem(name: "cnt", value: "1")
            ]
        }
        
        guard var components = URLComponents(string: targetURL) else { return nil }
        components.queryItems = queryItems
        return components.url?.absoluteString
    }
    
    // MARK: - HTTP请求
    
    /// 执行网络请求
    private func performNetworkRequest(urlString: String, requestType: String, requestIdentifier: String) async {
        guard let url = URL(string: urlString) else {
            GVLogger.log("TelemetryService", "[\(requestType)] [\(requestIdentifier)] ❌ URL无效")
            return
        }
        
        let request = URLRequest(url: url)
        let startTime = Date()
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            let httpResponse = response as! HTTPURLResponse
            
            let statusCode = httpResponse.statusCode
            let durationStr = String(format: "%.2f", duration)
            
            if statusCode >= 200 && statusCode < 300 {
                GVLogger.log("TelemetryService", "[\(requestType)] [\(requestIdentifier)] ✅ 成功 | status: \(statusCode) | 耗时: \(durationStr)s | URL: \(url)")
            } else {
                GVLogger.log("TelemetryService", "[\(requestType)] [\(requestIdentifier)] ❌ 失败 | status: \(statusCode) | 耗时: \(durationStr)s | URL: \(url)")
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let durationStr = String(format: "%.2f", duration)
            GVLogger.log("TelemetryService", "[\(requestType)] [\(requestIdentifier)] ❌ 异常 | error: \(error.localizedDescription) | 耗时: \(durationStr)s | URL: \(url)")
        }
    }
    
    // MARK: - 工具方法
    
    /// 获取当前连接的IP
    private func fetchCurrentIPAddress() -> String {
        if let ip = GVServiceConfigTools.shared.ipService,
           !ip.isEmpty {
            return ip
        } else {
            return "local"
        }
    }
    
    /// 生成时间戳（格式：MMddHHmmss）
    private func generateTimeStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddHHmmss"
        return formatter.string(from: Date())
    }
    
    /// 生成随机ID（8位UUID前缀）
    static func generateRandomId() -> String {
        return String(UUID().uuidString.prefix(8))
    }
}

