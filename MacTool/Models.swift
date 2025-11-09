//
//  Models.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Foundation
import SQLite3

// MARK: - Tool Models

// 功能类型枚举
enum ToolType: Int, CaseIterable {
    case power = 0
    case theme = 1
    
    var identifier: String {
        switch self {
        case .power:
            return "power"
        case .theme:
            return "theme"
        }
    }
    
    var title: String {
        switch self {
        case .power:
            return "充电功率"
        case .theme:
            return "主题设置"
        }
    }
    
    var icon: String {
        switch self {
        case .power:
            return "🔋"
        case .theme:
            return "🎨"
        }
    }
}

// 功能项结构
struct ToolItem {
    let id: String
    let title: String
    let icon: String
    let type: ToolType
}

// MARK: - Battery Models

/// 电池数据点
struct BatteryDataPoint: Codable, Equatable {
    let timestamp: Date
    let voltage: Double          // mV
    let current: Double          // mA
    let power: Double            // W
    let percentage: Int          // 电量百分比
    let isCharging: Bool
    let temperature: Double?     // 温度 (0.1°C，例如 216 表示 21.6°C)
    let cycleCount: Int?         // 循环次数
    let designCapacity: Int?     // 设计容量 (mAh)
    let maxCapacity: Int?         // 最大容量 (mAh)
    let batteryHealth: Double?   // 电池健康度 (0-100)
    
    /// 从 ioreg 命令输出解析
    static func parse(from output: String) -> BatteryDataPoint? {
        // 判断是否在充电：检查多个条件
        // 1. IsCharging = Yes
        // 2. ExternalConnected = Yes (充电器已连接)
        // 3. 如果电量<100%且ExternalConnected=Yes，通常也在充电
        let hasIsCharging = output.contains("\"IsCharging\" = Yes") || output.contains("IsCharging.*=.*Yes")
        let hasExternalConnected = output.contains("\"ExternalConnected\" = Yes") || output.contains("ExternalConnected.*=.*Yes")
        
        // 如果有电流值，也可以通过电流判断（正电流表示充电）
        let hasCurrent = extractValue(from: output, pattern: #"\n\s+"InstantAmperage"\s*=\s*([-]?\d+)"#)
        let isChargingByCurrent = (hasCurrent != nil) && (hasCurrent ?? 0) > 100 // 电流大于100mA认为是充电
        
        // 综合判断：IsCharging 或 (ExternalConnected 且电流为正)
        let isCharging = hasIsCharging || (hasExternalConnected && isChargingByCurrent)
        
        // 解析电压 (Voltage字段，单位mV) - 无论是否充电都需要
        guard let voltage = extractValue(from: output, pattern: #"\n\s+"Voltage"\s*=\s*(\d+)"#), voltage > 0 else {
            print("[BatteryDataPoint] ❌ 电压解析失败或为0")
            return nil
        }
        
        // 解析电量百分比
        let percentage = extractIntValue(from: output, pattern: #"CurrentCapacity.*?=\s*(\d+)"#) ?? 0
        
        // 解析额外信息（可选字段）
        let temperature = extractIntValue(from: output, pattern: #"Temperature.*?=\s*(\d+)"#).map { Double($0) / 10.0 }
        let cycleCount = extractIntValue(from: output, pattern: #"CycleCount.*?=\s*(\d+)"#)
        let designCapacity = extractIntValue(from: output, pattern: #"DesignCapacity.*?=\s*(\d+)"#)
        let maxCapacity = extractIntValue(from: output, pattern: #"MaxCapacity.*?=\s*(\d+)"#)
        let batteryHealth = maxCapacity.flatMap { max in
            designCapacity.flatMap { design in
                design > 0 ? Double(max) / Double(design) * 100.0 : nil
            }
        }
        
        // 如果不在充电，直接返回（功率为0）
        if !isCharging {
            return BatteryDataPoint(
                timestamp: Date(),
                voltage: voltage,
                current: 0,
                power: 0,
                percentage: percentage,
                isCharging: false,
                temperature: temperature,
                cycleCount: cycleCount,
                designCapacity: designCapacity,
                maxCapacity: maxCapacity,
                batteryHealth: batteryHealth
            )
        }
        
        // 如果在充电，解析电流并计算功率
        // 支持正负数（负值表示放电，正值表示充电）
        guard let current = extractValue(from: output, pattern: #"\n\s+"InstantAmperage"\s*=\s*([-]?\d+)"#) else {
            print("[BatteryDataPoint] ❌ 充电状态但电流解析失败")
            return nil
        }
        
        // 检查电流值是否异常
        // 1. 首先检查是否为无符号整数溢出值（UInt64.max 约为 1.844e+19）
        //    这个值通常表示数据读取错误或设备未正确初始化
        if abs(current) > 1.0e+18 {
            print("[BatteryDataPoint] ❌ 电流值异常（可能是溢出）: \(current) mA")
            return nil
        }
        
        // 2. 检查是否在合理范围内（正常电池电流范围：-10000mA 到 10000mA）
        //    负值表示放电，正值表示充电
        if current < -10000 || current > 10000 {
            print("[BatteryDataPoint] ❌ 电流值超出合理范围: \(current) mA")
            return nil
        }
        
        // 计算功率（单位：W）
        let powerValue = (voltage * current) / 1000000.0
        
        // 检查功率是否在合理范围内（-200W 到 200W）
        if abs(powerValue) > 200 {
            print("[BatteryDataPoint] ❌ 功率值异常: \(powerValue) W")
            return nil
        }
        
        return BatteryDataPoint(
            timestamp: Date(),
            voltage: voltage,
            current: current,
            power: powerValue,
            percentage: percentage,
            isCharging: true,
            temperature: temperature,
            cycleCount: cycleCount,
            designCapacity: designCapacity,
            maxCapacity: maxCapacity,
            batteryHealth: batteryHealth
        )
    }
    
    // MARK: - Private Helpers
    
    private static func extractValue(from output: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: output.utf16.count)
        guard let match = regex.firstMatch(in: output, range: range) else { return nil }
        guard let numberRange = Range(match.range(at: 1), in: output) else { return nil }
        
        let numberString = String(output[numberRange])
        
        // 安全检查：如果字符串过长，可能是异常值（正常电池数值不应该超过10位）
        if numberString.count > 10 {
            print("[BatteryDataPoint] ⚠️ 检测到异常长的数值字符串: \(numberString)")
            return nil
        }
        
        // 转换为 Double
        guard let value = Double(numberString) else { return nil }
        
        return value
    }
    
    private static func extractIntValue(from output: String, pattern: String) -> Int? {
        guard let value = extractValue(from: output, pattern: pattern) else { return nil }
        return Int(value)
    }
}

/// 电池数据存储管理器 - 使用 SQLite 数据库
class BatteryStorage {
    
    static let shared = BatteryStorage()
    
    private var db: OpaquePointer?
    private let maxDataPoints = 10000 // 最大存储点数
    private let maxRetentionDays = 7 // 数据保留天数
    
    private init() {
        setupDatabase()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        let fileURL = getDatabaseURL()
        
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            print("[BatteryStorage] 💾 数据库已打开: \(fileURL.path)")
            createTable()
        } else {
            print("[BatteryStorage] ❌ 无法打开数据库")
        }
    }
    
    private func getDatabaseURL() -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[0]
        return documentsDirectory.appendingPathComponent("BatteryData.sqlite")
    }
    
    private func createTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS BatteryDataPoint (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            voltage REAL NOT NULL,
            current REAL NOT NULL,
            power REAL NOT NULL,
            percentage INTEGER NOT NULL,
            isCharging INTEGER NOT NULL,
            temperature REAL,
            cycleCount INTEGER,
            designCapacity INTEGER,
            maxCapacity INTEGER,
            batteryHealth REAL
        );
        CREATE INDEX IF NOT EXISTS idx_timestamp ON BatteryDataPoint(timestamp);
        CREATE INDEX IF NOT EXISTS idx_percentage ON BatteryDataPoint(percentage);
        CREATE INDEX IF NOT EXISTS idx_power ON BatteryDataPoint(power);
        """
        
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, createTableSQL, nil, nil, &errMsg) != SQLITE_OK {
            print("[BatteryStorage] ❌ 创建表失败: \(String(cString: errMsg!))")
        } else {
            print("[BatteryStorage] ✅ 表结构已创建/验证")
            // 迁移现有表（为旧数据库添加新列）
            migrateTableIfNeeded()
        }
    }
    
    /// 迁移表结构（为现有表添加新列）
    private func migrateTableIfNeeded() {
        let migrations = [
            "ALTER TABLE BatteryDataPoint ADD COLUMN cycleCount INTEGER",
            "ALTER TABLE BatteryDataPoint ADD COLUMN designCapacity INTEGER",
            "ALTER TABLE BatteryDataPoint ADD COLUMN maxCapacity INTEGER",
            "ALTER TABLE BatteryDataPoint ADD COLUMN batteryHealth REAL"
        ]
        
        for migrationSQL in migrations {
            // SQLite 不支持 IF NOT EXISTS，所以需要捕获错误
            var errMsg: UnsafeMutablePointer<Int8>?
            if sqlite3_exec(db, migrationSQL, nil, nil, &errMsg) != SQLITE_OK {
                if let errMsg = errMsg {
                    let error = String(cString: errMsg)
                    // 如果列已存在，忽略错误（SQLite 返回 "duplicate column name"）
                    if !error.contains("duplicate column name") {
                        print("[BatteryStorage] ⚠️ 迁移警告: \(error)")
                    }
                }
            }
        }
        
        // 创建索引（如果不存在）
        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_percentage ON BatteryDataPoint(percentage)",
            "CREATE INDEX IF NOT EXISTS idx_power ON BatteryDataPoint(power)"
        ]
        
        for indexSQL in indexes {
            var errMsg: UnsafeMutablePointer<Int8>?
            if sqlite3_exec(db, indexSQL, nil, nil, &errMsg) != SQLITE_OK {
                if let errMsg = errMsg {
                    print("[BatteryStorage] ⚠️ 创建索引失败: \(String(cString: errMsg))")
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取数据库路径
    func getDatabasePath() -> URL {
        return getDatabaseURL()
    }
    
    /// 保存数据点
    func save(_ dataPoint: BatteryDataPoint) {
        let insertSQL = "INSERT INTO BatteryDataPoint (timestamp, voltage, current, power, percentage, isCharging, temperature, cycleCount, designCapacity, maxCapacity, batteryHealth) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        
        var statement: OpaquePointer?
        var insertSuccess = false
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, dataPoint.timestamp.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, dataPoint.voltage)
            sqlite3_bind_double(statement, 3, dataPoint.current)
            sqlite3_bind_double(statement, 4, dataPoint.power)
            sqlite3_bind_int(statement, 5, Int32(dataPoint.percentage))
            sqlite3_bind_int(statement, 6, dataPoint.isCharging ? 1 : 0)
            if let temp = dataPoint.temperature {
                sqlite3_bind_double(statement, 7, temp)
            } else {
                sqlite3_bind_null(statement, 7)
            }
            if let cycle = dataPoint.cycleCount {
                sqlite3_bind_int(statement, 8, Int32(cycle))
            } else {
                sqlite3_bind_null(statement, 8)
            }
            if let design = dataPoint.designCapacity {
                sqlite3_bind_int(statement, 9, Int32(design))
            } else {
                sqlite3_bind_null(statement, 9)
            }
            if let max = dataPoint.maxCapacity {
                sqlite3_bind_int(statement, 10, Int32(max))
            } else {
                sqlite3_bind_null(statement, 10)
            }
            if let health = dataPoint.batteryHealth {
                sqlite3_bind_double(statement, 11, health)
            } else {
                sqlite3_bind_null(statement, 11)
            }
            
            if sqlite3_step(statement) == SQLITE_DONE {
                insertSuccess = true
            } else {
                print("[BatteryStorage] ❌ 数据保存失败")
            }
        }
        
        sqlite3_finalize(statement)
        
        // 限制数据量
        cleanupOldData()
        
        // 日志：保存成功后的信息
        if insertSuccess {
            let totalCount = count()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"
            
            print("[BatteryStorage] ✅ 数据已保存 | 总数: \(totalCount) | 时间: \(dateFormatter.string(from: dataPoint.timestamp))")
        }
    }
    
    /// 加载所有数据
    func loadAll() -> [BatteryDataPoint] {
        return loadData(where: "1=1", orderBy: "timestamp ASC")
    }
    
    /// 获取最近的 N 个数据点
    func loadRecent(count: Int) -> [BatteryDataPoint] {
        return loadData(where: nil, limit: count, orderBy: "timestamp DESC")
    }
    
    /// 获取指定时间范围内的数据
    func load(from startDate: Date, to endDate: Date) -> [BatteryDataPoint] {
        let startTime = startDate.timeIntervalSince1970
        let endTime = endDate.timeIntervalSince1970
        let whereClause = "timestamp >= \(startTime) AND timestamp <= \(endTime)"
        return loadData(where: whereClause, orderBy: "timestamp ASC")
    }
    
    /// 清空所有数据
    func clearAll() {
        let deleteSQL = "DELETE FROM BatteryDataPoint;"
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                success = true
            } else {
                print("[BatteryStorage] ❌ 清空数据失败")
            }
        }
        
        sqlite3_finalize(statement)
        
        if success {
            print("[BatteryStorage] 🗑️ 所有数据已清空")
        }
    }
    
    /// 获取数据点数量
    func count() -> Int {
        let querySQL = "SELECT COUNT(*) FROM BatteryDataPoint;"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    // MARK: - Private Methods
    
    private func loadData(where whereClause: String?, limit: Int? = nil, orderBy: String) -> [BatteryDataPoint] {
        var querySQL = "SELECT timestamp, voltage, current, power, percentage, isCharging, temperature, cycleCount, designCapacity, maxCapacity, batteryHealth FROM BatteryDataPoint"
        
        if let whereClause = whereClause {
            querySQL += " WHERE \(whereClause)"
        }
        
        querySQL += " ORDER BY \(orderBy)"
        
        if let limit = limit {
            querySQL += " LIMIT \(limit)"
        }
        
        var statement: OpaquePointer?
        var dataPoints: [BatteryDataPoint] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
                let voltage = sqlite3_column_double(statement, 1)
                let current = sqlite3_column_double(statement, 2)
                let power = sqlite3_column_double(statement, 3)
                let percentage = Int(sqlite3_column_int(statement, 4))
                let isCharging = sqlite3_column_int(statement, 5) != 0
                let temperature = sqlite3_column_type(statement, 6) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 6)
                let cycleCount = sqlite3_column_type(statement, 7) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 7))
                let designCapacity = sqlite3_column_type(statement, 8) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 8))
                let maxCapacity = sqlite3_column_type(statement, 9) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 9))
                let batteryHealth = sqlite3_column_type(statement, 10) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 10)
                
                let dataPoint = BatteryDataPoint(
                    timestamp: timestamp,
                    voltage: voltage,
                    current: current,
                    power: power,
                    percentage: percentage,
                    isCharging: isCharging,
                    temperature: temperature,
                    cycleCount: cycleCount,
                    designCapacity: designCapacity,
                    maxCapacity: maxCapacity,
                    batteryHealth: batteryHealth
                )
                dataPoints.append(dataPoint)
            }
        }
        
        sqlite3_finalize(statement)
        return dataPoints
    }
    
    private func cleanupOldData() {
        // 1. 按时间清理：删除超过保留天数的数据
        let cutoffTime = Date().addingTimeInterval(-Double(maxRetentionDays * 24 * 60 * 60)).timeIntervalSince1970
        let deleteOldSQL = "DELETE FROM BatteryDataPoint WHERE timestamp < ?;"
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteOldSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, cutoffTime)
            sqlite3_step(statement)
            sqlite3_finalize(statement)
        }
        
        // 2. 按数量清理：如果超过最大点数，删除最旧的数据
        let currentCount = count()
        if currentCount > maxDataPoints {
            let excessCount = currentCount - maxDataPoints
            let deleteSQL = "DELETE FROM BatteryDataPoint WHERE id IN (SELECT id FROM BatteryDataPoint ORDER BY timestamp ASC LIMIT ?);"
            
            if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(excessCount))
                sqlite3_step(statement)
                sqlite3_finalize(statement)
            }
        }
    }
}

// MARK: - Battery Statistics

/// 电池统计分析结果
struct BatteryStatistics {
    /// 最大功率（W）
    let maxPower: Double
    /// 最小功率（W）
    let minPower: Double
    /// 平均功率（W）
    let averagePower: Double
    /// 总数据点数
    let totalDataPoints: Int
    /// 充电数据点数
    let chargingDataPoints: Int
    /// 功率随电量变化的趋势（每10%电量的平均功率）
    let powerByPercentage: [Int: Double]  // [电量百分比: 平均功率]
    /// 功率开始下降时的电量百分比
    let powerDropPercentage: Int?
    /// 最大功率时的电量百分比
    let maxPowerPercentage: Int?
    
    /// 格式化输出
    func format() -> String {
        var result = "📊 电池统计分析\n"
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "📈 功率统计:\n"
        result += "  最大功率: \(String(format: "%.2f", maxPower)) W\n"
        result += "  最小功率: \(String(format: "%.2f", minPower)) W\n"
        result += "  平均功率: \(String(format: "%.2f", averagePower)) W\n"
        result += "\n📊 数据统计:\n"
        result += "  总数据点: \(totalDataPoints)\n"
        result += "  充电数据点: \(chargingDataPoints)\n"
        
        if let maxPowerPct = maxPowerPercentage {
            result += "\n⚡ 最大功率出现在 \(maxPowerPct)% 电量时\n"
        }
        
        if let dropPct = powerDropPercentage {
            result += "📉 功率开始下降在 \(dropPct)% 电量时\n"
        }
        
        result += "\n📋 不同电量段的平均功率:\n"
        let sortedPercentages = powerByPercentage.keys.sorted(by: >)
        for pct in sortedPercentages.prefix(10) {  // 只显示前10个
            if let power = powerByPercentage[pct] {
                result += "  \(pct)%: \(String(format: "%.2f", power)) W\n"
            }
        }
        
        return result
    }
}

/// 电池统计分析类
class BatteryStatisticsAnalyzer {
    
    static let shared = BatteryStatisticsAnalyzer()
    
    private init() {}
    
    /// 分析所有数据
    func analyzeAll() -> BatteryStatistics? {
        let dataPoints = BatteryStorage.shared.loadAll()
        return analyze(dataPoints: dataPoints)
    }
    
    /// 分析指定时间范围内的数据
    func analyze(from startDate: Date, to endDate: Date) -> BatteryStatistics? {
        let dataPoints = BatteryStorage.shared.load(from: startDate, to: endDate)
        return analyze(dataPoints: dataPoints)
    }
    
    /// 分析最近 N 个数据点
    func analyzeRecent(count: Int) -> BatteryStatistics? {
        let dataPoints = BatteryStorage.shared.loadRecent(count: count)
        return analyze(dataPoints: dataPoints)
    }
    
    /// 核心分析方法
    private func analyze(dataPoints: [BatteryDataPoint]) -> BatteryStatistics? {
        guard !dataPoints.isEmpty else {
            print("[BatteryStatistics] ⚠️ 没有数据可分析")
            return nil
        }
        
        // 只分析充电时的数据
        let chargingPoints = dataPoints.filter { $0.isCharging && $0.power > 0 }
        guard !chargingPoints.isEmpty else {
            print("[BatteryStatistics] ⚠️ 没有充电数据可分析")
            return nil
        }
        
        // 计算基本统计
        let powers = chargingPoints.map { $0.power }
        let maxPower = powers.max() ?? 0
        let minPower = powers.min() ?? 0
        let averagePower = powers.reduce(0, +) / Double(powers.count)
        
        // 找到最大功率时的电量
        let maxPowerPoint = chargingPoints.max(by: { $0.power < $1.power })
        let maxPowerPercentage = maxPowerPoint?.percentage
        
        // 按电量百分比分组计算平均功率
        var powerByPercentage: [Int: [Double]] = [:]
        for point in chargingPoints {
            let pct = point.percentage
            if powerByPercentage[pct] == nil {
                powerByPercentage[pct] = []
            }
            powerByPercentage[pct]?.append(point.power)
        }
        
        // 计算每10%电量段的平均功率（例如 90-99%, 80-89% 等）
        var powerByPercentageGrouped: [Int: Double] = [:]
        for (pct, powerValues) in powerByPercentage {
            let groupKey = (pct / 10) * 10  // 向下取整到10的倍数
            let avgPower = powerValues.reduce(0, +) / Double(powerValues.count)
            if powerByPercentageGrouped[groupKey] == nil {
                powerByPercentageGrouped[groupKey] = avgPower
            } else {
                // 如果该组已有数据，取平均值
                powerByPercentageGrouped[groupKey] = (powerByPercentageGrouped[groupKey]! + avgPower) / 2.0
            }
        }
        
        // 分析功率下降趋势：找到功率开始明显下降的电量百分比
        // 从高电量到低电量，找到第一个功率明显下降的点（下降超过平均功率的10%）
        let sortedGroups = powerByPercentageGrouped.keys.sorted(by: >)
        var powerDropPercentage: Int? = nil
        
        if sortedGroups.count >= 2 {
            var prevPower: Double? = nil
            for groupKey in sortedGroups {
                if let currentPower = powerByPercentageGrouped[groupKey] {
                    if let prev = prevPower {
                        // 如果功率下降了超过10%，记录这个点
                        let dropRatio = (prev - currentPower) / prev
                        if dropRatio > 0.1 && powerDropPercentage == nil {
                            powerDropPercentage = groupKey
                        }
                    }
                    prevPower = currentPower
                }
            }
        }
        
        return BatteryStatistics(
            maxPower: maxPower,
            minPower: minPower,
            averagePower: averagePower,
            totalDataPoints: dataPoints.count,
            chargingDataPoints: chargingPoints.count,
            powerByPercentage: powerByPercentageGrouped,
            powerDropPercentage: powerDropPercentage,
            maxPowerPercentage: maxPowerPercentage
        )
    }
    
    /// 获取功率随电量变化的详细数据（用于绘制图表）
    func getPowerByPercentageData(dataPoints: [BatteryDataPoint]) -> [(percentage: Int, averagePower: Double, sampleCount: Int)] {
        let chargingPoints = dataPoints.filter { $0.isCharging && $0.power > 0 }
        
        var powerByPercentage: [Int: [Double]] = [:]
        for point in chargingPoints {
            let pct = point.percentage
            if powerByPercentage[pct] == nil {
                powerByPercentage[pct] = []
            }
            powerByPercentage[pct]?.append(point.power)
        }
        
        var result: [(percentage: Int, averagePower: Double, sampleCount: Int)] = []
        for (pct, powerValues) in powerByPercentage.sorted(by: { $0.key > $1.key }) {
            let avgPower = powerValues.reduce(0, +) / Double(powerValues.count)
            result.append((percentage: pct, averagePower: avgPower, sampleCount: powerValues.count))
        }
        
        return result
    }
}

