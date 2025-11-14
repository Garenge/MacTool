//
//  ThemeManager.swift
//  MacTool
//
//  主题管理器 - 统一管理应用主题和颜色
//

import Cocoa

// MARK: - 主题类型

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"  // 跟随系统
    
    var displayName: String {
        switch self {
        case .light:
            return "浅色模式"
        case .dark:
            return "深色模式"
        case .auto:
            return "跟随系统"
        }
    }
    
    var icon: String {
        switch self {
        case .light:
            return "☀️"
        case .dark:
            return "🌙"
        case .auto:
            return "💻"
        }
    }
}

// MARK: - 主题颜色定义

struct ThemeColors {
    
    // MARK: - 背景色
    
    /// 主背景色
    static var backgroundColor: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.windowBackgroundColor
        } else {
            return NSColor.white
        }
    }
    
    /// 次级背景色（卡片、面板等）
    static var secondaryBackgroundColor: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.controlBackgroundColor
        } else {
            return NSColor(white: 0.95, alpha: 1.0)
        }
    }
    
    /// 自定义卡片背景（浅/深两套固定颜色）
    static var cardBackgroundLight: NSColor {
        return NSColor(calibratedRed: 240.0/255.0, green: 240.0/255.0, blue: 240.0/255.0, alpha: 1.0)
    }
    
    static var cardBackgroundDark: NSColor {
        return NSColor(calibratedRed: 60.0/255.0, green: 60.0/255.0, blue: 60.0/255.0, alpha: 1.0)
    }
    
    /// 按当前主题返回卡片背景色（避免 NSColor 动态颜色在转 CGColor 时解析不一致）
    static var cardBackground: NSColor {
        return ThemeManager.shared.isDarkMode ? cardBackgroundDark : cardBackgroundLight
    }
    
    /// 控制背景色
    static var controlBackgroundColor: NSColor {
        return NSColor.controlBackgroundColor
    }
    
    /// 文本背景色
    static var textBackgroundColor: NSColor {
        return NSColor.textBackgroundColor
    }
    
    // MARK: - 文本色
    
    /// 主文本色
    static var labelColor: NSColor {
        return NSColor.labelColor
    }
    
    /// 次级文本色
    static var secondaryLabelColor: NSColor {
        return NSColor.secondaryLabelColor
    }
    
    /// 三级文本色
    static var tertiaryLabelColor: NSColor {
        return NSColor.tertiaryLabelColor
    }
    
    static var primaryBackground: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.name == .darkAqua ? NSColor(calibratedWhite: 0.12, alpha: 1.0) : NSColor(calibratedWhite: 0.98, alpha: 1.0)
        }
    }
    
    static var secondaryBackground: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.name == .darkAqua ? NSColor(calibratedWhite: 0.18, alpha: 1.0) : NSColor(calibratedWhite: 0.95, alpha: 1.0)
        }
    }
    
    static var primaryText: NSColor {
        return NSColor.labelColor
    }
    
    static var secondaryText: NSColor {
        return NSColor.secondaryLabelColor
    }
    
    static var border: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.name == .darkAqua ? NSColor(white: 1.0, alpha: 0.12) : NSColor(white: 0.0, alpha: 0.12)
        }
    }
    
    static var accent: NSColor {
        return NSColor.controlAccentColor
    }
    
    // MARK: - 强调色
    
    /// 主题色（蓝色）
    static var accentColor: NSColor {
        return NSColor.systemBlue
    }
    
    /// 成功色（绿色）
    static var successColor: NSColor {
        return NSColor.systemGreen
    }
    
    /// 警告色（橙色）
    static var warningColor: NSColor {
        return NSColor.systemOrange
    }
    
    /// 错误色（红色）
    static var errorColor: NSColor {
        return NSColor.systemRed
    }
    
    // MARK: - 分隔线
    
    /// 分隔线颜色
    static var separatorColor: NSColor {
        return NSColor.separatorColor
    }
    
    // MARK: - 图表颜色
    
    /// 图表线条颜色
    static var chartLineColor: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.name == .darkAqua ? NSColor.systemBlue : NSColor.systemBlue
        }
    }
    
    /// 图表网格颜色
    static var chartGridColor: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.name == .darkAqua ? NSColor(white: 0.3, alpha: 0.3) : NSColor(white: 0.8, alpha: 0.3)
        }
    }
    
    /// 图表文本颜色
    static var chartTextColor: NSColor {
        return NSColor.labelColor
    }
    
    // MARK: - 侧边栏
    
    /// 侧边栏背景色
    static var sidebarBackgroundColor: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.controlBackgroundColor
        } else {
            return NSColor(white: 0.96, alpha: 1.0)
        }
    }
    
    /// 侧边栏选中背景色
    static var sidebarSelectionColor: NSColor {
        return NSColor.selectedContentBackgroundColor
    }
}

// MARK: - 主题管理器

class ThemeManager {
    
    static let shared = ThemeManager()
    
    // 主题变更通知
    static let themeDidChangeNotification = Notification.Name("ThemeDidChange")
    
    private let themeKey = "AppTheme"
    
    // 当前主题
    var currentTheme: AppTheme {
        get {
            if let themeString = UserDefaults.standard.string(forKey: themeKey),
               let theme = AppTheme(rawValue: themeString) {
                return theme
            }
            return .auto  // 默认跟随系统
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
            applyTheme(newValue)
            
            // 发送主题变更通知
            NotificationCenter.default.post(name: ThemeManager.themeDidChangeNotification, object: nil)
            
            print("[ThemeManager] 🎨 主题已切换到: \(newValue.displayName)")
        }
    }
    
    private init() {
        // 应用保存的主题
        applyTheme(currentTheme)
    }
    
    /// 应用主题
    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            NSApp.appearance = nil  // 跟随系统
        }
    }
    
    /// 获取当前是否为深色模式
    var isDarkMode: Bool {
        if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) {
            return appearance == .darkAqua
        }
        return false
    }
}
