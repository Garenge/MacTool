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
            // 方法1：尝试使用完整命令获取所有数据（一步操作）
            if let fullOutput = self?.executeFullBatteryCommand(),
               let dataPoint = BatteryDataPoint.parse(from: fullOutput) {
                DispatchQueue.main.async {
                    self?.handleDataPoint(dataPoint)
                }
                return
            }
            
            // 方法2：如果方法1失败，尝试分别获取电压和电流（分步操作）
            print("[PowerHelper] ⚠️ 完整解析失败，尝试分别获取电压和电流...")
            
            // 分步获取所有信息
            let voltage = self?.getVoltage()
            let current = self?.getCurrent()
            let isCharging = self?.getChargingStatus() ?? false
            let percentage = self?.getBatteryPercentage() ?? 0
            
            // 获取额外信息（分步操作，可选）
            let temperature = self?.getTemperature()
            let cycleCount = self?.getCycleCount()
            let designCapacity = self?.getDesignCapacity()
            let maxCapacity = self?.getMaxCapacity()
            let batteryHealth = self?.calculateBatteryHealth(maxCapacity: maxCapacity, designCapacity: designCapacity)
            
            // 如果电压获取成功，创建数据点
            if let voltage = voltage, voltage > 0 {
                let powerValue = current != nil ? (voltage * (current ?? 0)) / 1000000.0 : 0
                
                let dataPoint = BatteryDataPoint(
                    timestamp: Date(),
                    voltage: voltage,
                    current: current ?? 0,
                    power: powerValue,
                    percentage: percentage,
                    isCharging: isCharging,
                    temperature: temperature,
                    cycleCount: cycleCount,
                    designCapacity: designCapacity,
                    maxCapacity: maxCapacity,
                    batteryHealth: batteryHealth
                )
                
                DispatchQueue.main.async {
                    self?.handleDataPoint(dataPoint)
                }
            } else {
                DispatchQueue.main.async {
                    print("[PowerHelper] ❌ 无法解析电池数据（所有方法均失败）")
                }
            }
        }
    }
    
    /// 处理成功获取的数据点
    private func handleDataPoint(_ dataPoint: BatteryDataPoint) {
        // 日志：当前功率
        print("[PowerHelper] ⚡ 当前功率: \(String(format: "%.2f", dataPoint.power)) W | 电压: \(String(format: "%.0f", dataPoint.voltage)) mV | 电流: \(String(format: "%.0f", dataPoint.current)) mA")
        
        // 保存数据
        BatteryStorage.shared.save(dataPoint)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .powerDataUpdated,
            object: nil,
            userInfo: ["data": dataPoint]
        )
    }
    
    /// 获取完整的电池信息（包含更多字段）
    private func executeFullBatteryCommand() -> String? {
        return executeIORegCommand(arguments: ["-n", "AppleSmartBattery", "-r"])
    }
    
    /// 分别获取电压（单位：mV）
    private func getVoltage() -> Double? {
        // 使用更精确的命令获取电压
        if let output = executeIORegCommand(arguments: ["-rn", "AppleSmartBattery", "-w", "0"]),
           let voltageStr = extractValueFromIOReg(output: output, key: "Voltage"),
           let voltage = Double(voltageStr), voltage > 0 {
            return voltage
        }
        return nil
    }
    
    /// 分别获取电流（单位：mA）
    private func getCurrent() -> Double? {
        // 使用更精确的命令获取电流
        if let output = executeIORegCommand(arguments: ["-rn", "AppleSmartBattery", "-w", "0"]),
           let currentStr = extractValueFromIOReg(output: output, key: "InstantAmperage") {
            // 检查是否为异常值
            if let current = Double(currentStr) {
                // 检查字符串长度和数值范围
                if currentStr.count > 10 || abs(current) > 1.0e+18 || abs(current) > 10000 {
                    print("[PowerHelper] ⚠️ 检测到异常电流值，跳过: \(currentStr)")
                    return nil
                }
                return current
            }
        }
        return nil
    }
    
    /// 获取充电状态
    private func getChargingStatus() -> Bool {
        if let output = executeIORegCommand(arguments: ["-rn", "AppleSmartBattery", "-w", "0"]) {
            // 检查多个条件
            let hasIsCharging = output.contains("\"IsCharging\" = Yes")
            let hasExternalConnected = output.contains("\"ExternalConnected\" = Yes")
            
            // 如果 IsCharging = Yes，直接返回 true
            if hasIsCharging {
                return true
            }
            
            // 如果充电器已连接，检查电流判断是否在充电
            if hasExternalConnected {
                if let current = getCurrent(), current > 100 {
                    // 正电流且大于100mA，认为在充电
                    return true
                }
            }
        }
        return false
    }
    
    /// 获取电池电量百分比
    private func getBatteryPercentage() -> Int {
        if let output = executeIORegCommand(arguments: ["-rn", "AppleSmartBattery", "-w", "0"]),
           let percentageStr = extractValueFromIOReg(output: output, key: "CurrentCapacity"),
           let percentage = Int(percentageStr) {
            return percentage
        }
        return 0
    }
    
    /// 获取温度（单位：°C）
    private func getTemperature() -> Double? {
        if let output = executeIORegCommand(arguments: ["-rn", "AppleSmartBattery", "-w", "0"]),
           let tempStr = extractValueFromIOReg(output: output, key: "Temperature"),
           let temp = Int(tempStr) {
            // Temperature 字段单位是 0.1°C，需要除以 10
            return Double(temp) / 10.0
        }
        return nil
    }
    
    /// 获取循环次数
    private func getCycleCount() -> Int? {
        if let output = executeIORegCommand(arguments: ["-rn", "AppleSmartBattery", "-w", "0"]),
           let cycleStr = extractValueFromIOReg(output: output, key: "CycleCount"),
           let cycle = Int(cycleStr) {
            return cycle
        }
        return nil
    }
    
    /// 获取设计容量（mAh）
    private func getDesignCapacity() -> Int? {
        if let output = executeIORegCommand(arguments: ["-rn", "AppleSmartBattery", "-w", "0"]),
           let capacityStr = extractValueFromIOReg(output: output, key: "DesignCapacity"),
           let capacity = Int(capacityStr) {
            return capacity
        }
        return nil
    }
    
    /// 获取最大容量（mAh）
    private func getMaxCapacity() -> Int? {
        if let output = executeIORegCommand(arguments: ["-rn", "AppleSmartBattery", "-w", "0"]),
           let capacityStr = extractValueFromIOReg(output: output, key: "MaxCapacity"),
           let capacity = Int(capacityStr) {
            return capacity
        }
        return nil
    }
    
    /// 计算电池健康度（0-100%）
    private func calculateBatteryHealth(maxCapacity: Int?, designCapacity: Int?) -> Double? {
        guard let max = maxCapacity, let design = designCapacity, design > 0 else {
            return nil
        }
        return Double(max) / Double(design) * 100.0
    }
    
    /// 执行 ioreg 命令的通用方法
    private func executeIORegCommand(arguments: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        task.arguments = arguments
        
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
    
    /// 从 ioreg 输出中提取特定键的值
    private func extractValueFromIOReg(output: String, key: String) -> String? {
        // 匹配模式：key" = value (支持多种格式)
        // 例如: "Voltage" = 12345 或 "InstantAmperage" = -1234
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = #""\#(escapedKey)"\s*=\s*([-]?\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: output.utf16.count)
        guard let match = regex.firstMatch(in: output, range: range) else { return nil }
        guard let valueRange = Range(match.range(at: 1), in: output) else { return nil }
        let valueStr = String(output[valueRange])
        
        // 安全检查：如果字符串过长，可能是异常值
        if valueStr.count > 10 {
            print("[PowerHelper] ⚠️ 检测到异常长的数值: \(key) = \(valueStr)")
            return nil
        }
        
        return valueStr
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
    
    // MARK: - Statistics Methods
    
    /// 获取所有数据的统计分析
    func getAllStatistics() -> BatteryStatistics? {
        return BatteryStatisticsAnalyzer.shared.analyzeAll()
    }
    
    /// 获取指定时间范围内的统计分析
    func getStatistics(from startDate: Date, to endDate: Date) -> BatteryStatistics? {
        return BatteryStatisticsAnalyzer.shared.analyze(from: startDate, to: endDate)
    }
    
    /// 获取最近 N 个数据点的统计分析
    func getRecentStatistics(count: Int) -> BatteryStatistics? {
        return BatteryStatisticsAnalyzer.shared.analyzeRecent(count: count)
    }
    
    /// 获取功率随电量变化的详细数据
    func getPowerByPercentageData() -> [(percentage: Int, averagePower: Double, sampleCount: Int)] {
        let dataPoints = BatteryStorage.shared.loadAll()
        return BatteryStatisticsAnalyzer.shared.getPowerByPercentageData(dataPoints: dataPoints)
    }
}

