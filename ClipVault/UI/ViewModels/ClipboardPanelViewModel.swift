import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardPanelViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet { applyFiltering() }
    }
    @Published private(set) var items: [DecodedClipboardItem] = []
    @Published private(set) var selectedItemID: UUID?

    private let storageService: ClipboardStorageService
    private let pasteService: PasteService
    private let targetApplicationProvider: () -> NSRunningApplication?
    private var allItems: [DecodedClipboardItem] = []

    init(
        storageService: ClipboardStorageService,
        pasteService: PasteService,
        targetApplicationProvider: @escaping () -> NSRunningApplication?
    ) {
        self.storageService = storageService
        self.pasteService = pasteService
        self.targetApplicationProvider = targetApplicationProvider

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardUpdate),
            name: .clipboardDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refresh() {
        let entities = storageService.fetchItems()
        allItems = entities.compactMap(storageService.decode)
        applyFiltering()
    }

    func select(itemID: UUID) {
        selectedItemID = itemID
    }

    func moveSelection(upward: Bool) {
        guard !items.isEmpty else {
            selectedItemID = nil
            return
        }

        guard let selectedItemID,
              let currentIndex = items.firstIndex(where: { $0.id == selectedItemID }) else {
            selectedItemID = items.first?.id
            return
        }

        let nextIndex: Int
        if upward {
            nextIndex = max(currentIndex - 1, 0)
        } else {
            nextIndex = min(currentIndex + 1, items.count - 1)
        }
        self.selectedItemID = items[nextIndex].id
    }

    func paste(item: DecodedClipboardItem) {
        selectedItemID = item.id
        pasteService.paste(item: item, targetApplication: targetApplicationProvider())
    }

    func pasteSelectedItem() {
        guard let selectedItemID,
              let selected = items.first(where: { $0.id == selectedItemID }) else {
            return
        }
        paste(item: selected)
    }

    func toggleFavorite(itemID: UUID) {
        storageService.toggleFavorite(itemID: itemID)
        refresh()
    }

    func togglePin(itemID: UUID) {
        storageService.togglePin(itemID: itemID)
        refresh()
    }

    func delete(itemID: UUID) {
        storageService.delete(itemID: itemID)
        refresh()
    }

    func clearAll() {
        storageService.clearAll()
        refresh()
    }

    @objc private func handleClipboardUpdate() {
        refresh()
    }

    private func applyFiltering() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            items = allItems
            ensureValidSelection()
            return
        }

        let lowercasedQuery = query.lowercased()
        items = allItems.filter { item in
            if let text = item.text?.lowercased(), text.contains(lowercasedQuery) {
                return true
            }

            if let sourceBundleID = item.sourceBundleID?.lowercased(), sourceBundleID.contains(lowercasedQuery) {
                return true
            }

            return false
        }
        ensureValidSelection()
    }

    private func ensureValidSelection() {
        if items.isEmpty {
            selectedItemID = nil
            return
        }

        if let selectedItemID,
           items.contains(where: { $0.id == selectedItemID }) {
            return
        }

        self.selectedItemID = items.first?.id
    }
}
