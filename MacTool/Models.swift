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
struct BatteryDataPoint: Codable {
    let timestamp: Date
    let voltage: Double          // mV
    let current: Double          // mA
    let power: Double            // W
    let percentage: Int          // 电量百分比
    let isCharging: Bool
    let temperature: Double?     // 温度
    
    /// 从 ioreg 命令输出解析
    static func parse(from output: String) -> BatteryDataPoint? {
        // 解析功率
        guard let powerValue = extractPowerValue(from: output) else {
            return nil
        }
        
        // 解析电压 (Voltage字段，单位mV)
        let voltage = extractValue(from: output, pattern: #"\bVoltage.*?=\s*(\d+)"#) ?? 0.0
        
        // 解析电流 (InstantAmperage字段，单位mA)
        let current = extractValue(from: output, pattern: #"InstantAmperage.*?=\s*(\d+)"#) ?? 0.0
        
        // 解析电量百分比
        let percentage = extractIntValue(from: output, pattern: #"CurrentCapacity.*?=\s*(\d+)"#) ?? 0
        
        // 判断是否在充电
        let isCharging = output.contains("IsCharging.*=.*Yes") || output.contains("\"IsCharging\" = Yes")
        
        return BatteryDataPoint(
            timestamp: Date(),
            voltage: voltage,
            current: current,
            power: powerValue,
            percentage: percentage,
            isCharging: isCharging,
            temperature: nil
        )
    }
    
    // MARK: - Private Helpers
    
    private static func extractPowerValue(from output: String) -> Double? {
        let pattern = "([0-9]+\\.[0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: output.utf16.count)
        guard let match = regex.firstMatch(in: output, range: range) else { return nil }
        guard let numberRange = Range(match.range(at: 1), in: output) else { return nil }
        return Double(output[numberRange])
    }
    
    private static func extractValue(from output: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: output.utf16.count)
        guard let match = regex.firstMatch(in: output, range: range) else { return nil }
        guard let numberRange = Range(match.range(at: 1), in: output) else { return nil }
        return Double(output[numberRange])
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
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error deleting data")
            }
        }
        
        sqlite3_finalize(statement)
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
        let currentCount = count()
        if currentCount > maxDataPoints {
            let excessCount = currentCount - maxDataPoints
            let deleteSQL = "DELETE FROM BatteryDataPoint WHERE id IN (SELECT id FROM BatteryDataPoint ORDER BY timestamp ASC LIMIT ?);"
            
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(excessCount))
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
}

