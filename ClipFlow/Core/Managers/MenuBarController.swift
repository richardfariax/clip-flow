import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject {
    private enum ItemTag: Int {
        case openDashboard = 999
        case openPanel = 1000
        case togglePause = 1001
        case settings = 1002
        case quit = 1003
        case toggleVoice = 1004
        case checkUpdates = 1005
        case systemMetrics = 1006
    }

    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let onOpenDashboard: () -> Void
    private let onOpenPanel: () -> Void
    private let onOpenSettings: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onTogglePause: (Bool) -> Void
    private let onToggleVoice: (Bool) -> Void
    private let onQuit: () -> Void
    private let isPausedProvider: () -> Bool
    private let isVoiceEnabledProvider: () -> Bool
    private let languageProvider: () -> AppLanguage
    private let updateAvailableProvider: () -> Bool

    var statusBarButton: NSStatusBarButton? { statusItem.button }

    init(
        onOpenDashboard: @escaping () -> Void,
        onOpenPanel: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onTogglePause: @escaping (Bool) -> Void,
        onToggleVoice: @escaping (Bool) -> Void,
        onQuit: @escaping () -> Void,
        isPausedProvider: @escaping () -> Bool,
        isVoiceEnabledProvider: @escaping () -> Bool,
        languageProvider: @escaping () -> AppLanguage,
        updateAvailableProvider: @escaping () -> Bool
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.onOpenDashboard = onOpenDashboard
        self.onOpenPanel = onOpenPanel
        self.onOpenSettings = onOpenSettings
        self.onCheckForUpdates = onCheckForUpdates
        self.onTogglePause = onTogglePause
        self.onToggleVoice = onToggleVoice
        self.onQuit = onQuit
        self.isPausedProvider = isPausedProvider
        self.isVoiceEnabledProvider = isVoiceEnabledProvider
        self.languageProvider = languageProvider
        self.updateAvailableProvider = updateAvailableProvider
        super.init()

        configureStatusItem()
        configureMenu()
    }

    func refreshPauseState() {
        guard let pauseItem = menu.item(withTag: ItemTag.togglePause.rawValue) else { return }
        pauseItem.state = isPausedProvider() ? .on : .off
    }

    func refreshVoiceState() {
        guard let voiceItem = menu.item(withTag: ItemTag.toggleVoice.rawValue) else { return }
        voiceItem.state = isVoiceEnabledProvider() ? .on : .off
    }

    func refreshAppearance() {
        applyStatusItemIcon()
    }

    func refreshUpdateItem() {
        guard let updates = menu.item(withTag: ItemTag.checkUpdates.rawValue) else { return }
        updates.title = updateMenuTitle()
    }

    func refreshSystemMetrics(_ snapshot: SystemMetricsSnapshot) {
        guard let item = menu.item(withTag: ItemTag.systemMetrics.rawValue) else { return }
        let cpu = snapshot.cpu.total.formatted(.percent.precision(.fractionLength(0)))
        let memory = snapshot.memory.usedFraction.formatted(.percent.precision(.fractionLength(0)))
        let gpu = snapshot.gpu?.device.formatted(.percent.precision(.fractionLength(0))) ?? "—"
        let temperature = snapshot.thermal.peakTemperature.map { String(format: "%.0f°C", $0) } ?? "—"
        let fans = snapshot.fans.averageRPM.map { String(format: "%.0f RPM", $0) } ?? "— RPM"
        item.title = "CPU \(cpu)  ·  RAM \(memory)  ·  GPU \(gpu)  ·  \(temperature)  ·  \(fans)"
    }

    func refreshLocalizedContent() {
        guard let openDashboard = menu.item(withTag: ItemTag.openDashboard.rawValue),
              let openPanel = menu.item(withTag: ItemTag.openPanel.rawValue),
              let pause = menu.item(withTag: ItemTag.togglePause.rawValue),
              let voice = menu.item(withTag: ItemTag.toggleVoice.rawValue),
              let updates = menu.item(withTag: ItemTag.checkUpdates.rawValue),
              let settings = menu.item(withTag: ItemTag.settings.rawValue),
              let quit = menu.item(withTag: ItemTag.quit.rawValue) else {
            return
        }

        openDashboard.title = t("Abrir Central do Mac", "Open Mac Command Center")
        openPanel.title = t("Abrir Clipboard", "Open Clipboard")
        pause.title = t("Pausar Monitoramento", "Pause Monitoring")
        voice.title = t("Comandos de Voz", "Voice Commands")
        updates.title = updateMenuTitle()
        settings.title = t("Preferências...", "Preferences...")
        quit.title = t("Sair do ClipFlow", "Quit ClipFlow")
    }

    private func updateMenuTitle() -> String {
        if updateAvailableProvider() {
            return t("Atualização Disponível...", "Update Available...")
        }
        return t("Buscar Atualizações...", "Check for Updates...")
    }

    private func configureStatusItem() {
        applyStatusItemIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = t(
            "Clique para abrir Ajustes · botão direito para o menu",
            "Click to open Settings · right-click for menu"
        )
    }

    private func applyStatusItemIcon() {
        if let button = statusItem.button {
            if let menuBarLogo = NSImage(named: menuBarLogoAssetName(for: button.effectiveAppearance)) {
                menuBarLogo.size = NSSize(width: 18, height: 18)
                menuBarLogo.isTemplate = false
                button.image = menuBarLogo
            } else {
                button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipFlow")
            }
        }
    }

    private func menuBarLogoAssetName(for appearance: NSAppearance) -> String {
        let best = appearance.bestMatch(from: [.darkAqua, .aqua])
        return best == .darkAqua ? "ClipFlowLogoDark" : "ClipFlowLogoLight"
    }

    private func configureMenu() {
        menu.autoenablesItems = false

        let dashboardItem = NSMenuItem(
            title: t("Abrir Central do Mac", "Open Mac Command Center"),
            action: #selector(openDashboard),
            keyEquivalent: ""
        )
        dashboardItem.target = self
        dashboardItem.tag = ItemTag.openDashboard.rawValue
        menu.addItem(dashboardItem)

        let metricsItem = NSMenuItem(title: "CPU —  ·  RAM —  ·  GPU —  ·  —", action: nil, keyEquivalent: "")
        metricsItem.tag = ItemTag.systemMetrics.rawValue
        metricsItem.isEnabled = false
        menu.addItem(metricsItem)

        menu.addItem(.separator())

        let openPanelItem = NSMenuItem(title: t("Abrir Clipboard", "Open Clipboard"), action: #selector(openPanel), keyEquivalent: "")
        openPanelItem.target = self
        openPanelItem.tag = ItemTag.openPanel.rawValue
        menu.addItem(openPanelItem)

        let pauseItem = NSMenuItem(title: t("Pausar Monitoramento", "Pause Monitoring"), action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.tag = ItemTag.togglePause.rawValue
        pauseItem.state = isPausedProvider() ? .on : .off
        menu.addItem(pauseItem)

        let voiceItem = NSMenuItem(title: t("Comandos de Voz", "Voice Commands"), action: #selector(toggleVoice), keyEquivalent: "")
        voiceItem.target = self
        voiceItem.tag = ItemTag.toggleVoice.rawValue
        voiceItem.state = isVoiceEnabledProvider() ? .on : .off
        menu.addItem(voiceItem)

        menu.addItem(.separator())

        let updatesItem = NSMenuItem(title: updateMenuTitle(), action: #selector(checkForUpdates), keyEquivalent: "")
        updatesItem.target = self
        updatesItem.tag = ItemTag.checkUpdates.rawValue
        menu.addItem(updatesItem)

        let settingsItem = NSMenuItem(title: t("Preferências...", "Preferences..."), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.tag = ItemTag.settings.rawValue
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: t("Sair do ClipFlow", "Quit ClipFlow"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.tag = ItemTag.quit.rawValue
        menu.addItem(quitItem)
    }

    @objc private func openPanel() {
        onOpenPanel()
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY - 4), in: sender)
        } else {
            onOpenSettings()
        }
    }

    @objc private func openDashboard() {
        onOpenDashboard()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc private func togglePause() {
        let updated = !isPausedProvider()
        onTogglePause(updated)
        refreshPauseState()
    }

    @objc private func toggleVoice() {
        let updated = !isVoiceEnabledProvider()
        onToggleVoice(updated)
        refreshVoiceState()
    }

    @objc private func quitApp() {
        onQuit()
    }

    private func t(_ pt: String, _ en: String) -> String {
        languageProvider().text(ptBR: pt, en: en)
    }
}

@MainActor
final class MenuBarMetricsController: NSObject {
    private let settings: AppSettings
    private let onPresentPopover: (NSView, MenuBarMetric) -> Void
    private var statusItems: [MenuBarMetric: NSStatusItem] = [:]
    private var configuredStyles: [MenuBarMetric: MenuBarMetricStyle] = [:]
    private var presentations: [MenuBarMetric: MenuBarMetricPresentation] = [:]
    private var overflowMetrics: Set<MenuBarMetric> = []
    private var overflowEvaluationScheduled = false
    private lazy var overflowPanel = MenuBarOverflowPanelController(onSelectMetric: onPresentPopover)

    init(
        settings: AppSettings,
        onPresentPopover: @escaping (NSView, MenuBarMetric) -> Void
    ) {
        self.settings = settings
        self.onPresentPopover = onPresentPopover
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        refreshConfiguration()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refreshConfiguration() {
        let updatedStyles = Dictionary(uniqueKeysWithValues: MenuBarMetric.allCases.map {
            ($0, settings.menuBarStyle(for: $0))
        })
        guard updatedStyles != configuredStyles else {
            return
        }

        configuredStyles = updatedStyles
        overflowMetrics.removeAll()
        overflowPanel.hide()

        for item in statusItems.values {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()

        for metric in MenuBarMetric.allCases {
            if updatedStyles[metric] != .hidden {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                item.autosaveName = "ClipFlow.metrics.\(metric.rawValue)"
                item.button?.target = self
                item.button?.action = #selector(openPopover(_:))
                item.button?.sendAction(on: [.leftMouseUp])
                if let button = item.button {
                    MenuBarMetricChrome.configure(button)
                }
                statusItems[metric] = item
            }
        }

        scheduleOverflowEvaluation()
    }

    func update(
        snapshot: SystemMetricsSnapshot,
        cpuHistory: [MetricHistoryPoint],
        memoryHistory: [MetricHistoryPoint],
        gpuHistory: [MetricHistoryPoint],
        temperatureHistory: [MetricHistoryPoint],
        fanHistory: [MetricHistoryPoint],
        storageHistory: [MetricHistoryPoint],
        networkHistory: [MetricHistoryPoint],
        powerHistory: [MetricHistoryPoint]
    ) {
        refreshConfiguration()
        render(.cpu, text: "CPU \(percent(snapshot.cpu.total))", history: cpuHistory, range: 0 ... 1)
        render(.gpu, text: "GPU \(snapshot.gpu.map { percent($0.device) } ?? "—")", history: gpuHistory, range: 0 ... 1)
        render(.memory, text: "RAM \(percent(snapshot.memory.usedFraction))", history: memoryHistory, range: 0 ... 1)
        render(
            .temperature,
            text: snapshot.thermal.peakTemperature.map { String(format: "%.0f°C", $0) } ?? "—°C",
            history: temperatureHistory,
            range: 20 ... 110
        )
        render(
            .fans,
            text: fanText(snapshot.fans),
            history: fanHistory,
            range: 0 ... snapshot.fans.chartMaximum
        )
        render(.storage, text: "SSD \(percent(snapshot.storage.usedFraction))", history: storageHistory, range: 0 ... 1)
        render(
            .network,
            text: "↓\(rate(snapshot.network.downloadBytesPerSecond)) ↑\(rate(snapshot.network.uploadBytesPerSecond))",
            history: networkHistory,
            range: adaptiveRange(for: networkHistory)
        )
        render(
            .power,
            text: powerText(snapshot.power),
            history: powerHistory,
            range: adaptiveRange(for: powerHistory)
        )

        if !overflowMetrics.isEmpty {
            updateOverflowPanel()
        }
        scheduleOverflowEvaluation()
    }

    private func render(
        _ metric: MenuBarMetric,
        text: String,
        history: [MetricHistoryPoint],
        range: ClosedRange<Double>
    ) {
        let style = settings.menuBarStyle(for: metric)
        let title = style == .text || style == .textAndGraph ? text : ""
        let image = style == .graph || style == .textAndGraph
            ? MenuBarSparklineRenderer.image(values: history.suffix(36).map(\.value), range: range)
            : nil
        let presentation = MenuBarMetricPresentation(
            metric: metric,
            title: title,
            image: image,
            imagePosition: style == .textAndGraph ? .imageLeading : (style == .graph ? .imageOnly : .noImage),
            toolTip: tooltip(for: metric, value: text)
        )
        presentations[metric] = presentation

        guard let item = statusItems[metric], let button = item.button else { return }
        button.title = presentation.title
        button.image = presentation.image
        button.imagePosition = presentation.imagePosition
        button.toolTip = presentation.toolTip
        button.setAccessibilityLabel(presentation.toolTip)
        item.length = MenuBarMetricLayout.compactStatusItemLength(
            titleWidth: presentation.titleWidth(using: button.font),
            imageWidth: presentation.image?.size.width ?? 0,
            showsTitleAndImage: presentation.imagePosition == .imageLeading
        )
    }

    private func tooltip(for metric: MenuBarMetric, value: String) -> String {
        let name: String = switch metric {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: settings.text(ptBR: "Memória", en: "Memory")
        case .temperature: settings.text(ptBR: "Temperatura", en: "Temperature")
        case .fans: settings.text(ptBR: "Ventoinhas", en: "Fans")
        case .storage: settings.text(ptBR: "Armazenamento", en: "Storage")
        case .network: settings.text(ptBR: "Rede", en: "Network")
        case .power: settings.text(ptBR: "Energia", en: "Power")
        }
        return "\(name): \(value)"
    }

    private func powerText(_ power: PowerMetrics) -> String {
        let level = power.batteryLevel.map(percent)
        let watts = power.powerWatts.map { String(format: "%.1fW", $0) }
        if let level, let watts { return "⚡︎\(level) \(watts)" }
        if let level { return "⚡︎\(level)" }
        if let watts { return "⚡︎\(watts)" }
        return power.source == .external ? "⚡︎AC" : "⚡︎—"
    }

    private func fanText(_ fans: FanMetrics) -> String {
        guard let rpm = fans.averageRPM else { return "FAN — RPM" }
        return "FAN \(rpm.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))) RPM"
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        return "\(formatter.string(fromByteCount: Int64(max(bytesPerSecond, 0))))/s"
    }

    private func adaptiveRange(for history: [MetricHistoryPoint]) -> ClosedRange<Double> {
        let maximum = max(history.suffix(36).map(\.value).max() ?? 1, 1)
        return 0 ... maximum
    }

    @objc private func openPopover(_ sender: NSStatusBarButton) {
        guard let metric = statusItems.first(where: { $0.value.button === sender })?.key else { return }
        onPresentPopover(sender, metric)
    }

    private func scheduleOverflowEvaluation() {
        guard !statusItems.isEmpty, !overflowEvaluationScheduled else { return }
        overflowEvaluationScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.overflowEvaluationScheduled = false
            self.evaluateOverflow()
        }
    }

    private func evaluateOverflow() {
        guard !statusItems.isEmpty,
              let screen = statusItems.values.compactMap({ $0.button?.window?.screen }).first ?? NSScreen.main,
              let rightArea = screen.auxiliaryTopRightArea,
              screen.auxiliaryTopLeftArea != nil else {
            return
        }

        let geometry = statusItems.reduce(into: [MenuBarMetric: MenuBarItemGeometry]()) { result, entry in
            let metric = entry.key
            let item = entry.value
            guard let button = item.button, let window = button.window, !button.bounds.isEmpty else {
                return
            }
            result[metric] = MenuBarItemGeometry(
                frame: window.convertToScreen(button.convert(button.bounds, to: nil)),
                isWindowVisible: window.isVisible
            )
        }

        guard geometry.count == statusItems.count,
              !geometry.isEmpty else {
            return
        }

        let metricsToMove = MenuBarOverflowLayout.metricsToMoveLeft(
            items: geometry,
            rightArea: rightArea
        )
        guard !metricsToMove.isEmpty else { return }

        for metric in metricsToMove {
            guard let item = statusItems.removeValue(forKey: metric) else { continue }
            NSStatusBar.system.removeStatusItem(item)
            overflowMetrics.insert(metric)
        }
        updateOverflowPanel(on: screen)
        scheduleOverflowEvaluation()
    }

    private func updateOverflowPanel(on screen: NSScreen? = nil) {
        let content = MenuBarMetric.allCases.compactMap { metric -> MenuBarMetricPresentation? in
            guard overflowMetrics.contains(metric) else { return nil }
            return presentations[metric]
        }.reversed()
        let targetScreen = screen
            ?? NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil })
            ?? NSScreen.main
        overflowPanel.update(presentations: Array(content), on: targetScreen)
    }

    @objc private func screenParametersDidChange() {
        overflowMetrics.removeAll()
        overflowPanel.hide()
        configuredStyles = [:]
        refreshConfiguration()
    }
}

struct MenuBarItemGeometry: Equatable {
    let frame: NSRect
    let isWindowVisible: Bool
}

enum MenuBarMetricLayout {
    static let cornerRadius: CGFloat = 7
    static let itemSpacing: CGFloat = 4
    static let horizontalContentPadding: CGFloat = 6
    static let minimumHeight: CGFloat = 22

    private static let titleImageSpacing: CGFloat = 4
    private static let minimumStatusItemWidth: CGFloat = 34

    static func compactStatusItemLength(
        titleWidth: CGFloat,
        imageWidth: CGFloat,
        showsTitleAndImage: Bool
    ) -> CGFloat {
        let contentSpacing = showsTitleAndImage && titleWidth > 0 && imageWidth > 0
            ? titleImageSpacing
            : 0
        let contentWidth = titleWidth + imageWidth + contentSpacing
        return max(
            minimumStatusItemWidth,
            ceil(contentWidth + (horizontalContentPadding * 2))
        )
    }
}

private enum MenuBarMetricChrome {
    static func configure(_ button: NSStatusBarButton) {
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        button.contentTintColor = .labelColor

        guard let container = button.superview else { return }
        let background = MenuBarMetricBackgroundView()
        background.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(background, positioned: .below, relativeTo: button)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            background.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            background.heightAnchor.constraint(equalToConstant: MenuBarMetricLayout.minimumHeight)
        ])
    }
}

private final class MenuBarMetricBackgroundView: NSVisualEffectView {
    init() {
        super.init(frame: .zero)
        material = .menu
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = MenuBarMetricLayout.cornerRadius
        layer?.masksToBounds = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

enum MenuBarOverflowLayout {
    static func metricsToMoveLeft(
        items: [MenuBarMetric: MenuBarItemGeometry],
        rightArea: NSRect
    ) -> Set<MenuBarMetric> {
        // Keep at least the highest-priority metric native on the right. Removing
        // every item from one stale geometry snapshot makes the whole group jump
        // to the left before AppKit can reflow the remaining status items.
        guard items.count > 1 else { return [] }

        let tolerance = rightArea.insetBy(dx: -2, dy: -2)
        let hasVisibleItem = items.values.contains(where: \.isWindowVisible)
        let needsMoreSpace = items.values.contains { item in
            let isOutsideRightArea = !tolerance.contains(item.frame)
            let isIndividuallyHidden = hasVisibleItem && !item.isWindowVisible
            return isOutsideRightArea || isIndividuallyHidden
        }
        guard needsMoreSpace else { return [] }

        // AppKit places the first-created metric nearest the existing menu extras.
        // Overflow one low-priority item at a time, then measure the native side
        // again. This fills the area beside the microphone before using the left.
        guard let metric = MenuBarMetric.allCases.reversed().first(where: { items[$0] != nil }) else {
            return []
        }
        return [metric]
    }
}

private struct MenuBarMetricPresentation {
    let metric: MenuBarMetric
    let title: String
    let image: NSImage?
    let imagePosition: NSControl.ImagePosition
    let toolTip: String

    func titleWidth(using font: NSFont?) -> CGFloat {
        guard !title.isEmpty else { return 0 }
        return (title as NSString).size(withAttributes: [
            .font: font ?? NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        ]).width
    }
}

@MainActor
private final class MenuBarOverflowPanelController: NSObject {
    private static let minimumMenuReservation: CGFloat = 360
    private static let horizontalMargin: CGFloat = 7

    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let contentView = NSView()
    private let stackView = NSStackView()
    private let onSelectMetric: (NSView, MenuBarMetric) -> Void
    private var buttons: [MenuBarMetric: MenuBarOverflowButton] = [:]

    init(onSelectMetric: @escaping (NSView, MenuBarMetric) -> Void) {
        self.onSelectMetric = onSelectMetric
        super.init()

        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = MenuBarMetricLayout.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        panel.contentView = contentView
    }

    func update(presentations: [MenuBarMetricPresentation], on screen: NSScreen?) {
        guard let screen,
              let leftArea = screen.auxiliaryTopLeftArea,
              !presentations.isEmpty else {
            hide()
            return
        }

        rebuildButtonsIfNeeded(for: presentations)
        for presentation in presentations {
            guard let button = buttons[presentation.metric] else { continue }
            button.title = presentation.title
            button.image = presentation.image
            button.imagePosition = presentation.imagePosition
            button.toolTip = presentation.toolTip
            button.setAccessibilityLabel(presentation.toolTip)
        }

        stackView.layoutSubtreeIfNeeded()
        let availableWidth = max(
            leftArea.width - Self.minimumMenuReservation - (Self.horizontalMargin * 2),
            80
        )
        let width = min(ceil(stackView.fittingSize.width), availableWidth)
        let height = min(max(NSStatusBar.system.thickness, 24), leftArea.height)
        let frame = NSRect(
            x: leftArea.maxX - width - Self.horizontalMargin,
            y: leftArea.midY - (height / 2),
            width: width,
            height: height
        )

        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func rebuildButtonsIfNeeded(for presentations: [MenuBarMetricPresentation]) {
        let metrics = presentations.map(\.metric)
        guard Set(metrics) != Set(buttons.keys) else { return }

        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buttons.removeAll()

        for metric in metrics {
            let itemView = MenuBarOverflowItemView(metric: metric)
            let button = itemView.button
            button.target = self
            button.action = #selector(selectMetric(_:))
            stackView.addArrangedSubview(itemView)
            buttons[metric] = button
        }
    }

    @objc private func selectMetric(_ sender: MenuBarOverflowButton) {
        onSelectMetric(sender, sender.metric)
    }
}

private final class MenuBarOverflowItemView: NSVisualEffectView {
    let button: MenuBarOverflowButton

    init(metric: MenuBarMetric) {
        button = MenuBarOverflowButton(metric: metric)
        super.init(frame: .zero)

        material = .menu
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = MenuBarMetricLayout.cornerRadius
        layer?.masksToBounds = true

        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: MenuBarMetricLayout.horizontalContentPadding
            ),
            button.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -MenuBarMetricLayout.horizontalContentPadding
            ),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: MenuBarMetricLayout.minimumHeight)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

private final class MenuBarOverflowButton: NSButton {
    let metric: MenuBarMetric

    init(metric: MenuBarMetric) {
        self.metric = metric
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .inline
        font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        contentTintColor = .labelColor
        focusRingType = .none
        setButtonType(.momentaryChange)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

private enum MenuBarSparklineRenderer {
    static func image(values: [Double], range: ClosedRange<Double>) -> NSImage {
        let size = NSSize(width: 31, height: 16)
        return NSImage(size: size, flipped: false) { bounds in
            guard values.count > 1 else { return true }
            let denominator = max(range.upperBound - range.lowerBound, 0.000_001)
            let path = NSBezierPath()
            path.lineWidth = 1.6
            path.lineJoinStyle = .round
            path.lineCapStyle = .round

            for (index, value) in values.enumerated() {
                let x = bounds.minX + CGFloat(index) / CGFloat(values.count - 1) * bounds.width
                let normalized = min(max((value - range.lowerBound) / denominator, 0), 1)
                let y = bounds.minY + 1 + CGFloat(normalized) * (bounds.height - 2)
                if index == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
            }
            NSColor.controlAccentColor.setStroke()
            path.stroke()
            return true
        }
    }
}
