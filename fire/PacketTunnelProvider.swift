//
//  PacketTunnelProvider.swift
//  fire
//
//  Created by sister on 2025/12/15.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var relayAgent: StreamRelayAgent? = nil
    
    private static let errorNamespace = "com.green.fire.vpn.birds.fly"
    private static let timeoutField = "timeout"
    private static let timeoutText = "timeout error"
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "Starting tunnel")
        startRelayAgent()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        relayAgent?.stopPacketTunnel()
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
    
    func startRelayAgent(){
        os_log("hellovpn startNust7: %{public}@", log: OSLog.default, type: .error, "setupConfuseTCPConnection")
        if relayAgent == nil{
            relayAgent  = StreamRelayAgent(packetFlow: packetFlow)
        }
        relayAgent?.applyNetworkSettings = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        relayAgent?.startLinkChannel()
    }
    
}
