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
    var chartView: BatteryChartView!
    var scrollView: NSScrollView!
    
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
        // 创建滚动视图（用于图表）
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 创建容器视图（宽度足够大以支持横向滚动，但足够宽以基本铺满）
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 2000, height: 400))
        containerView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.documentView = containerView
        
        // 创建图表视图
        chartView = BatteryChartView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        chartView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(chartView)
        
        // 居中图表
        NSLayoutConstraint.activate([
            chartView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            chartView.topAnchor.constraint(equalTo: containerView.topAnchor),
            chartView.widthAnchor.constraint(equalToConstant: 800),
            chartView.heightAnchor.constraint(equalToConstant: 400)
        ])
        
        // 创建顶部信息面板
        let infoPanel = NSView()
        infoPanel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.wantsLayer = true
        infoPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(infoPanel)
        
        // 创建功率标签
        powerLabel = NSTextField(labelWithString: "--")
        powerLabel.font = NSFont.systemFont(ofSize: 48, weight: .medium)
        powerLabel.alignment = .center
        powerLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(powerLabel)
        
        // 创建状态标签
        statusLabel = NSTextField(labelWithString: "等待数据刷新...")
        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.alignment = .center
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(statusLabel)
        
        // 创建按钮容器
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(buttonContainer)
        
        // 创建刷新按钮
        refreshButton = NSButton(title: "刷新", target: self, action: #selector(manualRefresh))
        refreshButton.bezelStyle = .rounded
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(refreshButton)
        
        // 创建打开数据库按钮
        openDatabaseButton = NSButton(title: "打开数据库", target: self, action: #selector(openDatabaseFolder))
        openDatabaseButton.bezelStyle = .rounded
        openDatabaseButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(openDatabaseButton)
        
        // 创建清空数据库按钮
        clearDatabaseButton = NSButton(title: "清空数据库", target: self, action: #selector(clearDatabase))
        clearDatabaseButton.bezelStyle = .rounded
        clearDatabaseButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(clearDatabaseButton)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 信息面板
            infoPanel.topAnchor.constraint(equalTo: view.topAnchor),
            infoPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            infoPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            infoPanel.heightAnchor.constraint(equalToConstant: 160),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: infoPanel.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 功率标签
            powerLabel.topAnchor.constraint(equalTo: infoPanel.topAnchor, constant: 20),
            powerLabel.centerXAnchor.constraint(equalTo: infoPanel.centerXAnchor),
            
            // 状态标签
            statusLabel.topAnchor.constraint(equalTo: powerLabel.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: infoPanel.centerXAnchor),
            
            // 按钮容器
            buttonContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 15),
            buttonContainer.centerXAnchor.constraint(equalTo: infoPanel.centerXAnchor),
            buttonContainer.heightAnchor.constraint(equalToConstant: 30),
            
            // 刷新按钮
            refreshButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            refreshButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 80),
            
            // 打开数据库按钮
            openDatabaseButton.leadingAnchor.constraint(equalTo: refreshButton.trailingAnchor, constant: 10),
            openDatabaseButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            openDatabaseButton.widthAnchor.constraint(equalToConstant: 100),
            
            // 清空数据库按钮
            clearDatabaseButton.leadingAnchor.constraint(equalTo: openDatabaseButton.trailingAnchor, constant: 10),
            clearDatabaseButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            clearDatabaseButton.widthAnchor.constraint(equalToConstant: 100),
            clearDatabaseButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor)
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
        updateChart()
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
        updateChart()
    }
    
    private func updateChart() {
        // 获取所有数据点并更新图表
        chartView.dataPoints = PowerHelper.shared.getAllDataPoints()
    }
}
