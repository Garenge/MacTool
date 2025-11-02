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
        
        // 如果没有数据，显示提示
        if dataPoints.isEmpty {
            drawNoDataMessage(context: context)
            return
        }
        
        // 缓存计算值
        chartRect = getChartRect()
        prepareData()
        
        // 绘制网格
        drawGrid(context: context, rect: chartRect)
        
        // 绘制曲线
        drawPowerCurve(context: context, rect: chartRect)
        
        // 绘制悬停点
        if let hoveredPoint = hoveredPoint {
            drawHoveredPoint(context: context, point: hoveredPoint, rect: chartRect)
        }
        
        // 绘制坐标轴标签
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
        
        // X轴是功率，Y轴是时间
        // 绘制区域填充
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.1).cgColor)
        context.beginPath()
        
        // 起点
        let firstPoint = chargingPoints.first!
        let firstX = rect.minX + CGFloat((firstPoint.power - minPower) / powerDiff) * rect.width
        let firstY = rect.minY + CGFloat((firstPoint.timestamp.timeIntervalSince1970 - startTime) / timeDiff) * rect.height
        context.move(to: CGPoint(x: rect.minX, y: firstY))
        context.addLine(to: CGPoint(x: firstX, y: firstY))
        
        // 连接所有点
        for point in chargingPoints {
            let x = rect.minX + CGFloat((point.power - minPower) / powerDiff) * rect.width
            let y = rect.minY + CGFloat((point.timestamp.timeIntervalSince1970 - startTime) / timeDiff) * rect.height
            context.addLine(to: CGPoint(x: x, y: y))
        }
        
        // 终点
        let lastPoint = chargingPoints.last!
        let lastY = rect.minY + CGFloat((lastPoint.timestamp.timeIntervalSince1970 - startTime) / timeDiff) * rect.height
        context.addLine(to: CGPoint(x: rect.minX, y: lastY))
        context.closePath()
        context.fillPath()
        
        // 绘制曲线
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        
        context.beginPath()
        let startPoint = chargingPoints.first!
        let startX = rect.minX + CGFloat((startPoint.power - minPower) / powerDiff) * rect.width
        let startY = rect.minY + CGFloat((startPoint.timestamp.timeIntervalSince1970 - startTime) / timeDiff) * rect.height
        context.move(to: CGPoint(x: startX, y: startY))
        
        for point in chargingPoints.dropFirst() {
            let x = rect.minX + CGFloat((point.power - minPower) / powerDiff) * rect.width
            let y = rect.minY + CGFloat((point.timestamp.timeIntervalSince1970 - startTime) / timeDiff) * rect.height
            context.addLine(to: CGPoint(x: x, y: y))
        }
        
        context.strokePath()
        
        // 绘制数据点
        context.setFillColor(NSColor.systemBlue.cgColor)
        let pointRadius: CGFloat = 3
        
        for point in chargingPoints {
            let x = rect.minX + CGFloat((point.power - minPower) / powerDiff) * rect.width
            let y = rect.minY + CGFloat((point.timestamp.timeIntervalSince1970 - startTime) / timeDiff) * rect.height
            context.fillEllipse(in: NSRect(x: x - pointRadius, y: y - pointRadius, width: pointRadius * 2, height: pointRadius * 2))
        }
    }
    
    private func prepareData() {
        // 准备数据：只使用充电中的数据
        chargingPoints = dataPoints.filter { $0.isCharging && $0.power > 0 }
        
        // 功率范围（最小值设为0，从底部开始）
        let maxPower = chargingPoints.map { $0.power }.max() ?? 100
        powerRange = (
            min: 0,  // 始终从0开始
            max: maxPower * 1.1  // 留一些顶部空间
        )
        
        // 时间范围
        timeRange = (
            start: chargingPoints.first?.timestamp.timeIntervalSince1970 ?? 0,
            end: chargingPoints.last?.timestamp.timeIntervalSince1970 ?? 1
        )
    }
    
    private func drawHoveredPoint(context: CGContext, point: BatteryDataPoint, rect: NSRect) {
        let powerDiff = powerRange.max - powerRange.min
        let x = rect.minX + CGFloat((point.power - powerRange.min) / max(powerDiff, 1.0)) * rect.width
        let y = rect.minY + CGFloat((point.timestamp.timeIntervalSince1970 - timeRange.start) / (timeRange.end - timeRange.start)) * rect.height
        
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
        guard !chargingPoints.isEmpty else { return }
        
        // 功率范围和时间范围已缓存
        let minPower = powerRange.min
        let maxPower = powerRange.max
        let startTime = timeRange.start
        let endTime = timeRange.end
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        // X轴是功率（底部）
        for i in 0...gridLineCount {
            let value = minPower + (maxPower - minPower) * CGFloat(i) / CGFloat(gridLineCount)
            let string = String(format: "%.1f W", value)
            let attributedString = NSAttributedString(string: string, attributes: attributes)
            let stringSize = attributedString.size()
            let x = rect.minX + CGFloat(i) * (rect.width / CGFloat(gridLineCount))
            let point = NSPoint(x: x - stringSize.width / 2, y: padding - stringSize.height - 8)
            attributedString.draw(at: point)
        }
        
        // Y轴是时间（左侧）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        let labelCount = min(5, gridLineCount + 1)
        for i in 0..<labelCount {
            let progress = CGFloat(i) / CGFloat(labelCount - 1)
            let time = endTime - (endTime - startTime) * progress
            let date = Date(timeIntervalSince1970: time)
            let string = dateFormatter.string(from: date)
            let attributedString = NSAttributedString(string: string, attributes: attributes)
            let stringSize = attributedString.size()
            let y = rect.minY + progress * rect.height
            let point = NSPoint(x: padding - stringSize.width - 8, y: y - stringSize.height / 2)
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
            let powerDiff = powerRange.max - powerRange.min
            let x = chartRect.minX + CGFloat((point.power - powerRange.min) / max(powerDiff, 1.0)) * chartRect.width
            let y = chartRect.minY + CGFloat((point.timestamp.timeIntervalSince1970 - timeRange.start) / (timeRange.end - timeRange.start)) * chartRect.height
            
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

