//
//  StatisticsWindowController.swift
//  MacTool
//
//  Created by Cascade on 2025/11/9.
//

import Cocoa

/// 统计窗口控制器 - 管理窗口生命周期与主题更新
class StatisticsWindowController: NSWindowController, NSWindowDelegate {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
        setupObservers()
        updateAppearance()
    }
    
    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时自动清理
        print("[StatisticsWindowController] 📊 统计窗口即将关闭")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default.removeObserver(self)
        NSApp.removeObserver(self, forKeyPath: "effectiveAppearance")
        print("[StatisticsWindowController] 📊 窗口控制器已释放")
    }

    private func setupObservers() {
        NSApp.addObserver(
            self,
            forKeyPath: "effectiveAppearance",
            options: [.new, .old],
            context: nil
        )
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "effectiveAppearance" && object as? NSApplication == NSApp {
            DispatchQueue.main.async { [weak self] in
                self?.updateAppearance()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func updateAppearance() {
        guard let contentView = window?.contentView else { return }
        contentView.appearance = NSApp.effectiveAppearance
        contentView.wantsLayer = true
        let isDarkMode: Bool
        if #available(macOS 10.14, *) {
            isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDarkMode = false
        }
        contentView.layer?.backgroundColor = isDarkMode ? NSColor.textBackgroundColor.cgColor : NSColor.white.cgColor
        applyAppearanceRecursively(in: contentView)
    }
    
    private func applyAppearanceRecursively(in view: NSView) {
        if let scroll = view as? NSScrollView {
            scroll.backgroundColor = NSColor.textBackgroundColor
        }
        if view is FlippedView {
            view.wantsLayer = true
        }
        for sub in view.subviews {
            applyAppearanceRecursively(in: sub)
        }
    }
}
