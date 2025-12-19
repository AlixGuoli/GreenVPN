//
//  GVConnectionStatsManager.swift
//  GreenVPN
//
//  连接统计管理器
//

import Foundation
import Combine

/// 连接统计管理器（单例）
final class GVConnectionStatsManager: ObservableObject {
    
    static let shared = GVConnectionStatsManager()
    
    /// 总连接时长（秒）
    @Published var totalDuration: TimeInterval = 0
    
    /// 总连接次数
    @Published var totalConnections: Int = 0
    
    /// 今日连接时长（秒）
    @Published var todayDuration: TimeInterval = 0
    
    private let totalDurationKey = "GVStatsTotalDuration"
    private let totalConnectionsKey = "GVStatsTotalConnections"
    private let todayDurationKey = "GVStatsTodayDuration"
    private let lastDateKey = "GVStatsLastDate"
    
    private init() {
        loadStats()
        checkDateReset()
    }
    
    /// 加载统计数据
    private func loadStats() {
        totalDuration = UserDefaults.standard.double(forKey: totalDurationKey)
        totalConnections = UserDefaults.standard.integer(forKey: totalConnectionsKey)
        todayDuration = UserDefaults.standard.double(forKey: todayDurationKey)
    }
    
    /// 检查是否需要重置今日统计（跨天）
    private func checkDateReset() {
        let lastDate = UserDefaults.standard.string(forKey: lastDateKey)
        let today = getTodayString()
        
        if lastDate != today {
            // 新的一天，重置今日统计
            todayDuration = 0
            UserDefaults.standard.set(todayDuration, forKey: todayDurationKey)
            UserDefaults.standard.set(today, forKey: lastDateKey)
        }
    }
    
    /// 获取今天的日期字符串（YYYY-MM-DD）
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /// 记录一次连接（连接成功时调用）
    func recordConnection() {
        totalConnections += 1
        UserDefaults.standard.set(totalConnections, forKey: totalConnectionsKey)
    }
    
    /// 记录连接时长（断开连接时调用）
    func recordDuration(_ duration: TimeInterval) {
        totalDuration += duration
        todayDuration += duration
        
        UserDefaults.standard.set(totalDuration, forKey: totalDurationKey)
        UserDefaults.standard.set(todayDuration, forKey: todayDurationKey)
        UserDefaults.standard.set(getTodayString(), forKey: lastDateKey)
    }
    
    /// 清除所有统计数据
    func clearAllStats() {
        totalDuration = 0
        totalConnections = 0
        todayDuration = 0
        
        UserDefaults.standard.removeObject(forKey: totalDurationKey)
        UserDefaults.standard.removeObject(forKey: totalConnectionsKey)
        UserDefaults.standard.removeObject(forKey: todayDurationKey)
        UserDefaults.standard.removeObject(forKey: lastDateKey)
    }
}

