//
//  ColorBackgroundView.swift
//  MacTool
//
//  支持动态颜色的背景视图
//

import Cocoa

class ColorBackgroundView: NSView {
    
    var fillColor: NSColor = .clear {
        didSet {
            needsDisplay = true
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false  // 不使用 layer
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 使用 NSColor 直接绘制，支持动态颜色
        fillColor.setFill()
        dirtyRect.fill()
    }
    
    override var isOpaque: Bool {
        return true
    }
}
