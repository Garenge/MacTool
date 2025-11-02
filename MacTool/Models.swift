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
    
    var identifier: String {
        switch self {
        case .power:
            return "power"
        }
    }
    
    var title: String {
        switch self {
        case .power:
            return "充电功率"
        }
    }
    
    var icon: String {
        switch self {
        case .power:
            return "🔋"
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
    let temperature: Double?     // 温度
    
    /// 从 ioreg 命令输出解析
    static func parse(from output: String) -> BatteryDataPoint? {
        // 先判断是否在充电
        let isCharging = output.contains("IsCharging.*=.*Yes") || output.contains("\"IsCharging\" = Yes")
        
        // 解析电压 (Voltage字段，单位mV) - 无论是否充电都需要
        guard let voltage = extractValue(from: output, pattern: #"\n\s+"Voltage"\s*=\s*(\d+)"#), voltage > 0 else {
            print("[BatteryDataPoint] ❌ 电压解析失败或为0")
            return nil
        }
        
        // 解析电量百分比
        let percentage = extractIntValue(from: output, pattern: #"CurrentCapacity.*?=\s*(\d+)"#) ?? 0
        
        // 如果不在充电，直接返回（功率为0）
        if !isCharging {
            return BatteryDataPoint(
                timestamp: Date(),
                voltage: voltage,
                current: 0,
                power: 0,
                percentage: percentage,
                isCharging: false,
                temperature: nil
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
            temperature: nil
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
            temperature REAL
        );
        CREATE INDEX IF NOT EXISTS idx_timestamp ON BatteryDataPoint(timestamp);
        """
        
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, createTableSQL, nil, nil, &errMsg) != SQLITE_OK {
            print("[BatteryStorage] ❌ 创建表失败: \(String(cString: errMsg!))")
        } else {
            print("[BatteryStorage] ✅ 表结构已创建/验证")
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取数据库路径
    func getDatabasePath() -> URL {
        return getDatabaseURL()
    }
    
    /// 保存数据点
    func save(_ dataPoint: BatteryDataPoint) {
        let insertSQL = "INSERT INTO BatteryDataPoint (timestamp, voltage, current, power, percentage, isCharging, temperature) VALUES (?, ?, ?, ?, ?, ?, ?);"
        
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
        var querySQL = "SELECT timestamp, voltage, current, power, percentage, isCharging, temperature FROM BatteryDataPoint"
        
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
                
                let dataPoint = BatteryDataPoint(
                    timestamp: timestamp,
                    voltage: voltage,
                    current: current,
                    power: power,
                    percentage: percentage,
                    isCharging: isCharging,
                    temperature: temperature
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

