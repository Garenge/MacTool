//
//  MainWindowController.swift
//  MacTool
//
//  窗口控制器 - 负责保存和恢复窗口大小和位置
//

import Cocoa

class MainWindowController: NSWindowController, NSWindowDelegate {
    
    // MARK: - Lifecycle
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // 设置窗口代理
        window?.delegate = self
        
        // 启用窗口恢复
        window?.isRestorable = true
        
        // 设置窗口的自动保存名称（用于保存位置和大小）
        window?.setFrameAutosaveName("MainWindow")
        
        // 从 UserDefaults 恢复窗口大小（作为备份方案）
        restoreWindowFrame()
        
        print("📐 MainWindowController: 窗口已加载")
    }
    
    // MARK: - Window State Management
    
    /// 恢复窗口大小和位置
    private func restoreWindowFrame() {
        guard let window = window else { return }
        
        // 如果有保存的窗口框架，恢复它
        if let frameString = UserDefaults.standard.string(forKey: "MainWindowFrame"),
           let frame = NSRectFromString(frameString) as NSRect? {
            
            // 验证框架是否在屏幕范围内
            if isFrameValid(frame) {
                window.setFrame(frame, display: true)
                print("📐 恢复窗口大小: \(frame.size.width) x \(frame.size.height)")
            }
        }
    }
    
    /// 保存窗口大小和位置
    private func saveWindowFrame() {
        guard let window = window else { return }
        
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: "MainWindowFrame")
        
        print("💾 保存窗口大小: \(window.frame.size.width) x \(window.frame.size.height)")
    }
    
    /// 验证窗口框架是否有效（在屏幕范围内）
    private func isFrameValid(_ frame: NSRect) -> Bool {
        guard let screen = NSScreen.main else { return false }
        
        let screenFrame = screen.visibleFrame
        
        // 检查窗口是否至少有一部分在屏幕内
        return frame.intersects(screenFrame) &&
               frame.width > 100 &&
               frame.height > 100
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // 窗口关闭前保存大小和位置
        saveWindowFrame()
        print("👋 MainWindowController: 窗口即将关闭")
    }
    
    func windowDidResize(_ notification: Notification) {
        // 实时保存窗口大小（可选，避免频繁写入）
        // saveWindowFrame()
    }
    
    func windowDidMove(_ notification: Notification) {
        // 实时保存窗口位置（可选，避免频繁写入）
        // saveWindowFrame()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 允许窗口关闭
        return true
    }
    
    // MARK: - State Restoration (macOS 自动恢复机制)
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        // 保存额外的状态信息（如果需要）
        if let window = window {
            coder.encode(NSStringFromRect(window.frame), forKey: "windowFrame")
        }
    }
    
    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        
        // 恢复额外的状态信息（如果需要）
        if let frameString = coder.decodeObject(forKey: "windowFrame") as? String,
           let frame = NSRectFromString(frameString) as NSRect?,
           let window = window,
           isFrameValid(frame) {
            window.setFrame(frame, display: false)
        }
    }
    
    // MARK: - Public Methods
    
    /// 重置窗口到默认大小
    func resetToDefaultSize() {
        guard let window = window else { return }
        
        let defaultSize = NSSize(width: 800, height: 600)
        var frame = window.frame
        frame.size = defaultSize
        
        window.setFrame(frame, display: true, animate: true)
        saveWindowFrame()
        
        print("🔄 窗口已重置到默认大小: 800 x 600")
    }
}

