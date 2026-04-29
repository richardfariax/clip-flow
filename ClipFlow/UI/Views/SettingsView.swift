import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionsManager: PermissionsManager

    let launchManager: LaunchAtLoginManager
    let onRebindHotkey: () -> Void

    @State private var launchAtLoginError: String?
    @State private var selectedHotkeyPresetID: String = HotkeyPreset.customID

    @State private var availableApps: [InstalledApplication] = []
    @State private var appSearchText: String = ""
    @State private var selectedAvailableAppBundleID: String?
    @State private var selectedIgnoredAppBundleID: String?
    @State private var isLoadingAvailableApps = false
    @State private var isAddIgnoredAppSheetPresented = false
    @State private var isHoveringIgnoredAppsGrid = false
    @State private var isRecordingCustomHotkey = false
    @State private var hotkeyRecorderMonitor: AnyObject?
    @State private var hotkeyRecorderMessage: String?

    private let labelColumnWidth: CGFloat = 210
    private let defaultControlWidth: CGFloat = 250

    private let creditsURL = URL(string: "https://www.linkedin.com/in/richardfariasss/")!
    private static let topScrollAnchorID = "settings-top-anchor"

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundLayer

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Color.clear
                        .frame(height: 0)
                        .id(Self.topScrollAnchorID)

                    VStack(alignment: .leading, spacing: 12) {
                        header

                        generalSection
                        hotkeySection
                        ignoredAppsSection
                        permissionsSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .scrollIndicators(.visible)
                .scrollDisabled(isHoveringIgnoredAppsGrid)
                .onAppear {
                    scrollSettingsToTop(using: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .clipFlowSettingsShouldScrollToTop)) { _ in
                    scrollSettingsToTop(using: proxy)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 760)
        .onAppear {
            settings.launchAtLogin = launchManager.isEnabled
            permissionsManager.refresh()
            syncHotkeyPresetState()
            loadAvailableAppsIfNeeded()
        }
        .onChange(of: settings.hotkeyCode, initial: false) { _, _ in
            syncHotkeyPresetState()
        }
        .onChange(of: settings.hotkeyModifiers, initial: false) { _, _ in
            syncHotkeyPresetState()
        }
        .sheet(isPresented: $isAddIgnoredAppSheetPresented) {
            addIgnoredAppsSheet
        }
        .onDisappear {
            stopHotkeyRecording()
        }
    }

    private var backgroundLayer: some View {
        VisualEffectBlur(material: .windowBackground, blendingMode: .withinWindow)
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                BrandLogoView(size: 28, cornerRadius: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text("ClipFlow")
                        .font(.title3.weight(.semibold))

                    Text(t("Preferências", "Preferences"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(t("Desenvolvido por", "Built by"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("Richard Farias", destination: creditsURL)
                    .font(.caption.weight(.medium))
            }
            .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private var generalSection: some View {
        cardSection(
            title: t("Geral", "General"),
            subtitle: t("Configurações principais do app", "Main app behavior settings"),
            fillsWidth: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                alignedConfigRow(title: t("Limite do Histórico", "History Limit")) {
                    Picker("", selection: $settings.historyLimit) {
                        Text("100").tag(100)
                        Text("500").tag(500)
                        Text("1000").tag(1000)
                    }
                    .labelsHidden()
                }

                alignedConfigRow(title: t("Idioma", "Language")) {
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                }

                alignedConfigRow(title: t("Aparência", "Appearance")) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title(for: settings.language)).tag(appearance)
                        }
                    }
                    .labelsHidden()
                }

                alignedConfigRow(title: t("Iniciar com o macOS", "Launch at Login")) {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                }

                if let launchAtLoginError {
                    alignedConfigNote(launchAtLoginError, color: .red)
                }

                Divider()

                alignedConfigRow(title: t("Pausar monitoramento", "Pause monitoring")) {
                    Toggle("", isOn: $settings.pauseMonitoring)
                        .labelsHidden()
                }

                alignedConfigRow(title: t("Criptografia local (AES-GCM)", "Local encryption (AES-GCM)")) {
                    Toggle("", isOn: $settings.enableEncryption)
                        .labelsHidden()
                }
            }
        }
    }

    private var hotkeySection: some View {
        cardSection(
            title: t("Atalho Global", "Global Hotkey"),
            subtitle: t("Abertura rápida do painel", "Quick panel access"),
            fillsWidth: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                alignedConfigRow(title: t("Atalho atual", "Current hotkey"), controlWidth: 320) {
                    Text(settings.hotkeyDisplay)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                alignedConfigRow(title: t("Preset de Atalho", "Hotkey Preset"), controlWidth: 320) {
                    Picker("", selection: $selectedHotkeyPresetID) {
                        ForEach(HotkeyPreset.all) { preset in
                            Text(preset.title(for: settings.language)).tag(preset.id)
                        }
                        Text(t("Personalizado", "Custom")).tag(HotkeyPreset.customID)
                    }
                    .labelsHidden()
                }
                .onChange(of: selectedHotkeyPresetID, initial: false) { _, newValue in
                    guard let selectedPreset = HotkeyPreset.all.first(where: { $0.id == newValue }) else {
                        return
                    }

                    settings.hotkeyCode = selectedPreset.keyCode
                    settings.hotkeyModifiers = selectedPreset.modifiers
                    onRebindHotkey()
                }

                if selectedHotkeyPresetID == HotkeyPreset.customID {
                    alignedConfigRow(title: t("Atalho personalizado", "Custom hotkey"), controlWidth: 320) {
                        Button(
                            isRecordingCustomHotkey
                                ? t("Pressione a combinação...", "Press key combination...")
                                : t("Gravar atalho", "Record shortcut")
                        ) {
                            if isRecordingCustomHotkey {
                                stopHotkeyRecording()
                            } else {
                                startHotkeyRecording()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    alignedConfigNote(
                        t(
                            "Use ao menos uma tecla modificadora (Command, Option, Control ou Shift).",
                            "Use at least one modifier key (Command, Option, Control, or Shift)."
                        )
                    )

                    if let hotkeyRecorderMessage {
                        alignedConfigNote(hotkeyRecorderMessage, color: .orange)
                    }
                }
            }
        }
    }

    private var ignoredAppsSection: some View {
        cardSection(
            title: t("Apps Ignorados", "Ignored Apps"),
            subtitle: t("Proteção para apps sensíveis", "Protection for sensitive apps"),
            fillsWidth: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button(t("Adicionar...", "Add...")) {
                        presentAddIgnoredAppsSheet()
                    }
                    .buttonStyle(.bordered)

                    Button(t("Remover", "Remove")) {
                        removeSelectedIgnoredApp()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedIgnoredAppBundleID == nil)

                    Spacer(minLength: 0)

                    if isLoadingAvailableApps {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ignoredAppsGrid
            }
        }
    }

    private var addIgnoredAppsSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Adicionar App Ignorado", "Add Ignored App"))
                .font(.headline)

            TextField(t("Buscar por nome do app", "Search by app name"), text: $appSearchText)
                .textFieldStyle(.roundedBorder)

            if filteredAvailableApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    Text(t("Nenhum app encontrado", "No apps found"))
                        .font(.subheadline.weight(.semibold))

                    Text(t("Tente outro nome de app.", "Try another app name."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                )
            } else {
                List(filteredAvailableApps, selection: $selectedAvailableAppBundleID) { app in
                    ApplicationListRow(app: app, showBundleID: false)
                        .tag(app.bundleID)
                }
                .frame(minHeight: 320)
            }

            HStack {
                Text("\(filteredAvailableApps.count) \(t("apps encontrados", "apps found"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(t("Cancelar", "Cancel")) {
                    isAddIgnoredAppSheetPresented = false
                }

                Button(t("Adicionar", "Add")) {
                    addSelectedAvailableApp()
                    isAddIgnoredAppSheetPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAvailableApp == nil)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 440)
    }

    private var permissionsSection: some View {
        cardSection(
            title: t("Permissões", "Permissions"),
            subtitle: t("Necessárias para hotkeys e colagem automática", "Required for hotkeys and automatic paste"),
            fillsWidth: true
        ) {
            PermissionsView(permissionsManager: permissionsManager, settings: settings)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { newValue in
                do {
                    try launchManager.setEnabled(newValue)
                    settings.launchAtLogin = launchManager.isEnabled
                    launchAtLoginError = nil
                } catch {
                    settings.launchAtLogin = launchManager.isEnabled
                    launchAtLoginError = error.localizedDescription
                }
            }
        )
    }

    private func cardSection<Content: View>(
        title: String,
        subtitle: String,
        fillsWidth: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.50))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1.0)
                )
        )
    }

    private func alignedConfigRow<Control: View>(
        title: String,
        controlWidth: CGFloat? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(width: labelColumnWidth, alignment: .leading)

            Spacer(minLength: 0)

            control()
                .frame(width: controlWidth ?? defaultControlWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func alignedConfigNote(_ text: String, color: Color = .secondary) -> some View {
        HStack(spacing: 12) {
            Spacer()
                .frame(width: labelColumnWidth)

            Text(text)
                .font(.caption)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func syncHotkeyPresetState() {
        selectedHotkeyPresetID = HotkeyPreset
            .matching(keyCode: settings.hotkeyCode, modifiers: settings.hotkeyModifiers)?
            .id ?? HotkeyPreset.customID
    }

    private func presentAddIgnoredAppsSheet() {
        loadAvailableAppsIfNeeded()
        appSearchText = ""
        selectedAvailableAppBundleID = nil
        isAddIgnoredAppSheetPresented = true
    }

    private func loadAvailableAppsIfNeeded() {
        guard availableApps.isEmpty, !isLoadingAvailableApps else {
            return
        }

        isLoadingAvailableApps = true
        Task.detached(priority: .userInitiated) {
            let apps = discoverInstalledApplications()
            await MainActor.run {
                self.availableApps = apps
                self.isLoadingAvailableApps = false
            }
        }
    }

    private func addSelectedAvailableApp() {
        guard let selectedAvailableApp else {
            return
        }

        var updated = settings.ignoredBundleIDs
        updated.append(selectedAvailableApp.bundleID)
        settings.ignoredBundleIDs = updated
        selectedIgnoredAppBundleID = selectedAvailableApp.bundleID
    }

    private func removeSelectedIgnoredApp() {
        guard let selectedIgnoredAppBundleID else {
            return
        }

        settings.ignoredBundleIDs.removeAll { $0 == selectedIgnoredAppBundleID }
        self.selectedIgnoredAppBundleID = nil
    }

    private var filteredAvailableApps: [InstalledApplication] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ignored = Set(settings.ignoredBundleIDs)

        return availableApps.filter { app in
            guard !ignored.contains(app.bundleID) else {
                return false
            }

            guard !query.isEmpty else {
                return true
            }

            return app.name.lowercased().contains(query) || app.bundleID.lowercased().contains(query)
        }
    }

    private var selectedAvailableApp: InstalledApplication? {
        if let selectedAvailableAppBundleID,
           let app = filteredAvailableApps.first(where: { $0.bundleID == selectedAvailableAppBundleID }) {
            return app
        }

        if filteredAvailableApps.count == 1 {
            return filteredAvailableApps.first
        }

        return nil
    }

    private var ignoredGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8)
        ]
    }

    private var ignoredAppsGrid: some View {
        Group {
            if ignoredApplications.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.secondary)
                        .imageScale(.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("Nenhum app ignorado", "No ignored apps"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(t("Clique em Adicionar para escolher apps.", "Click Add to choose apps."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVGrid(columns: ignoredGridColumns, spacing: 8) {
                            ForEach(ignoredApplications) { app in
                                IgnoredAppGridItem(
                                    app: app,
                                    isSelected: selectedIgnoredAppBundleID == app.bundleID
                                )
                                .id(app.bundleID)
                                .onTapGesture {
                                    selectedIgnoredAppBundleID = app.bundleID
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: ignoredAppsGridHeight)
                    .scrollIndicators(.visible)
                    .onHover { hovering in
                        isHoveringIgnoredAppsGrid = hovering
                    }
                    .onAppear {
                        scrollIgnoredAppsGridToTop(using: proxy)
                    }
                    .onChange(of: settings.ignoredBundleIDs, initial: false) { _, _ in
                        scrollIgnoredAppsGridToTop(using: proxy)
                    }
                }
            }
        }
    }

    private var ignoredAppsGridHeight: CGFloat {
        let itemCount = ignoredApplications.count
        guard itemCount > 0 else {
            return 0
        }

        let columns = 3
        let rows = Int(ceil(Double(itemCount) / Double(columns)))
        let visibleRows = min(rows, 2)
        let rowHeight: CGFloat = 44
        let rowSpacing: CGFloat = 8

        return CGFloat(visibleRows) * rowHeight + CGFloat(max(visibleRows - 1, 0)) * rowSpacing + 2
    }

    private var ignoredApplications: [InstalledApplication] {
        settings.ignoredBundleIDs.map { bundleID in
            if let known = availableApps.first(where: { $0.bundleID == bundleID }) {
                return known
            }

            let knownURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            return InstalledApplication(
                bundleID: bundleID,
                name: fallbackAppName(from: bundleID),
                appPath: knownURL?.path
            )
        }
    }

    private func fallbackAppName(from bundleID: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }

        return bundleID
            .split(separator: ".")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? bundleID
    }

    private func scrollIgnoredAppsGridToTop(using proxy: ScrollViewProxy) {
        guard let firstBundleID = ignoredApplications.first?.bundleID else {
            return
        }

        DispatchQueue.main.async {
            proxy.scrollTo(firstBundleID, anchor: .top)
        }
    }

    private func scrollSettingsToTop(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(Self.topScrollAnchorID, anchor: .top)
            DispatchQueue.main.async {
                proxy.scrollTo(Self.topScrollAnchorID, anchor: .top)
            }
        }
    }

    private func startHotkeyRecording() {
        stopHotkeyRecording()
        hotkeyRecorderMessage = nil
        isRecordingCustomHotkey = true

        hotkeyRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard self.isRecordingCustomHotkey else {
                return event
            }

            let keyCode = UInt32(event.keyCode)
            let modifiers = HotkeyFormatter.carbonModifiers(from: event.modifierFlags)

            guard HotkeyFormatter.isValidShortcut(keyCode: keyCode, modifiers: modifiers) else {
                self.hotkeyRecorderMessage = self.t(
                    "Atalho inválido. Use uma tecla com modificador.",
                    "Invalid shortcut. Use a key with a modifier."
                )
                NSSound.beep()
                self.stopHotkeyRecording()
                return nil
            }

            self.settings.hotkeyCode = keyCode
            self.settings.hotkeyModifiers = modifiers
            self.selectedHotkeyPresetID = HotkeyPreset.customID
            self.onRebindHotkey()
            self.hotkeyRecorderMessage = self.t("Atalho atualizado.", "Shortcut updated.")
            self.stopHotkeyRecording()
            return nil
        } as AnyObject
    }

    private func stopHotkeyRecording() {
        isRecordingCustomHotkey = false

        if let hotkeyRecorderMonitor {
            NSEvent.removeMonitor(hotkeyRecorderMonitor)
            self.hotkeyRecorderMonitor = nil
        }
    }

    private func t(_ pt: String, _ en: String) -> String {
        settings.text(ptBR: pt, en: en)
    }
}

private extension Notification.Name {
    static let clipFlowSettingsShouldScrollToTop = Notification.Name("clipflow.settings.scrollToTop")
}

private struct InstalledApplication: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let appPath: String?

    var id: String { bundleID }

    var icon: NSImage {
        if let appPath {
            return NSWorkspace.shared.icon(forFile: appPath)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}

private struct ApplicationListRow: View {
    let app: InstalledApplication
    let showBundleID: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.subheadline)
                    .lineLimit(1)

                if showBundleID {
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct IgnoredAppGridItem: View {
    let app: InstalledApplication
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(app.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func discoverInstalledApplications() -> [InstalledApplication] {
    let fileManager = FileManager.default
    let appDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/Applications/Utilities"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]

    var seenBundleIDs: Set<String> = []
    var discovered: [InstalledApplication] = []

    for directory in appDirectories where fileManager.fileExists(atPath: directory.path) {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            continue
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else {
                continue
            }

            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier?.lowercased(),
                  !bundleID.isEmpty,
                  !seenBundleIDs.contains(bundleID) else {
                continue
            }

            let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent

            seenBundleIDs.insert(bundleID)
            discovered.append(InstalledApplication(bundleID: bundleID, name: displayName, appPath: url.path))
        }
    }

    return discovered.sorted {
        let lhs = $0.name.localizedCaseInsensitiveCompare($1.name)
        if lhs == .orderedSame {
            return $0.bundleID < $1.bundleID
        }
        return lhs == .orderedAscending
    }
}
