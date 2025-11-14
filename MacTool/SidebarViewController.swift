//
//  SidebarViewController.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Cocoa

class SidebarViewController: NSViewController {
    
    var tableView: NSTableView!
    
    // 功能列表
    var tools: [ToolItem] = ToolType.allCases.map { type in
        ToolItem(id: type.identifier, title: type.title, icon: type.icon, type: type)
    }
    
    var selectedIndex: Int = 0 {
        didSet {
            NotificationCenter.default.post(name: .toolSelectionChanged, object: nil, userInfo: ["index": selectedIndex])
        }
    }
    
    // 测试开关
    private var testSwitch: NSSwitch!
    private var testSwitchContainer: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        setupTestSwitch()
        setupThemeObserver()
        updateColors()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        print("[SidebarViewController] 📱 页面已显示")
        
        // 在视图显示后选中第一行
        if tableView.selectedRow < 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    func setupTableView() {
        // 启用 layer 以支持背景色
        view.wantsLayer = true
        view.layer?.backgroundColor = ThemeColors.sidebarBackgroundColor.cgColor
        
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建表格视图
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.selectionHighlightStyle = .sourceList
        tableView.backgroundColor = NSColor.clear
        
        // 添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MainColumn"))
        column.width = 200
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60)
        ])
    }
    
    func setupTestSwitch() {
        // 创建测试开关容器
        testSwitchContainer = NSView()
        testSwitchContainer.wantsLayer = true
        testSwitchContainer.layer?.backgroundColor = ThemeColors.cardBackground.cgColor
        testSwitchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(testSwitchContainer)
        
        // 测试标签
        let testLabel = NSTextField(labelWithString: "🧪 深色")
        testLabel.font = NSFont.systemFont(ofSize: 11)
        testLabel.textColor = ThemeColors.labelColor
        testLabel.translatesAutoresizingMaskIntoConstraints = false
        testSwitchContainer.addSubview(testLabel)
        
        // 测试开关
        testSwitch = NSSwitch()
        testSwitch.target = self
        testSwitch.action = #selector(testSwitchToggled)
        testSwitch.state = ThemeManager.shared.isDarkMode ? .on : .off
        testSwitch.translatesAutoresizingMaskIntoConstraints = false
        testSwitchContainer.addSubview(testSwitch)
        
        NSLayoutConstraint.activate([
            testSwitchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            testSwitchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            testSwitchContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            testSwitchContainer.heightAnchor.constraint(equalToConstant: 60),
            
            testLabel.leadingAnchor.constraint(equalTo: testSwitchContainer.leadingAnchor, constant: 15),
            testLabel.centerYAnchor.constraint(equalTo: testSwitchContainer.centerYAnchor),
            
            testSwitch.trailingAnchor.constraint(equalTo: testSwitchContainer.trailingAnchor, constant: -15),
            testSwitch.centerYAnchor.constraint(equalTo: testSwitchContainer.centerYAnchor)
        ])
    }
    
    func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.themeDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func testSwitchToggled(_ sender: NSSwitch) {
        if sender.state == .on {
            ThemeManager.shared.currentTheme = .dark
        } else {
            ThemeManager.shared.currentTheme = .light
        }
    }
    
    @objc private func themeDidChange() {
        updateColors()
        testSwitch.state = ThemeManager.shared.isDarkMode ? .on : .off
        tableView.reloadData()
    }
    
    private func updateColors() {
        print("[SidebarViewController] 🎨 updateColors() 被调用")
        
        // 强制刷新 appearance
        view.appearance = NSApp.effectiveAppearance
        
        let sidebarBgColor = ThemeColors.sidebarBackgroundColor
        let secondaryBgColor = ThemeColors.cardBackground
        
        view.layer?.backgroundColor = sidebarBgColor.cgColor
        tableView.backgroundColor = NSColor.clear
        testSwitchContainer?.layer?.backgroundColor = secondaryBgColor.cgColor
        
        print("[SidebarViewController] 🎨 侧边栏背景色: \(sidebarBgColor)")
    }
}

// MARK: - NSTableViewDataSource
extension SidebarViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tools.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView ?? NSTableCellView()
        
        if cell.textField == nil {
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = NSColor.clear
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 20),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10)
            ])
            
            cell.textField = textField
        }
        
        let toolItem = tools[row]
        cell.textField?.stringValue = "\(toolItem.icon) \(toolItem.title)"
        
        return cell
    }
}

// MARK: - NSTableViewDelegate
extension SidebarViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 44
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRow >= 0 {
            selectedIndex = tableView.selectedRow
        }
    }
}

