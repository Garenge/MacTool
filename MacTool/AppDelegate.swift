//
//  AppDelegate.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // 保存主窗口控制器的引用
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        // 配置主窗口以支持状态保存
        configureMainWindow()
        
        // 启动功率监控
        PowerHelper.shared.start()
    }
    
    /// 配置主窗口
    private func configureMainWindow() {
        // 获取主窗口
        guard let mainWindow = NSApplication.shared.windows.first else {
            print("⚠️ 无法找到主窗口")
            return
        }
        
        // 创建自定义的窗口控制器
        let windowController = MainWindowController(window: mainWindow)
        windowController.windowDidLoad()
        
        // 保存引用
        mainWindowController = windowController
        
        print("✅ 主窗口已配置，支持状态保存")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        
        // 停止功率监控
        PowerHelper.shared.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

