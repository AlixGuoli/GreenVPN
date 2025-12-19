//
//  GVNodeManager.swift
//  GreenVPN
//
//  节点管理器：管理节点列表和当前选中节点
//

import Foundation
import Combine

/// 节点管理器（单例）
final class GVNodeManager: ObservableObject {
    
    static let shared = GVNodeManager()
    
    /// 所有可用节点列表
    @Published var nodes: [GVNode] = []
    
    /// 当前选中的节点 ID
    @Published var selectedNodeId: Int? {
        didSet {
            if let id = selectedNodeId {
                UserDefaults.standard.set(id, forKey: "GreenVPNSelectedNodeId")
            } else {
                UserDefaults.standard.removeObject(forKey: "GreenVPNSelectedNodeId")
            }
        }
    }
    
    /// 当前选中的节点
    var selectedNode: GVNode? {
        guard let id = selectedNodeId else { return nil }
        return nodes.first { $0.id == id }
    }
    
    private init() {
        loadMockNodes()
        restoreSelectedNode()
    }
    
    /// 加载假节点数据
    private func loadMockNodes() {
        // 统一的随机范围，让所有节点平等，但每个节点独立随机
        nodes = [
            GVNode(
                id: -1,
                name: "自动选择",
                countryCode: "auto",
                countryName: "自动",
                latency: 0,
                isAvailable: true,
                load: 0.0
            ),
            GVNode(
                id: 1,
                name: "美国",
                countryCode: "us",
                countryName: "美国",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            ),
            GVNode(
                id: 2,
                name: "德国",
                countryCode: "de",
                countryName: "德国",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            ),
            GVNode(
                id: 3,
                name: "法国",
                countryCode: "fr",
                countryName: "法国",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            ),
            GVNode(
                id: 4,
                name: "英国",
                countryCode: "gb",
                countryName: "英国",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            ),
            GVNode(
                id: 5,
                name: "日本",
                countryCode: "jp",
                countryName: "日本",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            ),
            GVNode(
                id: 6,
                name: "加拿大",
                countryCode: "ca",
                countryName: "加拿大",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            ),
            GVNode(
                id: 7,
                name: "新加坡",
                countryCode: "sg",
                countryName: "新加坡",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            ),
            GVNode(
                id: 8,
                name: "澳大利亚",
                countryCode: "au",
                countryName: "澳大利亚",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            ),
            GVNode(
                id: 9,
                name: "韩国",
                countryCode: "kr",
                countryName: "韩国",
                latency: Int.random(in: 5...120),
                isAvailable: true,
                load: Double.random(in: 0.05...0.35)
            )
        ]
        
        // 如果没有选中节点，默认选择 auto 节点（id=-1）
        if selectedNodeId == nil && !nodes.isEmpty {
            selectedNodeId = -1
        }
    }
    
    /// 随机更新所有节点的延迟和负载（每次进入节点列表时调用）
    /// 所有节点使用统一的随机范围，但每个节点独立随机，确保有差异但不会相差太大
    func refreshNodeStats() {
        for index in nodes.indices {
            if nodes[index].id == -1 {
                // Auto 节点不更新
                continue
            }
            // 所有节点使用统一的随机范围，让它们平等
            // 延迟范围：5-120ms（合理的 VPN 延迟范围）
            // 负载范围：0.05-0.35（大部分会是低负载，绿色）
            nodes[index].latency = Int.random(in: 5...120)
            nodes[index].load = Double.random(in: 0.05...0.35)
        }
    }
    
    /// 恢复之前选中的节点
    private func restoreSelectedNode() {
        let savedId = UserDefaults.standard.integer(forKey: "GreenVPNSelectedNodeId")
        if savedId != 0 && nodes.contains(where: { $0.id == savedId }) {
            selectedNodeId = savedId
        }
    }
    
    /// 选择节点
    func selectNode(_ node: GVNode) {
        selectedNodeId = node.id
    }
    
    /// 选择节点（通过 ID）
    func selectNode(id: Int) {
        if nodes.contains(where: { $0.id == id }) {
            selectedNodeId = id
        }
    }
    
    /// 更新节点延迟（假数据，用于模拟动态延迟）
    func updateNodeLatency(nodeId: Int, latency: Int) {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            nodes[index].latency = latency
        }
    }
}

