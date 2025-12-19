//
//  GVRoute.swift
//  GreenVPN
//
//  负责连接流程相关的导航（连接页 / 结果页 / 节点列表）
//

import Foundation
import Combine

// 应用内路由枚举
enum GVRoute: Hashable {
    case connecting
    case result(SessionOutcome)
    case nodeList
    case settings
    case toolbox   // 工具箱页面
}

// 简单路由协调器，集中管理 NavigationStack 的 path
final class GVRouteCoordinator: ObservableObject {
    
    @Published var path: [GVRoute] = []
    
    /// 显示连接中页面（会清空现有栈）
    func showConnecting() {
        path = [.connecting]
    }
    
    /// 显示结果页（会清空现有栈）
    func showResult(_ result: SessionOutcome) {
        // 防止重复添加相同的结果页
        if let last = path.last, case .result(let lastResult) = last, lastResult == result {
            return
        }
        path = [.result(result)]
    }
    
    /// 显示节点列表（预留，后续可接节点页面）
    func showNodeList() {
        path = [.nodeList]
    }
    
    /// 显示设置页面
    func showSettings() {
        path = [.settings]
    }
    
    /// 显示工具箱页面
    func showToolbox() {
        path = [.toolbox]
    }
    
    /// 清空路由
    func reset() {
        path.removeAll()
    }
    
    /// 如果当前在连接页，则移除连接页
    func dismissConnectingIfNeeded() {
        if let last = path.last, case .connecting = last {
            path.removeLast()
        }
    }
}


