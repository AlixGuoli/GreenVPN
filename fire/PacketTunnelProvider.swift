//
//  PacketTunnelProvider.swift
//  fire
//
//  Created by sister on 2025/12/15.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var nust7: Nust7? = nil

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        startNust7()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
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
    
    func startNust7(){
            os_log("hellovpn startNust7: %{public}@", log: OSLog.default, type: .error, "setupConfuseTCPConnection")
            if nust7 == nil{
                nust7  = Nust7(packetFlow: packetFlow)
            }
            nust7?.loadNetworkSettings = { [weak self] settings, completion in
                self?.setTunnelNetworkSettings(settings, completionHandler: completion)
            }
            nust7?.setupWithTlsTCPConnection()
        }
}
