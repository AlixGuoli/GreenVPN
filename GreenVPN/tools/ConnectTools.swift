//
//  ConnectTools.swift
//  GreenVPN
//
//  Created by sister on 2025/12/16.
//

import Foundation
import Combine
import NetworkExtension

class ConnectTools : ObservableObject {
   
    var manager = VPNManager.shared()
    
    private var connectBySelf: Bool = false
    
    init() {
        self.state = manager.coreMgr.connection.status
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
        //resetVPN()
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
    }
   
    
    @Published var state: NEVPNStatus = VPNManager.shared().coreMgr.connection.status {
        didSet {
            guard oldValue != state else { return }
            // 状态改变时，走统一映射
            applyStateToUI(state)
        }
    }
    
    /// 将系统 NEVPNStatus 同步到 UI（不依赖 didSet，供首次进入/无变更时调用）
    private func applyStateToUI(_ newState: NEVPNStatus) {
        switch newState {
        case .connected:
            debugPrint("NEVPNStatus: connected")
            if connectBySelf {
                textNetwork()           // 仅用户主动流程触发结果页/广告
                connectBySelf = false   // 处理一次后立即复位
            } else {
                connectionStatus = .connected
            }

        case .disconnected, .invalid:
            debugPrint("NEVPNStatus: disconnected")
            self.connectionStatus = .disconnected
            connectBySelf = false
        case .connecting:
            debugPrint("NEVPNStatus: connecting")
            connectionStatus = .connecting
        case .disconnecting, .reasserting:
            debugPrint("NEVPNStatus: disconnecting")
            connectionStatus = .connecting
        @unknown default:
            debugPrint("NEVPNStatus: failed")
            connectionStatus = .failed
            connectBySelf = false
        }
    }
    
    // 将NEVPNStatus转换为VPNConnectionStatus以保持UI一致性
    @Published var connectionStatus: VPNStatus = .disconnected {
        didSet {
            // 同步到GlobalStatus
        }
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        state = VPNManager.shared().coreMgr.connection.status
        debugPrint("NEVPNConnection state : \(state)")
        debugPrint("ConnectionStatus state : \(connectionStatus)")
    }
    
    func prepare(){
        connectBySelf = true
        manager.loadMAllFromPreferences() { error in
            debugPrint("prepare loadMAllFromPreferences")
            if let error = error {
                debugPrint("loadMAllFromPreferences error : \(error)")
            }else{
                self.startConnect()
            }
        }
    }
    
    func resetVPN() {
        manager.loadMAllFromPreferences { error in
            if error != nil {
                
            }
            // 加载完成后，读取一次系统状态；若不变则主动映射以驱动首帧 UI
            let current = self.manager.coreMgr.connection.status
            DispatchQueue.main.async {
                if self.state != current {
                    self.state = current
                } else {
                    self.applyStateToUI(current)
                }
            }
        }
    }
    
    func startConnect(){
        manager.enableAndConfigureVPNManager() { error in
            guard error == nil else {
                debugPrint("startConnect error 1 : \(String(describing: error))")
                return
            }
            self.manager.startVpnConnection() { error in
                guard error == nil else {
                    debugPrint("startConnect error 2 : \(String(describing: error))")
                    return
                }
            }
        }
    }
    
    func stopConnect(){
        manager.enableAndConfigureVPNManager() { error in
            guard error == nil else {
                return
            }
            
            self.manager.stopVpnConnection() { error in
                guard error == nil else {
                    return
                }
            }
        }
    }
    
    func handleButtonAction() {
        switch connectionStatus {
        case .connected:
            stopConnect()
        case .disconnected, .failed:
            self.connectionStatus = .connecting
            self.prepare()
        case .connecting:
            break
        }
    }
    
    func textNetwork() {
        debugPrint("NEVPNStatus: 主动连接")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            let isSuccess = true
            if isSuccess {
                self.sendSuccess()
            } else {
                self.sendFail()
            }
        }
        
    }
    
    func sendSuccess() {
        connectionStatus = .connected
        connectBySelf = false
    }
    
    func sendFail() {
        debugPrint("VM! Connect Failed")
        stopConnect()
        connectionStatus = .failed
        connectBySelf = false
    }
}
