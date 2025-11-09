//
//  ContentViewController.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Cocoa

class ContentViewController: NSViewController {
    
    // MARK: - Properties
    
    private var containerView: NSView!
    private var currentViewController: NSViewController?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupContainer()
        setupObservers()
        setupThemeObserver()
        showDefaultView()
        updateColors()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        print("[ContentViewController] 📝 内容容器页面已显示")
    }
    
    // MARK: - Setup
    
    private func setupContainer() {
        // 启用 layer 以支持背景色
        view.wantsLayer = true
        view.layer?.backgroundColor = ThemeColors.backgroundColor.cgColor
        
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = ThemeColors.backgroundColor.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toolSelectionChanged(_:)),
            name: .toolSelectionChanged,
            object: nil
        )
    }
    
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.themeDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func themeDidChange() {
        print("[ContentViewController] 🎨 主题变更通知收到")
        updateColors()
    }
    
    private func updateColors() {
        print("[ContentViewController] 🎨 updateColors() 被调用")
        print("[ContentViewController] 🎨 当前主题: \(ThemeManager.shared.currentTheme.displayName)")
        
        // 强制刷新 appearance 以确保颜色正确
        view.appearance = NSApp.effectiveAppearance
        containerView.appearance = NSApp.effectiveAppearance
        
        // 获取当前 appearance 对应的颜色
        let bgColor = ThemeColors.backgroundColor
        
        view.layer?.backgroundColor = bgColor.cgColor
        containerView.layer?.backgroundColor = bgColor.cgColor
        
        print("[ContentViewController] 🎨 背景色: \(bgColor)")
        print("[ContentViewController] 🎨 view.layer 存在: \(view.layer != nil)")
        print("[ContentViewController] 🎨 containerView.layer 存在: \(containerView.layer != nil)")
    }
    
    // MARK: - Actions
    
    @objc private func toolSelectionChanged(_ notification: Notification) {
        guard let index = notification.userInfo?["index"] as? Int,
              let toolType = ToolType(rawValue: index) else {
            return
        }
        
        showViewController(for: toolType)
    }
    
    // MARK: - Navigation
    
    private func showDefaultView() {
        showViewController(for: .power)
    }
    
    private func showViewController(for type: ToolType) {
        // 移除当前视图
        removeCurrentViewController()
        
        // 创建新视图
        let newViewController = ToolFactory.createViewController(for: type)
        addChild(newViewController)
        containerView.addSubview(newViewController.view)
        
        newViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            newViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            newViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            newViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        currentViewController = newViewController
    }
    
    private func removeCurrentViewController() {
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
        currentViewController = nil
    }
}

