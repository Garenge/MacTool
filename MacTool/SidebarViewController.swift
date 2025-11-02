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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // 在视图显示后选中第一行
        if tableView.selectedRow < 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    func setupTableView() {
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
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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

