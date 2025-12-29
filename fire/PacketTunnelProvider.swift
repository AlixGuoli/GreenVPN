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
    
    private var conn: TConn? = nil
    
    private static let errorDomain = "com.green.fire.vpn.birds.fly"
    private static let timeoutErrorKey = "timeout"
    private static let timeoutErrorMsg = "timeout error"
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        //startRelayAgent()
        os_log("[PacketTunnelProvider] Starting tunnel", log: OSLog.default, type: .error)
        if !checkTimeWindow() {
            let error = NSError(domain: Self.errorDomain, code: 1, userInfo: [Self.timeoutErrorKey: Self.timeoutErrorMsg])
            self.cancelTunnelWithError(error)
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "checkTimeWindow false")
            return
        }
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "checkTimeWindow true")
        startConn()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        //relayAgent?.stopPacketTunnel()
        conn?.haltNet()
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
    private func checkTimeWindow() -> Bool {
        if let userDefaults = UserDefaults(suiteName: GVSharedStorage.suiteIdentifier) {
            if let startTime = userDefaults.object(forKey: GVSharedStorage.timestampKey) as? Date {
                let now = Date()
                let delta = now.timeIntervalSince(startTime)
                if delta < 10 {
                    os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "PacketTunnelProvider less 10s")
                    //os_log("PacketTunnelProvider less 10s.", log: OSLog.default, type: .error)
                    return true
                }
            }
        }
        return false
    }
    
    private func startConn() {
        if conn == nil {
            conn = TConn()
        }
        
        conn?.applyNetworkSettings = { [weak self] cfg, done in
            self?.setTunnelNetworkSettings(cfg, completionHandler: done)
        }
        
        Task {
            do {
                os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "bootNet")
                try await conn?.bootNet()
            } catch {
                os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "bootNet error")
            }
        }
    }
}
