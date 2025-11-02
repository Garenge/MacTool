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
        showDefaultView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupContainer() {
        containerView = NSView()
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

