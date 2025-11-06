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
        
        // 绘制区域填充（使用平滑曲线）
        if points.count > 1 {
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.1).cgColor)
            context.beginPath()
            
            // 起点（从底部开始）
            context.move(to: CGPoint(x: points[0].x, y: rect.minY))
            context.addLine(to: points[0])
            
            // 使用改进的贝塞尔曲线连接所有点（更平滑）
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
                context.addCurve(to: p1, control1: cp1, control2: cp2)
                
                let cp3 = CGPoint(
                    x: p1.x + (p2.x - p1.x) * 0.3,
                    y: p1.y + (p2.y - p1.y) * 0.3
                )
                let cp4 = CGPoint(
                    x: p2.x - (p2.x - p1.x) * 0.3,
                    y: p2.y - (p2.y - p1.y) * 0.3
                )
                context.addCurve(to: p2, control1: cp3, control2: cp4)
            } else {
                // 4个及以上点使用 Hermite 插值（非常平滑）
                for i in 0..<(points.count - 1) {
                    let p0 = i > 0 ? points[i - 1] : points[i]
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    let p3 = i < points.count - 2 ? points[i + 2] : points[i + 1]
                    
                    // 计算切线（Catmull-Rom 风格）
                    let tension: CGFloat = 0.8  // 0.8 = 更平滑，0.5 = 标准 Catmull-Rom
                    
                    let m1x = (p2.x - p0.x) * tension
                    let m1y = (p2.y - p0.y) * tension
                    let m2x = (p3.x - p1.x) * tension
                    let m2y = (p3.y - p1.y) * tension
                    
                    let cp1 = CGPoint(
                        x: p1.x + m1x / 3.0,
                        y: p1.y + m1y / 3.0
                    )
                    let cp2 = CGPoint(
                        x: p2.x - m2x / 3.0,
                        y: p2.y - m2y / 3.0
                    )
                    
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
                context.addCurve(to: p1, control1: cp1, control2: cp2)
                
                let cp3 = CGPoint(
                    x: p1.x + (p2.x - p1.x) * 0.3,
                    y: p1.y + (p2.y - p1.y) * 0.3
                )
                let cp4 = CGPoint(
                    x: p2.x - (p2.x - p1.x) * 0.3,
                    y: p2.y - (p2.y - p1.y) * 0.3
                )
                context.addCurve(to: p2, control1: cp3, control2: cp4)
            } else {
                // 4个及以上点使用 Hermite 插值（非常平滑）
                for i in 0..<(points.count - 1) {
                    let p0 = i > 0 ? points[i - 1] : points[i]
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    let p3 = i < points.count - 2 ? points[i + 2] : points[i + 1]
                    
                    // 计算切线（Catmull-Rom 风格）
                    let tension: CGFloat = 0.8  // 0.8 = 更平滑，0.5 = 标准 Catmull-Rom
                    
                    let m1x = (p2.x - p0.x) * tension
                    let m1y = (p2.y - p0.y) * tension
                    let m2x = (p3.x - p1.x) * tension
                    let m2y = (p3.y - p1.y) * tension
                    
                    let cp1 = CGPoint(
                        x: p1.x + m1x / 3.0,
                        y: p1.y + m1y / 3.0
                    )
                    let cp2 = CGPoint(
                        x: p2.x - m2x / 3.0,
                        y: p2.y - m2y / 3.0
                    )
                    
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
    }
    
    private func prepareData() {
        // 准备数据：显示所有数据点（包括功率为0的），以便看到完整的时间线
        chargingPoints = dataPoints
        
        let now = Date().timeIntervalSince1970
        
        if chargingPoints.isEmpty {
            // 如果没有数据，设置默认范围
            timeRange = (
                start: now - 3600,  // 最近1小时
                end: now
            )
            powerRange = (
                min: 0,
                max: 30.0  // 默认最大值30W（可根据需要调整）
            )
        } else {
            // 功率范围（最小值设为0，从底部开始）
            let maxPower = chargingPoints.map { $0.power }.max() ?? 30.0
            powerRange = (
                min: 0,  // 始终从0开始
                max: max(maxPower * 1.1, 10.0)  // 留一些顶部空间，最小10W以便显示
            )
            
            // 时间范围：如果数据点时间范围小于1小时，扩展到1小时
            let dataStartTime = chargingPoints.first?.timestamp.timeIntervalSince1970 ?? now - 3600
            let dataEndTime = chargingPoints.last?.timestamp.timeIntervalSince1970 ?? now
            
            // 确保时间范围至少是最近1小时
            let oneHourAgo = now - 3600
            timeRange = (
                start: min(dataStartTime, oneHourAgo),
                end: max(dataEndTime, now)
            )
        }
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

