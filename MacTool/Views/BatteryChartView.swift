//
//  BatteryChartView.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Cocoa

/// 充电功率曲线图
class BatteryChartView: NSView {
    
    // MARK: - Properties
    
    var dataPoints: [BatteryDataPoint] = [] {
        didSet {
            needsDisplay = true
        }
    }
    
    // 配置选项
    private let padding: CGFloat = 50
    private let gridLineCount: Int = 5
    private let maxVisiblePoints: Int = 300 // 最多显示的采样点数
    
    // 缓存计算属性
    private var chartRect: NSRect = .zero
    private var powerRange: (min: Double, max: Double) = (0, 100)
    private var timeRange: (start: TimeInterval, end: TimeInterval) = (0, 1)
    var customTimeRange: (start: TimeInterval, end: TimeInterval)?
    private var chargingPoints: [BatteryDataPoint] = []
    
    // 悬停点
    private var hoveredPoint: BatteryDataPoint?
    
    // MARK: - Lifecycle
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // 设置背景色
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 启用鼠标跟踪
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 绘制背景
        drawBackground(context: context, rect: dirtyRect)
        
        // 缓存计算值（即使没有数据也设置默认范围）
        chartRect = getChartRect()
        prepareData()
        
        // 绘制网格
        drawGrid(context: context, rect: chartRect)
        
        // 如果没有数据，显示提示信息
        if dataPoints.isEmpty {
            drawNoDataMessage(context: context)
        } else {
            // 绘制曲线
            drawPowerCurve(context: context, rect: chartRect)
            
            // 绘制悬停点
            if let hoveredPoint = hoveredPoint {
                drawHoveredPoint(context: context, point: hoveredPoint, rect: chartRect)
            }
        }
        
        // 始终绘制坐标轴标签（即使没有数据）
        drawAxisLabels(context: context, rect: chartRect)
    }
    
    // MARK: - Drawing Methods
    
    private func drawBackground(context: CGContext, rect: NSRect) {
        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(rect)
    }
    
    private func drawNoDataMessage(context: CGContext) {
        let message = "暂无数据"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let attributedString = NSAttributedString(string: message, attributes: attributes)
        let stringSize = attributedString.size()
        let point = NSPoint(
            x: bounds.midX - stringSize.width / 2,
            y: bounds.midY - stringSize.height / 2
        )
        attributedString.draw(at: point)
    }
    
    private func getChartRect() -> NSRect {
        return NSRect(
            x: padding,
            y: padding,
            width: bounds.width - padding * 2,
            height: bounds.height - padding * 2
        )
    }
    
    private func drawGrid(context: CGContext, rect: NSRect) {
        context.setStrokeColor(NSColor.gridColor.cgColor)
        context.setLineWidth(0.5)
        
        // 绘制水平网格线
        for i in 0...gridLineCount {
            let y = rect.minY + CGFloat(i) * (rect.height / CGFloat(gridLineCount))
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        
        // 绘制垂直网格线
        for i in 0...gridLineCount {
            let x = rect.minX + CGFloat(i) * (rect.width / CGFloat(gridLineCount))
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        
        context.strokePath()
    }
    
    private func drawPowerCurve(context: CGContext, rect: NSRect) {
        guard !chargingPoints.isEmpty else { return }
        
        // 使用缓存的功率和时间范围
        let minPower = powerRange.min
        let maxPower = powerRange.max
        let powerDiff = max(maxPower - minPower, 1.0) // 避免除零
        
        let startTime = timeRange.start
        let endTime = timeRange.end
        let timeDiff = max(endTime - startTime, 1) // 避免除零
        
        // X轴是时间，Y轴是功率（传统图表方式）
        // 转换数据点为CGPoint数组
        var points = chargingPoints.map { point -> CGPoint in
            let x = rect.minX + CGFloat((point.timestamp.timeIntervalSince1970 - startTime) / timeDiff) * rect.width
            let y = rect.minY + CGFloat((point.power - minPower) / powerDiff) * rect.height
            return CGPoint(x: x, y: y)
        }
        
        // 如果数据点太多，进行采样以获得更好的平滑效果
        // 关键：数据点越少，平滑效果越明显
        let maxPoints = 30  // 限制为30个点，使平滑效果更明显
        if points.count > maxPoints {
            let step = max(1, points.count / maxPoints)
            var sampledPoints: [CGPoint] = []
            for i in stride(from: 0, to: points.count, by: step) {
                sampledPoints.append(points[i])
            }
            // 确保包含最后一个点
            if let lastPoint = points.last, sampledPoints.last != lastPoint {
                sampledPoints.append(lastPoint)
            }
            points = sampledPoints
            print("📊 采样后数据点: \(points.count) (原始: \(chargingPoints.count))")
        } else {
            print("📊 数据点数量: \(points.count)")
        }
        
        // 设置裁剪区域，防止曲线超出底部（功率不能为负）
        context.saveGState()
        context.clip(to: rect)
        
        // 绘制区域填充（使用平滑曲线）
        if points.count > 1 {
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.1).cgColor)
            context.beginPath()
            
            // 起点（从底部开始）
            context.move(to: CGPoint(x: points[0].x, y: rect.minY))
            context.addLine(to: points[0])
            
            // 使用改进的贝塞尔曲线连接所有点（更平滑，且约束控制点防止交叉）
            if points.count == 2 {
                context.addLine(to: points[1])
            } else if points.count == 3 {
                // 3个点使用简单平滑
                let p0 = points[0]
                let p1 = points[1]
                let p2 = points[2]
                
                let cp1 = CGPoint(
                    x: p0.x + (p1.x - p0.x) * 0.7,
                    y: p0.y + (p1.y - p0.y) * 0.7
                )
                let cp2 = CGPoint(
                    x: p1.x - (p2.x - p1.x) * 0.3,
                    y: p1.y - (p2.y - p1.y) * 0.3
                )
                // 约束控制点在段内，减少过冲
                let minX12 = min(p0.x, p1.x)
                let maxX12 = max(p0.x, p1.x)
                let minY12 = min(p0.y, p1.y)
                let maxY12 = max(p0.y, p1.y)
                let minX23 = min(p1.x, p2.x)
                let maxX23 = max(p1.x, p2.x)
                let minY23 = min(p1.y, p2.y)
                let maxY23 = max(p1.y, p2.y)
                let clampedCp1 = CGPoint(
                    x: max(min(cp1.x, maxX12), minX12),
                    y: max(min(cp1.y, maxY12), minY12)
                )
                let clampedCp2 = CGPoint(
                    x: max(min(cp2.x, maxX23), minX23),
                    y: max(min(cp2.y, maxY23), minY23)
                )
                context.addCurve(to: p1, control1: clampedCp1, control2: clampedCp2)
                
                let cp3 = CGPoint(
                    x: p1.x + (p2.x - p1.x) * 0.3,
                    y: p1.y + (p2.y - p1.y) * 0.3
                )
                let cp4 = CGPoint(
                    x: p2.x - (p2.x - p1.x) * 0.3,
                    y: p2.y - (p2.y - p1.y) * 0.3
                )
                let clampedCp3 = CGPoint(
                    x: max(min(cp3.x, maxX23), minX23),
                    y: max(min(cp3.y, maxY23), minY23)
                )
                let clampedCp4 = CGPoint(
                    x: max(min(cp4.x, maxX23), minX23),
                    y: max(min(cp4.y, maxY23), minY23)
                )
                context.addCurve(to: p2, control1: clampedCp3, control2: clampedCp4)
            } else {
                // 4个及以上点使用 Hermite 插值（非常平滑）
                for i in 0..<(points.count - 1) {
                    let p0 = i > 0 ? points[i - 1] : points[i]
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    let p3 = i < points.count - 2 ? points[i + 2] : points[i + 1]
                    
                    // 计算切线（Catmull-Rom 风格）
                    let tension: CGFloat = 0.5  // 降低张力，减少过冲
                    
                    let m1x = (p2.x - p0.x) * tension
                    let m1y = (p2.y - p0.y) * tension
                    let m2x = (p3.x - p1.x) * tension
                    let m2y = (p3.y - p1.y) * tension
                    
                    var cp1 = CGPoint(
                        x: p1.x + m1x / 3.0,
                        y: p1.y + m1y / 3.0
                    )
                    var cp2 = CGPoint(
                        x: p2.x - m2x / 3.0,
                        y: p2.y - m2y / 3.0
                    )
                    // 约束控制点在当前段 [p1,p2] 的包围盒内，保证 X 方向单调，避免回折
                    let minX = min(p1.x, p2.x)
                    let maxX = max(p1.x, p2.x)
                    let minY = min(p1.y, p2.y)
                    let maxY = max(p1.y, p2.y)
                    cp1.x = max(min(cp1.x, maxX), minX)
                    cp2.x = max(min(cp2.x, maxX), minX)
                    cp1.y = max(min(cp1.y, maxY), minY)
                    cp2.y = max(min(cp2.y, maxY), minY)
                    
                    context.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }
            
            // 终点（回到底部）
            context.addLine(to: CGPoint(x: points.last!.x, y: rect.minY))
            context.closePath()
            context.fillPath()
        }
        
        // 绘制平滑曲线（使用贝塞尔曲线）
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.5)  // 增加线条宽度，使曲线更明显
        context.setLineJoin(.round)
        context.setLineCap(.round)
        
        // 启用高质量渲染
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        // 使用平滑曲线绘制（复用之前计算的points数组）
        if points.count > 1 {
            context.beginPath()
            context.move(to: points[0])
            
            if points.count == 2 {
                // 只有两个点,直接连线
                context.addLine(to: points[1])
            } else if points.count == 3 {
                // 3个点使用简单平滑
                let p0 = points[0]
                let p1 = points[1]
                let p2 = points[2]
                
                let cp1 = CGPoint(
                    x: p0.x + (p1.x - p0.x) * 0.7,
                    y: p0.y + (p1.y - p0.y) * 0.7
                )
                let cp2 = CGPoint(
                    x: p1.x - (p2.x - p1.x) * 0.3,
                    y: p1.y - (p2.y - p1.y) * 0.3
                )
                let minX12 = min(p0.x, p1.x)
                let maxX12 = max(p0.x, p1.x)
                let minY12 = min(p0.y, p1.y)
                let maxY12 = max(p0.y, p1.y)
                let minX23 = min(p1.x, p2.x)
                let maxX23 = max(p1.x, p2.x)
                let minY23 = min(p1.y, p2.y)
                let maxY23 = max(p1.y, p2.y)
                let clampedCp1 = CGPoint(
                    x: max(min(cp1.x, maxX12), minX12),
                    y: max(min(cp1.y, maxY12), minY12)
                )
                let clampedCp2 = CGPoint(
                    x: max(min(cp2.x, maxX23), minX23),
                    y: max(min(cp2.y, maxY23), minY23)
                )
                context.addCurve(to: p1, control1: clampedCp1, control2: clampedCp2)
                
                let cp3 = CGPoint(
                    x: p1.x + (p2.x - p1.x) * 0.3,
                    y: p1.y + (p2.y - p1.y) * 0.3
                )
                let cp4 = CGPoint(
                    x: p2.x - (p2.x - p1.x) * 0.3,
                    y: p2.y - (p2.y - p1.y) * 0.3
                )
                let clampedCp3 = CGPoint(
                    x: max(min(cp3.x, maxX23), minX23),
                    y: max(min(cp3.y, maxY23), minY23)
                )
                let clampedCp4 = CGPoint(
                    x: max(min(cp4.x, maxX23), minX23),
                    y: max(min(cp4.y, maxY23), minY23)
                )
                context.addCurve(to: p2, control1: clampedCp3, control2: clampedCp4)
            } else {
                // 4个及以上点使用 Hermite 插值（非常平滑）
                for i in 0..<(points.count - 1) {
                    let p0 = i > 0 ? points[i - 1] : points[i]
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    let p3 = i < points.count - 2 ? points[i + 2] : points[i + 1]
                    
                    // 计算切线（Catmull-Rom 风格）
                    let tension: CGFloat = 0.5  // 降低张力，减少过冲
                    
                    let m1x = (p2.x - p0.x) * tension
                    let m1y = (p2.y - p0.y) * tension
                    let m2x = (p3.x - p1.x) * tension
                    let m2y = (p3.y - p1.y) * tension
                    
                    var cp1 = CGPoint(
                        x: p1.x + m1x / 3.0,
                        y: p1.y + m1y / 3.0
                    )
                    var cp2 = CGPoint(
                        x: p2.x - m2x / 3.0,
                        y: p2.y - m2y / 3.0
                    )
                    // 约束控制点在当前段 [p1,p2] 的包围盒内，保证 X 方向单调，避免回折
                    let minX = min(p1.x, p2.x)
                    let maxX = max(p1.x, p2.x)
                    let minY = min(p1.y, p2.y)
                    let maxY = max(p1.y, p2.y)
                    cp1.x = max(min(cp1.x, maxX), minX)
                    cp2.x = max(min(cp2.x, maxX), minX)
                    cp1.y = max(min(cp1.y, maxY), minY)
                    cp2.y = max(min(cp2.y, maxY), minY)
                    
                    context.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }
            
            context.strokePath()
        }
        
        // 绘制数据点（仅在采样后数据点较少时显示）
        // 数据点太多会显得杂乱，影响曲线的流畅视觉效果
        if points.count <= 20 {
            context.setFillColor(NSColor.systemBlue.cgColor)
            let pointRadius: CGFloat = 3
            
            for point in points {
                context.fillEllipse(in: NSRect(x: point.x - pointRadius, y: point.y - pointRadius, width: pointRadius * 2, height: pointRadius * 2))
            }
        }
        
        // 恢复图形状态（移除裁剪）
        context.restoreGState()
    }
    
    private func prepareData() {
        // 准备数据：显示所有数据点（包括功率为0的），以便看到完整的时间线
        // 确保按时间排序，避免曲线回折导致的交叉
        let sortedPoints = dataPoints.sorted { $0.timestamp < $1.timestamp }
        
        let now = Date().timeIntervalSince1970
        
        if sortedPoints.isEmpty {
            // 如果没有数据，设置默认范围
            if let custom = customTimeRange {
                timeRange = custom
            } else {
                timeRange = (
                    start: now - 3600,  // 最近1小时
                    end: now
                )
            }
            powerRange = (
                min: 0,
                max: 30.0  // 默认最大值30W（可根据需要调整）
            )
            chargingPoints = []
        } else {
            // 先确定时间范围（优先使用自定义范围）
            if let custom = customTimeRange {
                timeRange = custom
            } else {
                let dataStartTime = sortedPoints.first!.timestamp.timeIntervalSince1970
                let dataEndTime = sortedPoints.last!.timestamp.timeIntervalSince1970
                let oneHourAgo = now - 3600
                timeRange = (
                    start: min(dataStartTime, oneHourAgo),
                    end: max(dataEndTime, now)
                )
            }
            
            // 根据时间范围进行分桶重采样，限制总点数，并对空白时间段补零
            let resampled = resample(points: sortedPoints, start: timeRange.start, end: timeRange.end)
            chargingPoints = resampled
            
            // 根据重采样后的数据计算功率范围（最小值固定为0）
            let maxPower = chargingPoints.map { $0.power }.max() ?? 30.0
            powerRange = (
                min: 0,
                max: max(maxPower * 1.1, 10.0)
            )
        }
    }

    /// 将原始数据按时间分桶重采样，限制总点数并填补空白区间
    private func resample(points: [BatteryDataPoint], start: TimeInterval, end: TimeInterval) -> [BatteryDataPoint] {
        guard end > start else { return points }
        let duration = end - start
        // 选择桶宽（秒）
        let bucket: TimeInterval
        if duration <= 3600 { // 1小时
            bucket = 30 // 30秒/点 ~120点
        } else if duration <= 24*3600 { // 24小时
            bucket = 120 // 2分钟/点 ~720点
        } else if duration <= 7*24*3600 { // 7天
            bucket = 600 // 10分钟/点
        } else {
            // 目标最多 ~800 点
            bucket = max(1, duration / 800.0)
        }
        
        // 构建桶
        let bucketCount = max(1, Int(ceil(duration / bucket)))
        var buckets: [[BatteryDataPoint]] = Array(repeating: [], count: bucketCount)
        
        // 将点分配到桶
        for p in points {
            let t = p.timestamp.timeIntervalSince1970
            if t < start || t > end { continue }
            var idx = Int((t - start) / bucket)
            if idx >= bucketCount { idx = bucketCount - 1 }
            if idx < 0 { idx = 0 }
            buckets[idx].append(p)
        }
        
        var result: [BatteryDataPoint] = []
        result.reserveCapacity(bucketCount)
        var lastPercentage: Int = points.last?.percentage ?? 0
        
        for i in 0..<bucketCount {
            let bucketStart = start + Double(i) * bucket
            let bucketMid = bucketStart + bucket/2
            let items = buckets[i]
            if items.isEmpty {
                // 空白桶：补零点
                let dp = BatteryDataPoint(
                    timestamp: Date(timeIntervalSince1970: bucketMid),
                    voltage: 0,
                    current: 0,
                    power: 0,
                    percentage: lastPercentage,
                    isCharging: false,
                    temperature: nil,
                    cycleCount: nil,
                    designCapacity: nil,
                    maxCapacity: nil,
                    batteryHealth: nil
                )
                result.append(dp)
            } else {
                // 聚合：取平均功率、平均电压/电流，电量用平均四舍五入
                let count = Double(items.count)
                let avgPower = items.reduce(0.0) { $0 + $1.power } / count
                let avgVoltage = items.reduce(0.0) { $0 + $1.voltage } / count
                let avgCurrent = items.reduce(0.0) { $0 + $1.current } / count
                let avgPct = Int((items.reduce(0.0) { $0 + Double($1.percentage) } / count).rounded())
                lastPercentage = avgPct
                let anyCharging = items.contains(where: { $0.isCharging && $0.power > 0 })
                let dp = BatteryDataPoint(
                    timestamp: Date(timeIntervalSince1970: bucketMid),
                    voltage: avgVoltage,
                    current: avgCurrent,
                    power: max(0, avgPower),
                    percentage: avgPct,
                    isCharging: anyCharging,
                    temperature: nil,
                    cycleCount: nil,
                    designCapacity: nil,
                    maxCapacity: nil,
                    batteryHealth: nil
                )
                result.append(dp)
            }
        }
        return result
    }
    
    private func drawHoveredPoint(context: CGContext, point: BatteryDataPoint, rect: NSRect) {
        let x = rect.minX + CGFloat((point.timestamp.timeIntervalSince1970 - timeRange.start) / (timeRange.end - timeRange.start)) * rect.width
        let powerDiff = powerRange.max - powerRange.min
        let y = rect.minY + CGFloat((point.power - powerRange.min) / max(powerDiff, 1.0)) * rect.height
        
        // 绘制交叉线
        context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [5, 5])
        
        context.beginPath()
        context.move(to: CGPoint(x: x, y: rect.minY))
        context.addLine(to: CGPoint(x: x, y: rect.maxY))
        context.move(to: CGPoint(x: rect.minX, y: y))
        context.addLine(to: CGPoint(x: rect.maxX, y: y))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
        
        // 绘制数据点
        context.setFillColor(NSColor.systemOrange.cgColor)
        let pointRadius: CGFloat = 5
        context.fillEllipse(in: NSRect(x: x - pointRadius, y: y - pointRadius, width: pointRadius * 2, height: pointRadius * 2))
        
        // 绘制提示框
        drawTooltip(context: context, point: point, x: x, y: y, rect: rect)
    }
    
    private func drawTooltip(context: CGContext, point: BatteryDataPoint, x: CGFloat, y: CGFloat, rect: NSRect) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        
        let powerText = String(format: "%.2f W", point.power)
        let timeText = dateFormatter.string(from: point.timestamp)
        let percentageText = "\(point.percentage)%"
        
        let tooltipText = """
        \(powerText)
        \(timeText)
        \(percentageText)
        """
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor
        ]
        let attributedString = NSAttributedString(string: tooltipText, attributes: attributes)
        let size = attributedString.size()
        
        let padding: CGFloat = 8
        let boxSize = NSSize(width: size.width + padding * 2, height: size.height + padding * 2)
        
        // 计算提示框位置（避免超出边界）
        var boxOrigin = NSPoint(x: x + 10, y: y + 10)
        if boxOrigin.x + boxSize.width > rect.maxX {
            boxOrigin.x = x - boxSize.width - 10
        }
        if boxOrigin.y + boxSize.height > rect.maxY {
            boxOrigin.y = y - boxSize.height - 10
        }
        
        // 绘制背景
        context.setFillColor(NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor)
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(1.0)
        
        let boxRect = NSRect(origin: boxOrigin, size: boxSize)
        let radius: CGFloat = 6
        let path = CGMutablePath()
        path.addRoundedRect(in: boxRect, cornerWidth: radius, cornerHeight: radius)
        context.addPath(path)
        context.fillPath()
        context.addPath(path)
        context.strokePath()
        
        // 绘制文本
        let textPoint = NSPoint(x: boxOrigin.x + padding, y: boxOrigin.y + padding)
        attributedString.draw(at: textPoint)
    }
    
    private func drawAxisLabels(context: CGContext, rect: NSRect) {
        // 功率范围和时间范围已缓存（即使没有数据也已设置默认值）
        let minPower = powerRange.min
        let maxPower = powerRange.max
        let startTime = timeRange.start
        let endTime = timeRange.end
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        // Y轴是功率（左侧，顶部为最大值，底部为0）
        for i in 0...gridLineCount {
            let value = minPower + (maxPower - minPower) * CGFloat(i) / CGFloat(gridLineCount)
            let string = String(format: "%.1f W", value)
            let attributedString = NSAttributedString(string: string, attributes: attributes)
            let stringSize = attributedString.size()
            let y = rect.minY + CGFloat(i) * (rect.height / CGFloat(gridLineCount))
            let point = NSPoint(x: padding - stringSize.width - 8, y: y - stringSize.height / 2)
            attributedString.draw(at: point)
        }
        
        // X轴是时间（底部）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        let labelCount = min(5, gridLineCount + 1)
        for i in 0..<labelCount {
            let progress = CGFloat(i) / CGFloat(labelCount - 1)
            let time = startTime + (endTime - startTime) * progress
            let date = Date(timeIntervalSince1970: time)
            let string = dateFormatter.string(from: date)
            let attributedString = NSAttributedString(string: string, attributes: attributes)
            let stringSize = attributedString.size()
            let x = rect.minX + progress * rect.width
            let point = NSPoint(x: x - stringSize.width / 2, y: padding - stringSize.height - 8)
            attributedString.draw(at: point)
        }
    }
    
    // MARK: - Mouse Tracking
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        updateHoveredPoint(at: location)
    }
    
    override func mouseExited(with event: NSEvent) {
        hoveredPoint = nil
        needsDisplay = true
    }
    
    private func updateHoveredPoint(at location: NSPoint) {
        guard !chargingPoints.isEmpty else {
            hoveredPoint = nil
            needsDisplay = true
            return
        }
        
        // 查找最近的数据点
        let hitRadius: CGFloat = 10
        var closestPoint: BatteryDataPoint?
        var closestDistance: CGFloat = hitRadius
        
        for point in chargingPoints {
            let x = chartRect.minX + CGFloat((point.timestamp.timeIntervalSince1970 - timeRange.start) / (timeRange.end - timeRange.start)) * chartRect.width
            let powerDiff = powerRange.max - powerRange.min
            let y = chartRect.minY + CGFloat((point.power - powerRange.min) / max(powerDiff, 1.0)) * chartRect.height
            
            let distance = sqrt(pow(location.x - x, 2) + pow(location.y - y, 2))
            if distance < closestDistance {
                closestDistance = distance
                closestPoint = point
            }
        }
        
        if hoveredPoint != closestPoint {
            hoveredPoint = closestPoint
            needsDisplay = true
        }
    }
}

// MARK: - Helper Extension

extension NSColor {
    static var gridColor: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.separatorColor
        } else {
            return NSColor.lightGray
        }
    }
}

