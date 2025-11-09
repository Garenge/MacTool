//
//  ThemeViewController.swift
//  MacTool
//
//  主题设置页面
//

import Cocoa

class ThemeViewController: NSViewController {
    
    // MARK: - Properties
    
    private var titleLabel: NSTextField!
    private var descriptionLabel: NSTextField!
    private var themeButtons: [NSButton] = []
    private var currentThemeIndicator: NSTextField!
    private var themeCards: [NSView] = []  // 保存主题卡片引用
    private var testContainer: NSView!  // 保存测试容器引用
    
    // 测试开关（用于快速测试主题切换）
    private var testSwitch: NSSwitch!
    private var testLabel: NSTextField!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateCurrentThemeIndicator()
        
        // 监听主题变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.themeDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        print("[ThemeViewController] 🎨 主题设置页面已显示")
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.wantsLayer = true
        
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 创建容器视图
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = containerView
        
        // 标题
        titleLabel = NSTextField(labelWithString: "🎨 主题设置")
        titleLabel.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // 描述
        descriptionLabel = NSTextField(labelWithString: "选择您喜欢的主题外观")
        descriptionLabel.font = NSFont.systemFont(ofSize: 14)
        descriptionLabel.alignment = .center
        descriptionLabel.textColor = ThemeColors.secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)
        
        // 当前主题指示器
        currentThemeIndicator = NSTextField(labelWithString: "")
        currentThemeIndicator.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        currentThemeIndicator.alignment = .center
        currentThemeIndicator.textColor = ThemeColors.accentColor
        currentThemeIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(currentThemeIndicator)
        
        // 主题选项容器
        let themesContainer = NSView()
        themesContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(themesContainer)
        
        // 创建主题选项卡片
        var previousCard: NSView?
        for theme in AppTheme.allCases {
            let card = createThemeCard(for: theme)
            themeCards.append(card)  // 保存引用
            themesContainer.addSubview(card)
            
            NSLayoutConstraint.activate([
                card.leadingAnchor.constraint(equalTo: themesContainer.leadingAnchor),
                card.trailingAnchor.constraint(equalTo: themesContainer.trailingAnchor),
                card.heightAnchor.constraint(equalToConstant: 80)
            ])
            
            if let previous = previousCard {
                card.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 15).isActive = true
            } else {
                card.topAnchor.constraint(equalTo: themesContainer.topAnchor).isActive = true
            }
            
            previousCard = card
        }
        
        if let lastCard = previousCard {
            themesContainer.bottomAnchor.constraint(equalTo: lastCard.bottomAnchor).isActive = true
        }
        
        // 分隔线
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(separator)
        
        // 测试区域标题
        let testTitle = NSTextField(labelWithString: "🧪 快速测试")
        testTitle.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        testTitle.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(testTitle)
        
        // 测试开关容器
        testContainer = NSView()
        testContainer.wantsLayer = true
        testContainer.layer?.backgroundColor = ThemeColors.secondaryBackgroundColor.cgColor
        testContainer.layer?.cornerRadius = 8
        testContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(testContainer)
        
        // 测试标签
        testLabel = NSTextField(labelWithString: "深色模式")
        testLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        testLabel.translatesAutoresizingMaskIntoConstraints = false
        testContainer.addSubview(testLabel)
        
        // 测试开关
        testSwitch = NSSwitch()
        testSwitch.target = self
        testSwitch.action = #selector(testSwitchToggled)
        testSwitch.state = ThemeManager.shared.isDarkMode ? .on : .off
        testSwitch.translatesAutoresizingMaskIntoConstraints = false
        testContainer.addSubview(testSwitch)
        
        let testDescription = NSTextField(labelWithString: "快速切换深色/浅色模式进行测试")
        testDescription.font = NSFont.systemFont(ofSize: 11)
        testDescription.textColor = ThemeColors.secondaryLabelColor
        testDescription.translatesAutoresizingMaskIntoConstraints = false
        testContainer.addSubview(testDescription)
        
        // 布局约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            currentThemeIndicator.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 15),
            currentThemeIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            themesContainer.topAnchor.constraint(equalTo: currentThemeIndicator.bottomAnchor, constant: 30),
            themesContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 60),
            themesContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -60),
            
            separator.topAnchor.constraint(equalTo: themesContainer.bottomAnchor, constant: 40),
            separator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            separator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            testTitle.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 30),
            testTitle.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 60),
            
            testContainer.topAnchor.constraint(equalTo: testTitle.bottomAnchor, constant: 15),
            testContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 60),
            testContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -60),
            testContainer.heightAnchor.constraint(equalToConstant: 70),
            testContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -40),
            
            testLabel.leadingAnchor.constraint(equalTo: testContainer.leadingAnchor, constant: 20),
            testLabel.centerYAnchor.constraint(equalTo: testContainer.centerYAnchor, constant: -10),
            
            testSwitch.trailingAnchor.constraint(equalTo: testContainer.trailingAnchor, constant: -20),
            testSwitch.centerYAnchor.constraint(equalTo: testLabel.centerYAnchor),
            
            testDescription.topAnchor.constraint(equalTo: testLabel.bottomAnchor, constant: 5),
            testDescription.leadingAnchor.constraint(equalTo: testContainer.leadingAnchor, constant: 20)
        ])
    }
    
    /// 创建主题卡片
    private func createThemeCard(for theme: AppTheme) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = ThemeColors.secondaryBackgroundColor.cgColor
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 2
        card.layer?.borderColor = (ThemeManager.shared.currentTheme == theme) ? 
            ThemeColors.accentColor.cgColor : NSColor.clear.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // 图标
        let iconLabel = NSTextField(labelWithString: theme.icon)
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        iconLabel.alignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconLabel)
        
        // 标题
        let titleLabel = NSTextField(labelWithString: theme.displayName)
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // 描述
        let descText = theme == .auto ? "自动跟随系统设置" : (theme == .light ? "适合白天使用" : "适合夜间使用")
        let descLabel = NSTextField(labelWithString: descText)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = ThemeColors.secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descLabel)
        
        // 选择按钮
        let button = NSButton(title: "选择", target: self, action: #selector(themeButtonClicked(_:)))
        button.bezelStyle = .rounded
        button.tag = theme.rawValue.hashValue
        button.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(button)
        themeButtons.append(button)
        
        // 存储主题信息
        button.identifier = NSUserInterfaceItemIdentifier(theme.rawValue)
        
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 50),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 15),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            button.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        return card
    }
    
    // MARK: - Actions
    
    @objc private func themeButtonClicked(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let theme = AppTheme(rawValue: identifier) else {
            return
        }
        
        ThemeManager.shared.currentTheme = theme
        updateThemeCards()
        updateCurrentThemeIndicator()
        updateTestSwitch()
    }
    
    @objc private func testSwitchToggled(_ sender: NSSwitch) {
        if sender.state == .on {
            ThemeManager.shared.currentTheme = .dark
        } else {
            ThemeManager.shared.currentTheme = .light
        }
    }
    
    @objc private func themeDidChange() {
        updateThemeCards()
        updateCurrentThemeIndicator()
        updateTestSwitch()
        updateColors()
    }
    
    // MARK: - Helper Methods
    
    private func updateThemeCards() {
        for case let card as NSView in view.subviews.first?.subviews.first?.subviews ?? [] {
            if card.layer?.cornerRadius == 10 {
                // 找到对应的按钮
                for subview in card.subviews {
                    if let button = subview as? NSButton,
                       let identifier = button.identifier?.rawValue,
                       let theme = AppTheme(rawValue: identifier) {
                        card.layer?.borderColor = (ThemeManager.shared.currentTheme == theme) ?
                            ThemeColors.accentColor.cgColor : NSColor.clear.cgColor
                    }
                }
            }
        }
    }
    
    private func updateCurrentThemeIndicator() {
        let theme = ThemeManager.shared.currentTheme
        currentThemeIndicator.stringValue = "当前主题：\(theme.icon) \(theme.displayName)"
    }
    
    private func updateTestSwitch() {
        testSwitch.state = ThemeManager.shared.isDarkMode ? .on : .off
    }
    
    private func updateColors() {
        view.layer?.backgroundColor = ThemeColors.backgroundColor.cgColor
        
        // 更新主题卡片背景
        for card in themeCards {
            card.layer?.backgroundColor = ThemeColors.secondaryBackgroundColor.cgColor
        }
        
        // 更新测试容器背景
        testContainer?.layer?.backgroundColor = ThemeColors.secondaryBackgroundColor.cgColor
        
        // 更新文本颜色
        titleLabel.textColor = ThemeColors.labelColor
        descriptionLabel.textColor = ThemeColors.secondaryLabelColor
        currentThemeIndicator.textColor = ThemeColors.accentColor
    }
}
