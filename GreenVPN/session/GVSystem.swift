//
//  VPNManager.swift
//  GreenVPN
//
//  Created by sister on 2025/12/16.
//

import Foundation
import NetworkExtension

class GVSystem {
    
    public var driver = NEVPNManager.shared()
  
    private static var s: GVSystem = {
        return GVSystem()
    }()

    public class func shared() -> GVSystem {
        return s
    }
  
    public init() {}
    
    /// 加载所有配置；若不存在则创建（会触发系统 VPN 权限弹窗）
    public func prepareEngine(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences() { managers, error in
            guard let managers = managers, error == nil else {
                completion(error)
                return
            }
            
            if managers.count == 0 {
                let providerManager = NETunnelProviderManager()
                providerManager.protocolConfiguration = NETunnelProviderProtocol()
                providerManager.localizedDescription = "Cool VPN"
                providerManager.protocolConfiguration?.serverAddress = "Cool VPN"
                providerManager.saveToPreferences { error in
                    guard error == nil else {
                        completion(error)
                        return
                    }
                    providerManager.loadFromPreferences { error in
                        self.driver = providerManager
                        completion(nil)
                    }
                }
            } else {
                self.driver = managers[0]
                completion(nil)
            }
        }
    }
    
    /// 仅恢复已存在的 VPN 配置，不会创建新的配置（避免首次启动时弹出权限）
    /// - Parameter completion: hasConfig 表示是否存在已保存的配置
    public func restoreEngineIfAvailable(completion: @escaping (_ hasConfig: Bool, _ error: Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let managers = managers, let first = managers.first else {
                // 没有任何配置：不创建，静默返回
                completion(false, nil)
                return
            }
            
            self.driver = first
            completion(true, nil)
        }
    }
    
    public func applyEngineConfig(completion: @escaping (Error?) -> Void) {
        GVLogger.log("VPNManager", "开始启用并保存 VPN 配置")
        driver.isEnabled = true
        driver.saveToPreferences { error in
            guard error == nil else {
                completion(error)
                return
            }
            self.driver.loadFromPreferences { error in
                completion(error)
            }
        }
    }
    
    public func startEngine(completion: @escaping (Error?) -> Void) {
        if self.driver.connection.status == .disconnected || self.driver.connection.status == .invalid {
            do {
                GVLogger.log("VPNManager", "尝试启动 VPN 隧道连接")
                try self.driver.connection.startVPNTunnel()
            } catch {
                completion(error)
            }
        }
    }
    
    public func stopEngine(completion: @escaping (Error?) -> Void) {
        if self.driver.connection.status == .connected{
            self.driver.connection.stopVPNTunnel()
        }
    }
    
}
