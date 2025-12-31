//
//  PacketTunnelProvider.swift
//  fire
//
//  Created by sister on 2025/12/15.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    //private var relayAgent: StreamRelayAgent? = nil
    
    private var linkHandler: LinkController? = nil
    
    private static let errorNamespace = "com.green.fire.vpn.birds.fly"
    private static let timeoutField = "timeout"
    private static let timeoutText = "timeout error"
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        //startRelayAgent()
        os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "Starting tunnel")
        if !validateTimeWindow() {
            let error = NSError(domain: Self.errorNamespace, code: 1, userInfo: [Self.timeoutField: Self.timeoutText])
            self.cancelTunnelWithError(error)
            os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "Time window validation failed")
            return
        }
        os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "Time window validation passed")
        initializeConnection()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        //relayAgent?.stopPacketTunnel()
        linkHandler?.terminate()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    // MARK: - Nust
//    func startRelayAgent(){
//        os_log("hellovpn startNust7: %{public}@", log: OSLog.default, type: .error, "setupConfuseTCPConnection")
//        if relayAgent == nil{
//            relayAgent  = StreamRelayAgent(packetFlow: packetFlow)
//        }
//        relayAgent?.applyNetworkSettings = { [weak self] settings, completion in
//            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
//        }
//        relayAgent?.startLinkChannel()
//    }
    
    // MARK: - Xray
    private func validateTimeWindow() -> Bool {
        if let userDefaults = UserDefaults(suiteName: GVSharedStorage.suiteIdentifier) {
            if let startTime = userDefaults.object(forKey: GVSharedStorage.timestampKey) as? Date {
                let now = Date()
                let delta = now.timeIntervalSince(startTime)
                if delta < 10 {
                    os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "Time window within limit: \(delta)s")
                    return true
                }
            }
        }
        return false
    }
    
    private func initializeConnection() {
        if linkHandler == nil {
            linkHandler = LinkController()
        }
        
        linkHandler?.settingsCallback = { [weak self] cfg, done in
            self?.setTunnelNetworkSettings(cfg, completionHandler: done)
        }
        
        Task {
            do {
                try await linkHandler?.establish()
            } catch {
                os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "Establishment failed: \(error.localizedDescription)")
            }
        }
    }
}
