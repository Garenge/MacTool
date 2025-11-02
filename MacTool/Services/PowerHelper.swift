//
//  PowerHelper.swift
//  MacTool
//
//  Created by Garenge on 2025/11/2.
//

import Foundation

/// 功率监控辅助类（单例）
class PowerHelper {
    
    static let shared = PowerHelper()
    
    // MARK: - Properties
    
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 5.0 // 5秒刷新一次
    private var isRunning = false
    
    // MARK: - Initialization
    
    private init() {
        // 单例模式
    }
    
    // MARK: - Public Methods
    
    /// 开始监控
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        // 清空旧数据
        BatteryStorage.shared.clearAll()
        
        print("[PowerHelper] 🚀 开始功率监控 | 刷新间隔: \(Int(refreshInterval))秒")
        
        // 立即获取一次数据
        fetchPowerData()
        
        // 启动定时器
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.fetchPowerData()
        }
    }
    
    /// 停止监控
    func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
        
        print("[PowerHelper] 🛑 停止功率监控")
    }
    
    /// 获取功率数据
    @objc func fetchPowerData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 执行终端命令 - 获取完整电池信息
            let fullOutput = self?.executeFullBatteryCommand()
            
            // 执行简化命令获取功率
            let powerOutput = self?.executePowerCommand()
            
            DispatchQueue.main.async {
                // 先尝试从完整输出解析
                var dataPoint: BatteryDataPoint?
                if let fullOutput = fullOutput {
                    dataPoint = BatteryDataPoint.parse(from: fullOutput)
                }
                
                // 如果解析失败，使用功率输出
                if dataPoint == nil, let powerOutput = powerOutput {
                    dataPoint = BatteryDataPoint.parse(from: powerOutput)
                }
                
                guard let dataPoint = dataPoint else {
                    print("[PowerHelper] ❌ 无法解析电池数据")
                    return
                }
                
                // 日志：当前功率
                print("[PowerHelper] ⚡ 当前功率: \(String(format: "%.2f", dataPoint.power)) W")
                
                // 保存数据
                BatteryStorage.shared.save(dataPoint)
                
                // 发送通知
                NotificationCenter.default.post(
                    name: .powerDataUpdated,
                    object: nil,
                    userInfo: ["data": dataPoint]
                )
            }
        }
    }
    
    /// 执行获取功率的命令
    private func executePowerCommand() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "ioreg -n AppleSmartBattery -r | awk '/\"InstantAmperage\"/{a=$3} /\"Voltage\"/{v=$3} END{printf \"Current Power: %.2f W\\n\", a * v / 1000000}'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    /// 获取完整的电池信息（包含更多字段）
    func executeFullBatteryCommand() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "ioreg -n AppleSmartBattery -r"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    // MARK: - Query Methods
    
    /// 获取所有数据点
    func getAllDataPoints() -> [BatteryDataPoint] {
        return BatteryStorage.shared.loadAll()
    }
    
    /// 获取最近的 N 个数据点
    func getRecentDataPoints(count: Int) -> [BatteryDataPoint] {
        return BatteryStorage.shared.loadRecent(count: count)
    }
    
    /// 获取指定时间范围内的数据
    func getDataPoints(from startDate: Date, to endDate: Date) -> [BatteryDataPoint] {
        return BatteryStorage.shared.load(from: startDate, to: endDate)
    }
    
    /// 获取数据点总数
    func getDataPointCount() -> Int {
        return BatteryStorage.shared.count()
    }
    
    /// 清空所有数据
    func clearAllData() {
        BatteryStorage.shared.clearAll()
    }
}

