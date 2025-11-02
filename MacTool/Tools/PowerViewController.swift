//
//  PowerViewController.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Cocoa

class PowerViewController: NSViewController {
    
    // MARK: - Properties
    
    var powerLabel: NSTextField!
    var refreshButton: NSButton!
    var statusLabel: NSTextField!
    var openDatabaseButton: NSButton!
    var clearDatabaseButton: NSButton!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        // 显示当前数据
        updateUIWithLatestData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // 监听功率数据更新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerDataUpdated(_:)),
            name: .powerDataUpdated,
            object: nil
        )
    }
    
    func setupUI() {
        // 创建主容器
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])
        
        // 创建功率标签
        powerLabel = NSTextField(labelWithString: "--")
        powerLabel.font = NSFont.systemFont(ofSize: 64, weight: .medium)
        powerLabel.alignment = .center
        powerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(powerLabel)
        
        // 创建状态标签
        statusLabel = NSTextField(labelWithString: "等待数据刷新...")
        statusLabel.font = NSFont.systemFont(ofSize: 14)
        statusLabel.alignment = .center
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // 创建刷新按钮
        refreshButton = NSButton(title: "刷新", target: self, action: #selector(manualRefresh))
        refreshButton.bezelStyle = .rounded
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(refreshButton)
        
        // 创建打开数据库按钮
        openDatabaseButton = NSButton(title: "打开数据库", target: self, action: #selector(openDatabaseFolder))
        openDatabaseButton.bezelStyle = .rounded
        openDatabaseButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(openDatabaseButton)
        
        // 创建清空数据库按钮
        clearDatabaseButton = NSButton(title: "清空数据库", target: self, action: #selector(clearDatabase))
        clearDatabaseButton.bezelStyle = .rounded
        clearDatabaseButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(clearDatabaseButton)
        
        // 布局约束
        NSLayoutConstraint.activate([
            powerLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            powerLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: powerLabel.bottomAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            refreshButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 30),
            refreshButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 100),
            
            openDatabaseButton.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 15),
            openDatabaseButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            openDatabaseButton.widthAnchor.constraint(equalToConstant: 120),
            
            clearDatabaseButton.topAnchor.constraint(equalTo: openDatabaseButton.bottomAnchor, constant: 15),
            clearDatabaseButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            clearDatabaseButton.widthAnchor.constraint(equalToConstant: 120),
            
            containerView.bottomAnchor.constraint(equalTo: clearDatabaseButton.bottomAnchor, constant: 40)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func manualRefresh() {
        statusLabel.stringValue = "手动刷新中..."
        // 触发一次数据获取
        PowerHelper.shared.fetchPowerData()
    }
    
    @objc private func openDatabaseFolder() {
        let dbPath = BatteryStorage.shared.getDatabasePath()
        NSWorkspace.shared.open(dbPath.deletingLastPathComponent())
    }
    
    @objc private func clearDatabase() {
        let alert = NSAlert()
        alert.messageText = "清空数据库"
        alert.informativeText = "确定要清空所有历史数据吗？此操作无法撤销。"
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            BatteryStorage.shared.clearAll()
            statusLabel.stringValue = "数据库已清空"
            statusLabel.textColor = NSColor.systemOrange
            powerLabel.stringValue = "--"
        }
    }
    
    @objc private func handlePowerDataUpdated(_ notification: Notification) {
        guard let dataPoint = notification.userInfo?["data"] as? BatteryDataPoint else {
            return
        }
        
        updateUI(with: dataPoint)
    }
    
    // MARK: - UI Update
    
    private func updateUI(with dataPoint: BatteryDataPoint) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        
        if dataPoint.isCharging {
            powerLabel.stringValue = String(format: "%.2f W", dataPoint.power)
            statusLabel.stringValue = "上次更新: \(dateFormatter.string(from: dataPoint.timestamp)) | 电量: \(dataPoint.percentage)% | 充电中"
        } else {
            powerLabel.stringValue = "未充电"
            statusLabel.stringValue = "上次更新: \(dateFormatter.string(from: dataPoint.timestamp)) | 电量: \(dataPoint.percentage)% | 未充电"
        }
        statusLabel.textColor = NSColor.secondaryLabelColor
    }
    
    private func updateUIWithLatestData() {
        let recentData = PowerHelper.shared.getRecentDataPoints(count: 1)
        if let latestData = recentData.first {
            updateUI(with: latestData)
        } else {
            statusLabel.stringValue = "暂无数据"
            statusLabel.textColor = NSColor.secondaryLabelColor
        }
    }
}
