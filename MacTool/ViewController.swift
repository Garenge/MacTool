//
//  ViewController.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Cocoa

class ViewController: NSSplitViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 创建左右分栏布局
        setupSplitView()
    }
    
    func setupSplitView() {
        // 创建侧边栏
        let sidebarVC = SidebarViewController()
        sidebarVC.view.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        // 创建内容区域
        let contentVC = ContentViewController()
        
        // 添加到分割视图
        addSplitViewItem(NSSplitViewItem(sidebarWithViewController: sidebarVC))
        addSplitViewItem(NSSplitViewItem(contentListWithViewController: contentVC))
        
        // 设置分割视图属性
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = "MainSplitView"
    }
}

