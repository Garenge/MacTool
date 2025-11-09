//
//  FlippedView.swift
//  MacTool
//
//  Created by Cascade on 2025/11/9.
//

import Cocoa

/// 翻转的视图类（坐标从顶部开始），随系统主题更新背景色
class FlippedView: NSView {
    override var isFlipped: Bool {
        return true  // 使坐标系统从顶部开始
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBackgroundForAppearance()
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundForAppearance()
    }
    
    private func updateBackgroundForAppearance() {
        wantsLayer = true
        let isDarkMode: Bool
        if #available(macOS 10.14, *) {
            isDarkMode = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDarkMode = false
        }
        layer?.backgroundColor = isDarkMode ? NSColor.textBackgroundColor.cgColor : NSColor.white.cgColor
    }
}
