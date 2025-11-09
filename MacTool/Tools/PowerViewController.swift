//
//  PowerViewController.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Cocoa

// FlippedView 与 StatisticsWindowController 已迁移至单独文件，参见 Tools/FlippedView.swift 与 Tools/StatisticsWindowController.swift

class PowerViewController: NSViewController {
    
    // MARK: - Properties
    
    var powerLabel: NSTextField!
    var batteryLabel: NSTextField!  // 电量显示标签
    var refreshButton: NSButton!
    var statusLabel: NSTextField!
    var openDatabaseButton: NSButton!
    var clearDatabaseButton: NSButton!
    var statisticsButton: NSButton!
    var chartView: BatteryChartView!
    var scrollView: NSScrollView!
    var infoPanel: NSView!
    private var selectedStartDate: Date?
    private var selectedEndDate: Date?
    var rangeContainer: NSView!
    var dateContainer: NSView!
    var segmentedControl: NSSegmentedControl!
    var headlineContainer: NSView!
    var headlineStack: NSStackView!
    var controlsStack: NSStackView!
    var moreButton: NSPopUpButton!
    var disclosureButton: NSButton!
    var lastHourButton: NSButton!
    var last24hButton: NSButton!
    var last7dButton: NSButton!
    var todayButton: NSButton!
    var startDatePicker: NSDatePicker!
    var endDatePicker: NSDatePicker!
    var applyRangeButton: NSButton!
    var infoPanelHeightConstraint: NSLayoutConstraint!
    
    // 强引用统计窗口控制器，防止被过早释放
    private var statisticsWindowControllers: [StatisticsWindowController] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
        // 默认选中“近1小时”并刷新
        segmentedControl.selectedSegment = 0
        selectLastHour()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        // 显示当前数据
        updateUIWithLatestData()
        // 更新背景色以适应当前主题
        updateInfoPanelBackgroundColor()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // 在视图完全显示后再次检查主题，确保背景色正确
        updateInfoPanelBackgroundColor()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default.removeObserver(self)
        // 移除 KVO 观察者
        NSApp.removeObserver(self, forKeyPath: "effectiveAppearance")
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
        
        // 监听应用内部主题变更通知（通过 ThemeManager）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChanged),
            name: ThemeManager.themeDidChangeNotification,
            object: nil
        )
        
        // 监听系统外观变化通知（系统设置中切换主题）
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemAppearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        
        // 使用 KVO 监听 NSApp.effectiveAppearance 的变化
        NSApp.addObserver(
            self,
            forKeyPath: "effectiveAppearance",
            options: [.new, .old],
            context: nil
        )
    }
    
    @objc private func handleAppearanceChanged() {
        // 当应用主题变化时，更新背景色
        DispatchQueue.main.async { [weak self] in
            self?.updateInfoPanelBackgroundColor()
        }
    }
    
    @objc private func handleSystemAppearanceChanged() {
        // 当系统主题变化时，更新背景色
        DispatchQueue.main.async { [weak self] in
            self?.updateInfoPanelBackgroundColor()
        }
    }
    
    // KVO 监听 NSApp.effectiveAppearance 变化
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "effectiveAppearance" && object as? NSApplication == NSApp {
            DispatchQueue.main.async { [weak self] in
                self?.updateInfoPanelBackgroundColor()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func setupUI() {
        // 设置主视图背景色为蓝色
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemBlue.cgColor
        
        // 创建滚动视图（用于图表）
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 创建容器视图
        let containerView = NSView(frame: .zero)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = containerView
        
        // 创建图表视图
        chartView = BatteryChartView(frame: .zero)
        chartView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(chartView)
        
        // 容器约束：宽度跟随视图宽度，高度固定
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 400),
            
            // 图表在容器中居中，固定大小
            chartView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            chartView.topAnchor.constraint(equalTo: containerView.topAnchor),
            chartView.widthAnchor.constraint(equalToConstant: 800),
            chartView.heightAnchor.constraint(equalToConstant: 400)
        ])
        
        // 创建顶部信息面板
        infoPanel = NSView()
        infoPanel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.wantsLayer = true
        updateInfoPanelBackgroundColor()
        view.addSubview(infoPanel)
        
        // 创建功率标签
        powerLabel = NSTextField(labelWithString: "--")
        powerLabel.font = NSFont.systemFont(ofSize: 48, weight: .medium)
        powerLabel.alignment = .center
        powerLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(powerLabel)
        
        // 创建电量标签
        batteryLabel = NSTextField(labelWithString: "--%")
        batteryLabel.font = NSFont.systemFont(ofSize: 32, weight: .medium)
        batteryLabel.alignment = .center
        batteryLabel.textColor = NSColor.systemBlue
        batteryLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(batteryLabel)
        
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
        
        // 创建查看统计按钮
        statisticsButton = NSButton(title: "📊 查看统计", target: self, action: #selector(showStatistics))
        statisticsButton.bezelStyle = .rounded
        statisticsButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(statisticsButton)
        // 选项1：将三项动作收纳到“更多”菜单，隐藏原按钮
        statisticsButton.isHidden = true

        // 第一排新增“更多”下拉菜单（不保留选中态，始终展示“更多”文字）
        moreButton = NSPopUpButton(title: "更多", target: nil, action: nil)
        moreButton.controlSize = .regular
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.pullsDown = true
        let moreMenu = NSMenu()
        // 标题项：仅用于展示按钮文字，不可选
        let titleItem = NSMenuItem(title: "更多", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        moreMenu.addItem(titleItem)
        // 三个操作项：打开数据库、清空数据、查看统计（不显示勾选）
        let openItem = NSMenuItem(title: "打开数据库", action: #selector(openDatabaseFolder), keyEquivalent: "")
        openItem.target = self
        moreMenu.addItem(openItem)
        let clearItem = NSMenuItem(title: "清空数据", action: #selector(clearDatabase), keyEquivalent: "")
        clearItem.target = self
        moreMenu.addItem(clearItem)
        let statsItem = NSMenuItem(title: "查看统计", action: #selector(showStatistics), keyEquivalent: "")
        statsItem.target = self
        moreMenu.addItem(statsItem)
        moreButton.menu = moreMenu
        buttonContainer.addSubview(moreButton)
        // 隐藏旧按钮以减少拥挤
        openDatabaseButton.isHidden = true
        clearDatabaseButton.isHidden = true

        // 分段控件（与刷新/更多同一行，放在左侧）
        segmentedControl = NSSegmentedControl(labels: ["近1小时", "近24小时", "近7天", "今天"], trackingMode: .selectOne, target: self, action: #selector(selectSegmentChanged))
        segmentedControl.controlSize = .regular
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        // 先不直接添加，后续加入 controlsStack
        // 隐藏旧快捷按钮
        lastHourButton = NSButton()
        last24hButton = NSButton()
        last7dButton = NSButton()
        todayButton = NSButton()
        lastHourButton.isHidden = true
        last24hButton.isHidden = true
        last7dButton.isHidden = true
        todayButton.isHidden = true

        // 第三排容器：自定义日期区间（可折叠）
        disclosureButton = NSButton(title: "自定义时间 ▸", target: self, action: #selector(toggleDateContainer))
        disclosureButton.bezelStyle = .rounded
        disclosureButton.controlSize = .regular
        disclosureButton.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(disclosureButton)

        dateContainer = NSView()
        dateContainer.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(dateContainer)

        startDatePicker = NSDatePicker()
        startDatePicker.controlSize = .small
        startDatePicker.datePickerStyle = .textFieldAndStepper
        startDatePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        startDatePicker.translatesAutoresizingMaskIntoConstraints = false
        dateContainer.addSubview(startDatePicker)

        endDatePicker = NSDatePicker()
        endDatePicker.controlSize = .small
        endDatePicker.datePickerStyle = .textFieldAndStepper
        endDatePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        endDatePicker.translatesAutoresizingMaskIntoConstraints = false
        dateContainer.addSubview(endDatePicker)

        applyRangeButton = NSButton(title: "应用", target: self, action: #selector(applyCustomRange))
        applyRangeButton.bezelStyle = .rounded
        applyRangeButton.controlSize = .regular
        applyRangeButton.translatesAutoresizingMaskIntoConstraints = false
        dateContainer.addSubview(applyRangeButton)
        
        // =========== 统一居中布局：headerStack = 垂直栈 ===========
        let headerStack = NSStackView()
        headerStack.orientation = .vertical
        headerStack.spacing = 6
        headerStack.alignment = .centerX
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        infoPanel.addSubview(headerStack)

        // 第一行：功率 + 电量（水平栈）
        headlineStack = NSStackView(views: [powerLabel, batteryLabel])
        headlineStack.orientation = .horizontal
        headlineStack.spacing = 16
        headlineStack.alignment = .centerY
        headlineStack.distribution = .equalCentering
        headlineStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(headlineStack)

        // 第二行：状态标签
        headerStack.addArrangedSubview(statusLabel)

        // 第三行：分段 + 弹性 + 刷新 + 更多（水平栈）
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        controlsStack = NSStackView(views: [segmentedControl, spacer, refreshButton, moreButton])
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 10
        controlsStack.alignment = .centerY
        controlsStack.distribution = .fill
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(controlsStack)

        // 第四行：折叠按钮
        headerStack.addArrangedSubview(disclosureButton)

        // 第五行：日期容器（内部已有子控件）
        headerStack.addArrangedSubview(dateContainer)

        // 基本约束：infoPanel 和 headerStack
        infoPanelHeightConstraint = infoPanel.heightAnchor.constraint(equalToConstant: 210)
        NSLayoutConstraint.activate([
            // 信息面板铺满顶部
            infoPanel.topAnchor.constraint(equalTo: view.topAnchor),
            infoPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            infoPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            infoPanelHeightConstraint,

            // 图表滚动区
            scrollView.topAnchor.constraint(equalTo: infoPanel.bottomAnchor, constant: 0),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 头部栈整体居中
            headerStack.topAnchor.constraint(equalTo: infoPanel.topAnchor, constant: 12),
            headerStack.centerXAnchor.constraint(equalTo: infoPanel.centerXAnchor),
            headerStack.leadingAnchor.constraint(greaterThanOrEqualTo: infoPanel.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: infoPanel.trailingAnchor, constant: -20),

            // 日期容器固定高度（适配常规按钮）
            dateContainer.heightAnchor.constraint(equalToConstant: 28),

            // 控件宽度
            refreshButton.widthAnchor.constraint(equalToConstant: 72),
            moreButton.widthAnchor.constraint(equalToConstant: 72)
        ])

        // 顶部行控件增加高度（约 +10px）
        NSLayoutConstraint.activate([
            segmentedControl.heightAnchor.constraint(equalToConstant: 32),
            refreshButton.heightAnchor.constraint(equalToConstant: 32),
            moreButton.heightAnchor.constraint(equalToConstant: 32),
            disclosureButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        // 日期内部的横向排布
        NSLayoutConstraint.activate([
            startDatePicker.leadingAnchor.constraint(equalTo: dateContainer.leadingAnchor),
            startDatePicker.centerYAnchor.constraint(equalTo: dateContainer.centerYAnchor),
            startDatePicker.widthAnchor.constraint(equalToConstant: 160),

            endDatePicker.leadingAnchor.constraint(equalTo: startDatePicker.trailingAnchor, constant: 6),
            endDatePicker.centerYAnchor.constraint(equalTo: dateContainer.centerYAnchor),
            endDatePicker.widthAnchor.constraint(equalToConstant: 160),

            applyRangeButton.leadingAnchor.constraint(equalTo: endDatePicker.trailingAnchor, constant: 6),
            applyRangeButton.centerYAnchor.constraint(equalTo: dateContainer.centerYAnchor),
            applyRangeButton.widthAnchor.constraint(equalToConstant: 60),
            applyRangeButton.trailingAnchor.constraint(equalTo: dateContainer.trailingAnchor)
        ])

        // 初始化日期选择器默认值
        let now = Date()
        startDatePicker.dateValue = now.addingTimeInterval(-3600)
        endDatePicker.dateValue = now
        // 初始收起第三排
        dateContainer.isHidden = true
        infoPanelHeightConstraint.constant = 180
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
    
    @objc private func showStatistics() {
        guard let statistics = PowerHelper.shared.getAllStatistics() else {
            let alert = NSAlert()
            alert.messageText = "暂无统计数据"
            alert.informativeText = "请确保已有足够的充电数据。至少需要一些充电数据点才能进行分析。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        // 创建统计信息窗口（更大尺寸以容纳可视化元素）
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "📊 电池统计分析"
        window.center()
        window.minSize = NSSize(width: 600, height: 500)
        // 不设置 maxSize，允许用户自由调整窗口大小
        
        // 窗口由 WindowController 管理，不自动释放
        window.isReleasedWhenClosed = false
        
        // 获取窗口的 contentView
        guard let contentView = window.contentView else {
            print("[PowerViewController] ⚠️ 无法获取窗口的 contentView")
            return
        }
        
        // 创建滚动视图
        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.textBackgroundColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        
        // 先计算需要的高度
        let calculatedHeight = calculateContentViewHeight(statistics: statistics)
        let containerHeight = max(calculatedHeight, 800)
        
        // 创建容器视图（自定义类，确保坐标从顶部开始）
        // 使用自适应宽度
        let containerView = FlippedView(frame: NSRect(x: 0, y: 0, width: 810, height: containerHeight))
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        
        // 先设置 documentView
        scrollView.documentView = containerView
        
        print("[PowerViewController] 📊 容器视图初始尺寸: 810 x \(containerHeight)")
        print("[PowerViewController] 📊 开始创建统计视图...")
        
        // 使用富文本创建美观的报告
        createBeautifiedStatisticsView(in: containerView, statistics: statistics)
        
        print("[PowerViewController] 📊 统计视图创建完成")
        
        // 设置滚动视图约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
        
        // 设置容器视图约束 - 使用自适应宽度
        // 使用 clipView 作为参考，确保容器宽度随窗口变化
        let clipView = scrollView.contentView
        
        // 使用较低优先级的最小宽度约束，避免与trailingAnchor冲突
        let minWidthConstraint = containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 600)
        minWidthConstraint.priority = .defaultHigh  // 降低优先级，允许窗口缩小到600以下
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: clipView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            containerView.heightAnchor.constraint(equalToConstant: containerHeight),
            minWidthConstraint
        ])
        print("[PowerViewController] 📊 容器视图约束设置完成，高度: \(containerHeight)")
        
        // 创建窗口控制器来管理窗口生命周期
        let windowController = StatisticsWindowController(window: window)
        windowController.windowDidLoad()
        
        // 强引用窗口控制器，防止被过早释放
        statisticsWindowControllers.append(windowController)
        
        // 监听窗口关闭，移除控制器引用
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statisticsWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
        
        // 显示窗口
        windowController.showWindow(nil)
        
        // 注意：通过 windowController 管理窗口，窗口关闭时会收到通知并清理
        // 通过约束系统自动处理窗口大小变化，内容会自适应调整
    }
    
    @objc private func statisticsWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // 移除对应的窗口控制器
        statisticsWindowControllers.removeAll { controller in
            controller.window == window
        }
        
        // 移除观察器
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
        
        print("[PowerViewController] 📊 统计窗口已关闭，控制器已移除")
    }
    
    /// 创建美化后的统计视图（富文本 + 可视化元素）
    private func createBeautifiedStatisticsView(in containerView: NSView, statistics: BatteryStatistics) {
        // 从顶部开始布局（Y坐标从顶部向下递增）
        // 注意：NSView 的约束系统使用 topAnchor 时，Y坐标从顶部开始
        var currentY: CGFloat = 30  // 从顶部 30px 开始（增加一些上边距）
        let padding: CGFloat = 20
        let sectionSpacing: CGFloat = 30
        
        print("[PowerViewController] 📊 开始布局，起始Y: \(currentY)")
        
        // ========== 标题区域 ==========
        currentY = createTitleSection(y: currentY, containerView: containerView, padding: padding)
        currentY += sectionSpacing
        
        // ========== 一、功率统计指标（带进度条）==========
        currentY = createPowerStatsSection(y: currentY, containerView: containerView, statistics: statistics, padding: padding)
        currentY += sectionSpacing
        
        // ========== 二、数据统计指标（表格格式）==========
        currentY = createDataStatsSection(y: currentY, containerView: containerView, statistics: statistics, padding: padding)
        currentY += sectionSpacing
        
        // ========== 三、功率趋势分析（可视化）==========
        currentY = createTrendAnalysisSection(y: currentY, containerView: containerView, statistics: statistics, padding: padding)
        currentY += sectionSpacing
        
        // ========== 四、不同电量段的平均功率（图表）==========
        currentY = createPowerByPercentageSection(y: currentY, containerView: containerView, statistics: statistics, padding: padding)
        
        // 添加底部空白占位视图，确保有足够的空间
        let bottomSpacer = NSView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bottomSpacer)
        
        NSLayoutConstraint.activate([
            bottomSpacer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: currentY),
            bottomSpacer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bottomSpacer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bottomSpacer.heightAnchor.constraint(equalToConstant: 130)
        ])
        
        currentY += 130
        
        print("[PowerViewController] 📊 布局完成，最终高度: \(currentY)")
    }
    
    /// 创建标题区域
    private func createTitleSection(y: CGFloat, containerView: NSView, padding: CGFloat) -> CGFloat {
        let titleLabel = NSTextField(labelWithString: "📊 电池充电功率统计分析报告")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        let widthConstraint = titleLabel.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor, constant: -padding * 2)
        widthConstraint.priority = .required
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: y),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -padding),
            widthConstraint
        ])
        
        return y + 60  // 返回下一个Y位置（标题高度 + 间距）
    }
    
    /// 创建功率统计区域（带进度条可视化）
    private func createPowerStatsSection(y: CGFloat, containerView: NSView, statistics: BatteryStatistics, padding: CGFloat) -> CGFloat {
        var currentY = y
        
        // 章节标题
        createSectionTitle(text: "📈 一、功率统计指标", y: &currentY, containerView: containerView, padding: padding)
        currentY += 5
        
        // 最大功率（带进度条）
        createMetricRow(
            title: "最大功率",
            value: String(format: "%.2f W", statistics.maxPower),
            maxValue: max(statistics.maxPower * 1.2, 100), // 设置一个合理的最大值用于显示
            currentValue: statistics.maxPower,
            color: NSColor.systemGreen,
            y: &currentY,
            containerView: containerView,
            padding: padding
        )
        currentY += 10
        
        // 平均功率
        createMetricRow(
            title: "平均功率",
            value: String(format: "%.2f W", statistics.averagePower),
            maxValue: max(statistics.maxPower * 1.2, 100),
            currentValue: statistics.averagePower,
            color: NSColor.systemBlue,
            y: &currentY,
            containerView: containerView,
            padding: padding
        )
        currentY += 10
        
        // 最小功率
        createMetricRow(
            title: "最小功率",
            value: String(format: "%.2f W", statistics.minPower),
            maxValue: max(statistics.maxPower * 1.2, 100),
            currentValue: statistics.minPower,
            color: NSColor.systemOrange,
            y: &currentY,
            containerView: containerView,
            padding: padding
        )
        currentY += 15
        
        return currentY
    }
    
    /// 创建数据统计区域（表格格式）
    private func createDataStatsSection(y: CGFloat, containerView: NSView, statistics: BatteryStatistics, padding: CGFloat) -> CGFloat {
        var currentY = y
        
        // 章节标题
        createSectionTitle(text: "📊 二、数据统计指标", y: &currentY, containerView: containerView, padding: padding)
        currentY += 5
        
        // 创建表格样式的数据展示
        let tableData = [
            ("总数据点", "\(statistics.totalDataPoints)", "数据库中存储的所有数据点数量"),
            ("充电数据点", "\(statistics.chargingDataPoints)", "实际充电状态下的数据点数量"),
            ("数据完整度", String(format: "%.1f%%", Double(statistics.chargingDataPoints) / Double(statistics.totalDataPoints) * 100), "充电数据占总数据的比例")
        ]
        
        for (title, value, description) in tableData {
            currentY = createTableRow(
                title: title,
                value: value,
                description: description,
                y: currentY,
                containerView: containerView,
                padding: padding
            )
            currentY += 8
        }
        
        return currentY + 10
    }
    
    /// 创建趋势分析区域
    private func createTrendAnalysisSection(y: CGFloat, containerView: NSView, statistics: BatteryStatistics, padding: CGFloat) -> CGFloat {
        var currentY = y
        
        // 章节标题
        createSectionTitle(text: "⚡ 三、功率趋势分析指标", y: &currentY, containerView: containerView, padding: padding)
        currentY += 5
        
        // 最大功率电量
        if let maxPowerPct = statistics.maxPowerPercentage {
            createPercentageRow(
                title: "最大功率电量",
                percentage: maxPowerPct,
                description: "功率达到最大值时的电池电量",
                y: &currentY,
                containerView: containerView,
                padding: padding
            )
        }
        
        // 功率下降电量
        if let dropPct = statistics.powerDropPercentage {
            createPercentageRow(
                title: "功率下降电量",
                percentage: dropPct,
                description: "功率开始明显下降（下降超过10%）时的电量",
                y: &currentY,
                containerView: containerView,
                padding: padding
            )
        }
        
        return currentY + 10
    }
    
    /// 创建电量段功率区域（可视化图表）
    private func createPowerByPercentageSection(y: CGFloat, containerView: NSView, statistics: BatteryStatistics, padding: CGFloat) -> CGFloat {
        var currentY = y
        
        // 章节标题
        createSectionTitle(text: "📋 四、不同电量段的平均功率", y: &currentY, containerView: containerView, padding: padding)
        currentY += 5
        
        let subtitle = NSTextField(labelWithString: "功率随电量变化趋势（每10%电量为一组）")
        subtitle.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = NSColor.secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitle)
        
        NSLayoutConstraint.activate([
            subtitle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: currentY),
            subtitle.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding + 20),
            subtitle.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -(padding + 20))
        ])
        currentY += 25
        
        // 获取最大功率值用于归一化显示
        let maxPowerInChart = statistics.powerByPercentage.values.max() ?? 50.0
        
        // 按电量从高到低排序显示
        let sortedPercentages = statistics.powerByPercentage.keys.sorted(by: >)
        for pct in sortedPercentages {
            if let power = statistics.powerByPercentage[pct] {
                let pctRange = "\(pct)% - \(min(pct + 9, 100))%"
                currentY = createPowerBarRow(
                    percentageRange: pctRange,
                    power: power,
                    maxPower: maxPowerInChart,
                    y: currentY,
                    containerView: containerView,
                    padding: padding
                )
                currentY += 5
            }
        }
        
        // 返回当前Y位置（底部间距通过独立的空白视图处理）
        return currentY
    }
    
    // MARK: - Helper Methods for UI Components
    
    /// 创建章节标题
    private func createSectionTitle(text: String, y: inout CGFloat, containerView: NSView, padding: CGFloat) -> NSView {
        let title = NSTextField(labelWithString: text)
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.textColor = NSColor.labelColor
        title.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(title)
        
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: containerView.topAnchor, constant: y),
            title.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            title.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding)
        ])
        
        y += 25  // 标题高度 + 间距
        return title
    }
    
    /// 创建带进度条的指标行
    private func createMetricRow(title: String, value: String, maxValue: Double, currentValue: Double, color: NSColor, y: inout CGFloat, containerView: NSView, padding: CGFloat) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(container)
        
        // 标题和值
        let titleLabel = NSTextField(labelWithString: "\(title):")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        valueLabel.textColor = color
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)
        
        // 进度条背景（使用NSView替代NSBox）
        let progressBar = NSView()
        progressBar.wantsLayer = true
        progressBar.layer?.backgroundColor = color.withAlphaComponent(0.3).cgColor
        progressBar.layer?.cornerRadius = 3
        progressBar.layer?.borderWidth = 0.5
        progressBar.layer?.borderColor = NSColor.separatorColor.cgColor
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(progressBar)
        
        // 进度条填充（实际值）
        let progressFill = NSView()
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = color.cgColor
        progressFill.layer?.cornerRadius = 3
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBar.addSubview(progressFill)
        
        // 防止除以零导致崩溃
        let progressRatio = maxValue > 0 ? min(currentValue / maxValue, 1.0) : 0.0
        
        // 约束
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: containerView.topAnchor, constant: y),
            container.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            container.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            container.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            
            progressBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            progressBar.heightAnchor.constraint(equalToConstant: 12),
            
            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBar.widthAnchor, multiplier: CGFloat(progressRatio)),
            progressFill.heightAnchor.constraint(equalTo: progressBar.heightAnchor)
        ])
        
        y += 50
        return container
    }
    
    /// 创建表格行
    private func createTableRow(title: String, value: String, description: String, y: CGFloat, containerView: NSView, padding: CGFloat) -> CGFloat {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 4
        containerView.addSubview(container)
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = NSColor.systemBlue
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)
        
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 10)
        descLabel.textColor = NSColor.secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: containerView.topAnchor, constant: y),
            container.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            container.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            container.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -8),
            
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -15),
            descLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 8)
        ])
        
        return y + 40
    }
    
    /// 创建百分比行（带进度条）
    private func createPercentageRow(title: String, percentage: Int, description: String, y: inout CGFloat, containerView: NSView, padding: CGFloat) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(container)
        
        let titleLabel = NSTextField(labelWithString: "\(title):")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let valueLabel = NSTextField(labelWithString: "\(percentage)%")
        valueLabel.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        valueLabel.textColor = getPercentageColor(percentage)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)
        
        // 百分比进度条（使用NSView替代NSBox）
        let progressBar = NSView()
        progressBar.wantsLayer = true
        progressBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        progressBar.layer?.cornerRadius = 4
        progressBar.layer?.borderWidth = 0.5
        progressBar.layer?.borderColor = NSColor.separatorColor.cgColor
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(progressBar)
        
        let progressFill = NSView()
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = getPercentageColor(percentage).cgColor
        progressFill.layer?.cornerRadius = 4
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBar.addSubview(progressFill)
        
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 10)
        descLabel.textColor = NSColor.secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)
        
        // 确保百分比在有效范围内
        let progressRatio = max(0.0, min(Double(percentage) / 100.0, 1.0))
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: containerView.topAnchor, constant: y),
            container.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            container.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            container.heightAnchor.constraint(equalToConstant: 55),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            
            progressBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            progressBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            progressBar.heightAnchor.constraint(equalToConstant: 16),
            
            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBar.widthAnchor, multiplier: CGFloat(progressRatio)),
            progressFill.heightAnchor.constraint(equalTo: progressBar.heightAnchor),
            
            descLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20)
        ])
        
        y += 55
        return container
    }
    
    /// 创建功率条形图行
    private func createPowerBarRow(percentageRange: String, power: Double, maxPower: Double, y: CGFloat, containerView: NSView, padding: CGFloat) -> CGFloat {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(container)
        
        let rangeLabel = NSTextField(labelWithString: percentageRange)
        rangeLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        rangeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rangeLabel)
        
        let powerLabel = NSTextField(labelWithString: String(format: "%.2f W", power))
        powerLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        powerLabel.textColor = NSColor.labelColor
        powerLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(powerLabel)
        
        // 条形图（使用NSView替代NSBox）
        let barContainer = NSView()
        barContainer.wantsLayer = true
        barContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        barContainer.layer?.cornerRadius = 2
        barContainer.layer?.borderWidth = 0.5
        barContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        barContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(barContainer)
        
        let barFill = NSView()
        barFill.wantsLayer = true
        barFill.layer?.backgroundColor = getPowerBarColor(power: power, maxPower: maxPower).cgColor
        barFill.layer?.cornerRadius = 2
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barContainer.addSubview(barFill)
        
        // 防止除以零导致崩溃
        let barRatio = maxPower > 0 ? min(power / maxPower, 1.0) : 0.0
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: containerView.topAnchor, constant: y),
            container.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            container.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            container.heightAnchor.constraint(equalToConstant: 20),
            
            rangeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            rangeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            rangeLabel.widthAnchor.constraint(equalToConstant: 100),
            
            powerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            powerLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            barContainer.leadingAnchor.constraint(equalTo: rangeLabel.trailingAnchor, constant: 15),
            barContainer.trailingAnchor.constraint(equalTo: powerLabel.leadingAnchor, constant: -15),
            barContainer.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            barContainer.heightAnchor.constraint(equalToConstant: 12),
            
            barFill.topAnchor.constraint(equalTo: barContainer.topAnchor),
            barFill.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor),
            barFill.widthAnchor.constraint(equalTo: barContainer.widthAnchor, multiplier: CGFloat(barRatio)),
            barFill.heightAnchor.constraint(equalTo: barContainer.heightAnchor)
        ])
        
        return y + 20
    }
    
    /// 计算内容视图高度
    private func calculateContentViewHeight(statistics: BatteryStatistics) -> CGFloat {
        var height: CGFloat = 30  // 顶部间距
        height += 60 + 30  // 标题区域 + sectionSpacing
        height += 180 + 30  // 功率统计区域（3个指标 * 50 + 标题） + sectionSpacing
        height += 150 + 30  // 数据统计区域（3个表格行 * 40 + 标题） + sectionSpacing
        height += 150 + 30  // 趋势分析区域（2个百分比行 * 55 + 标题） + sectionSpacing
        height += 55 + CGFloat(statistics.powerByPercentage.count) * 25  // 电量段功率区域（标题+副标题+条形图）
        height += 130  // 底部间距
        return height
    }
    
    /// 根据百分比获取颜色
    private func getPercentageColor(_ percentage: Int) -> NSColor {
        if percentage >= 80 {
            return NSColor.systemGreen
        } else if percentage >= 50 {
            return NSColor.systemYellow
        } else if percentage >= 20 {
            return NSColor.systemOrange
        } else {
            return NSColor.systemRed
        }
    }
    
    /// 根据功率获取条形图颜色
    private func getPowerBarColor(power: Double, maxPower: Double) -> NSColor {
        let ratio = power / maxPower
        if ratio >= 0.8 {
            return NSColor.systemGreen
        } else if ratio >= 0.5 {
            return NSColor.systemBlue
        } else if ratio >= 0.3 {
            return NSColor.systemYellow
        } else {
            return NSColor.systemOrange
        }
    }
    
    /// 格式化统计信息，包含所有可统计的变量说明
    private func formatStatistics(_ stats: BatteryStatistics) -> String {
        var result = ""
        
        result += "═══════════════════════════════════════════════════════\n"
        result += "        📊 电池充电功率统计分析报告\n"
        result += "═══════════════════════════════════════════════════════\n\n"
        
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "📈 一、功率统计指标\n"
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "• 最大功率 (maxPower): \(String(format: "%.2f", stats.maxPower)) W\n"
        result += "  └─ 说明: 充电过程中记录到的最高功率值\n\n"
        
        result += "• 最小功率 (minPower): \(String(format: "%.2f", stats.minPower)) W\n"
        result += "  └─ 说明: 充电过程中记录到的最低功率值\n\n"
        
        result += "• 平均功率 (averagePower): \(String(format: "%.2f", stats.averagePower)) W\n"
        result += "  └─ 说明: 所有充电数据点的平均功率\n\n"
        
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "📊 二、数据统计指标\n"
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "• 总数据点 (totalDataPoints): \(stats.totalDataPoints)\n"
        result += "  └─ 说明: 数据库中存储的所有数据点数量\n\n"
        
        result += "• 充电数据点 (chargingDataPoints): \(stats.chargingDataPoints)\n"
        result += "  └─ 说明: 实际充电状态下的数据点数量\n\n"
        
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "⚡ 三、功率趋势分析指标\n"
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        
        if let maxPowerPct = stats.maxPowerPercentage {
            result += "• 最大功率电量 (maxPowerPercentage): \(maxPowerPct)%\n"
            result += "  └─ 说明: 功率达到最大值时的电池电量百分比\n\n"
        } else {
            result += "• 最大功率电量: 暂无数据\n\n"
        }
        
        if let dropPct = stats.powerDropPercentage {
            result += "• 功率下降电量 (powerDropPercentage): \(dropPct)%\n"
            result += "  └─ 说明: 功率开始明显下降（下降超过10%）时的电量\n"
            result += "     提示: 通常表示进入恒压充电阶段\n\n"
        } else {
            result += "• 功率下降电量: 暂无明显下降趋势\n\n"
        }
        
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "📋 四、不同电量段的平均功率\n"
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "(功率随电量变化趋势，每10%电量为一组)\n\n"
        
        let sortedPercentages = stats.powerByPercentage.keys.sorted(by: >)
        for pct in sortedPercentages {
            if let power = stats.powerByPercentage[pct] {
                let pctRange = "\(pct)% - \(min(pct + 9, 100))%"
                result += "• 电量 \(pctRange): \(String(format: "%.2f", power)) W\n"
            }
        }
        
        result += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "💡 代码访问方式:\n"
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        result += "let stats = PowerHelper.shared.getAllStatistics()\n"
        result += "if let stats = stats {\n"
        result += "    print(\"最大功率: \\(stats.maxPower) W\")\n"
        result += "    print(\"平均功率: \\(stats.averagePower) W\")\n"
        result += "    print(\"最大功率电量: \\(stats.maxPowerPercentage ?? 0)%\")\n"
        result += "    print(\"功率下降电量: \\(stats.powerDropPercentage ?? 0)%\")\n"
        result += "}\n"
        
        return result
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
        
        // 更新电量显示（始终显示）
        batteryLabel.stringValue = "\(dataPoint.percentage)%"
        
        // 根据电量设置颜色
        if dataPoint.percentage >= 80 {
            batteryLabel.textColor = NSColor.systemGreen
        } else if dataPoint.percentage >= 50 {
            batteryLabel.textColor = NSColor.systemYellow
        } else if dataPoint.percentage >= 20 {
            batteryLabel.textColor = NSColor.systemOrange
        } else {
            batteryLabel.textColor = NSColor.systemRed
        }
        
        if dataPoint.isCharging {
            powerLabel.stringValue = String(format: "%.2f W", dataPoint.power)
            statusLabel.stringValue = "上次更新: \(dateFormatter.string(from: dataPoint.timestamp)) | 充电中"
        } else {
            powerLabel.stringValue = "未充电"
            statusLabel.stringValue = "上次更新: \(dateFormatter.string(from: dataPoint.timestamp)) | 未充电"
        }
        statusLabel.textColor = NSColor.secondaryLabelColor
    }
    
    private func updateUIWithLatestData() {
        let recentData = PowerHelper.shared.getRecentDataPoints(count: 1)
        if let latestData = recentData.first {
            updateUI(with: latestData)
        } else {
            batteryLabel.stringValue = "--%"
            batteryLabel.textColor = NSColor.secondaryLabelColor
            statusLabel.stringValue = "暂无数据"
            statusLabel.textColor = NSColor.secondaryLabelColor
        }
        updateChart()
    }
    
    /// 更新 infoPanel 的背景色，根据当前主题（浅色/深色模式）
    private func updateInfoPanelBackgroundColor() {
        guard let infoPanel = infoPanel else { return }
        
        // 强制刷新 appearance 以确保颜色正确
        infoPanel.appearance = NSApp.effectiveAppearance
        
        // 判断当前是否为深色模式
        let isDarkMode: Bool
        if #available(macOS 10.14, *) {
            isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDarkMode = false
        }
        
        // 根据主题设置颜色：深色模式使用文本背景色，浅色模式使用白色
        infoPanel.layer?.backgroundColor = isDarkMode ? NSColor.textBackgroundColor.cgColor : NSColor.white.cgColor
    }
    
    private func updateChart() {
        // 若已选择自定义时间段，则按该范围展示；否则默认最近1小时
        if let start = selectedStartDate, let end = selectedEndDate {
            // 确保时间顺序正确
            let (s, e) = start <= end ? (start, end) : (end, start)
            chartView.dataPoints = PowerHelper.shared.getDataPoints(from: s, to: e)
            chartView.customTimeRange = (
                start: s.timeIntervalSince1970,
                end: e.timeIntervalSince1970
            )
        } else {
            let now = Date()
            let oneHourAgo = now.addingTimeInterval(-3600)
            chartView.dataPoints = PowerHelper.shared.getDataPoints(from: oneHourAgo, to: now)
            chartView.customTimeRange = nil
        }
    }

    // 供外部设置时间范围的接口
    func setChartRange(start: Date?, end: Date?) {
        selectedStartDate = start
        selectedEndDate = end
        updateChart()
    }

    @objc private func selectLastHour() {
        let now = Date()
        let s = now.addingTimeInterval(-3600)
        let e = now
        startDatePicker.dateValue = s
        endDatePicker.dateValue = e
        setChartRange(start: s, end: e)
    }

    @objc private func selectLast24h() {
        let now = Date()
        let s = now.addingTimeInterval(-24*3600)
        let e = now
        startDatePicker.dateValue = s
        endDatePicker.dateValue = e
        setChartRange(start: s, end: e)
    }

    @objc private func selectLast7d() {
        let now = Date()
        let s = now.addingTimeInterval(-7*24*3600)
        let e = now
        startDatePicker.dateValue = s
        endDatePicker.dateValue = e
        setChartRange(start: s, end: e)
    }

    @objc private func selectToday() {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        startDatePicker.dateValue = start
        endDatePicker.dateValue = now
        setChartRange(start: start, end: now)
    }

    @objc private func selectSegmentChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: selectLastHour()
        case 1: selectLast24h()
        case 2: selectLast7d()
        case 3: selectToday()
        default: break
        }
    }

    @objc private func toggleDateContainer() {
        let hidden = !dateContainer.isHidden
        dateContainer.isHidden = hidden
        disclosureButton.title = hidden ? "自定义时间 ▸" : "自定义时间 ▾"
        infoPanelHeightConstraint.constant = hidden ? 180 : 210
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            self.view.layoutSubtreeIfNeeded()
        }, completionHandler: nil)
    }

    @objc private func applyCustomRange() {
        let s = startDatePicker.dateValue
        let e = endDatePicker.dateValue
        setChartRange(start: s, end: e)
    }
}
