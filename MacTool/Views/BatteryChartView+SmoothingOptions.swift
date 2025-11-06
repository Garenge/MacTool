//
//  BatteryChartView+SmoothingOptions.swift
//  MacTool
//
//  曲线平滑选项扩展
//

import Cocoa

extension BatteryChartView {
    
    /// 平滑曲线类型
    enum SmoothingType {
        case none           // 无平滑，直线连接
        case light          // 轻度平滑
        case medium         // 中度平滑（当前使用）
        case heavy          // 重度平滑
        case catmullRom     // Catmull-Rom 样条曲线
    }
    
    /// 根据平滑类型获取控制点参数
    static func getSmoothingFactors(type: SmoothingType) -> (tension: CGFloat, continuity: CGFloat) {
        switch type {
        case .none:
            return (0.0, 0.0)
        case .light:
            return (0.3, 0.3)
        case .medium:
            return (0.5, 0.5)
        case .heavy:
            return (0.7, 0.7)
        case .catmullRom:
            return (0.5, 0.0)  // Catmull-Rom 特殊参数
        }
    }
    
    /// 使用 Catmull-Rom 样条曲线绘制（高级平滑算法）
    /// 这种曲线会经过所有数据点，且更加平滑自然
    static func drawCatmullRomCurve(context: CGContext, points: [CGPoint], alpha: CGFloat = 0.5) {
        guard points.count > 1 else { return }
        
        if points.count == 2 {
            context.addLine(to: points[1])
            return
        }
        
        // 对于 Catmull-Rom 样条，我们需要至少4个点
        // 对于边界情况，我们复制第一个和最后一个点
        var extendedPoints = points
        extendedPoints.insert(points[0], at: 0)  // 复制第一个点
        extendedPoints.append(points[points.count - 1])  // 复制最后一个点
        
        // 绘制每一段曲线
        for i in 1..<(extendedPoints.count - 2) {
            let p0 = extendedPoints[i - 1]
            let p1 = extendedPoints[i]
            let p2 = extendedPoints[i + 1]
            let p3 = extendedPoints[i + 2]
            
            // 计算时间参数（用于 Catmull-Rom）
            let t0: CGFloat = 0.0
            let t1 = t0 + pow(distance(p0, p1), alpha)
            let t2 = t1 + pow(distance(p1, p2), alpha)
            let t3 = t2 + pow(distance(p2, p3), alpha)
            
            // 计算控制点
            let m1 = (p2 - p0) / (t2 - t0) - (p1 - p0) / (t1 - t0) + (p1 - p0) / (t1 - t0)
            let m2 = (p3 - p1) / (t3 - t1) - (p2 - p1) / (t2 - t1) + (p2 - p1) / (t2 - t1)
            
            let c1 = p1 + m1 * (t2 - t1) / 3.0
            let c2 = p2 - m2 * (t2 - t1) / 3.0
            
            context.addCurve(to: p2, control1: c1, control2: c2)
        }
    }
    
    /// 计算两点间距离
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - CGPoint 运算符扩展

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
        return CGPoint(x: point.x * scalar, y: point.y * scalar)
    }
    
    static func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
        return CGPoint(x: point.x / scalar, y: point.y / scalar)
    }
}

