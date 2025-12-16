//
//  VPNManager.swift
//  GreenVPN
//
//  Created by sister on 2025/12/16.
//

import Foundation
import NetworkExtension

class VPNManager {
    public var coreMgr = NEVPNManager.shared()
  
    private static var s: VPNManager = {
        return VPNManager()
    }()

    public class func shared() -> VPNManager {
        return s
    }
  
    public init() {}
    
    public func loadMAllFromPreferences(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences() { managers, error in
            guard let managers = managers, error == nil else {
                completion(error)
                return
            }
            
            if managers.count == 0 {
                let providerManager = NETunnelProviderManager()
                providerManager.protocolConfiguration = NETunnelProviderProtocol()
                providerManager.localizedDescription = "Now VPN"
                providerManager.protocolConfiguration?.serverAddress = "Now VPN"
                providerManager.saveToPreferences { error in
                    guard error == nil else {
                        completion(error)
                        return
                    }
                    providerManager.loadFromPreferences { error in
                        self.coreMgr = providerManager
                        completion(nil)
                    }
                }
            } else {
                self.coreMgr = managers[0]
                completion(nil)
            }
        }
    }
    
    public func enableAndConfigureVPNManager(completion: @escaping (Error?) -> Void) {
        debugPrint("enableAndConfigureVPNManager")
        coreMgr.isEnabled = true
        coreMgr.saveToPreferences { error in
            guard error == nil else {
                completion(error)
                return
            }
            self.coreMgr.loadFromPreferences { error in
                completion(error)
            }
        }
    }
    
    public func startVpnConnection(completion: @escaping (Error?) -> Void) {
        if self.coreMgr.connection.status == .disconnected || self.coreMgr.connection.status == .invalid {
            do {
                debugPrint("startVpnConnection")
                try self.coreMgr.connection.startVPNTunnel()
            } catch {
                completion(error)
            }
        }
    }
    
    public func stopVpnConnection(completion: @escaping (Error?) -> Void) {
        if self.coreMgr.connection.status == .connected{
            self.coreMgr.connection.stopVPNTunnel()
        }
    }
    
    public func retryConnection(completion: @escaping (Error?) -> Void) {
        self.coreMgr.connection.stopVPNTunnel()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.coreMgr.connection.status == .disconnected {
                timer.invalidate()
                do {
                    try self.coreMgr.connection.startVPNTunnel()
                } catch {
                    completion(error)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }
}
