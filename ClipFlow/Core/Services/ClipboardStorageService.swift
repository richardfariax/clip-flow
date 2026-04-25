import AppKit
import Foundation
import SwiftData

@MainActor
final class ClipboardStorageService {
    private let modelContext: ModelContext
    private let settings: AppSettings
    private let cryptoService: LocalCryptoService

    init(modelContext: ModelContext, settings: AppSettings, cryptoService: LocalCryptoService) {
        self.modelContext = modelContext
        self.settings = settings
        self.cryptoService = cryptoService
    }

    func insert(snapshot: ClipboardSnapshot, sourceBundleID: String?) {
        do {
            if try isConsecutiveDuplicate(hash: snapshot.contentHash) {
                return
            }

            let finalPayload: Data
            let encrypted: Bool
            if settings.enableEncryption {
                finalPayload = try cryptoService.encrypt(snapshot.payload)
                encrypted = true
            } else {
                finalPayload = snapshot.payload
                encrypted = false
            }

            let entity = ClipboardItemEntity(
                createdAt: snapshot.createdAt,
                updatedAt: snapshot.createdAt,
                kindRaw: snapshot.kind.rawValue,
                textSubtypeRaw: snapshot.textSubtype?.rawValue,
                payload: finalPayload,
                isEncrypted: encrypted,
                contentHash: snapshot.contentHash,
                sourceBundleID: sourceBundleID
            )

            modelContext.insert(entity)
            try enforceHistoryLimit()
            try modelContext.save()
        } catch {
            NSLog("[ClipFlow] Falha ao salvar item do clipboard: \(error.localizedDescription)")
        }
    }

    func fetchItems() -> [ClipboardItemEntity] {
        let descriptor = FetchDescriptor<ClipboardItemEntity>()
        let items = (try? modelContext.fetch(descriptor)) ?? []
        return items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    func decode(_ entity: ClipboardItemEntity) -> DecodedClipboardItem? {
        let kind = ClipboardContentKind(rawValue: entity.kindRaw)
        guard let kind else { return nil }

        do {
            let rawPayload = try decryptIfNeeded(entity)
            switch kind {
            case .text:
                let text = String(data: rawPayload, encoding: .utf8)
                return DecodedClipboardItem(
                    id: entity.id,
                    createdAt: entity.createdAt,
                    kind: .text,
                    textSubtype: entity.textSubtypeRaw.flatMap(ClipboardTextSubtype.init(rawValue:)),
                    text: text,
                    image: nil,
                    isFavorite: entity.isFavorite,
                    isPinned: entity.isPinned,
                    isEncrypted: entity.isEncrypted,
                    sourceBundleID: entity.sourceBundleID
                )
            case .image:
                let image = NSImage(data: rawPayload)
                return DecodedClipboardItem(
                    id: entity.id,
                    createdAt: entity.createdAt,
                    kind: .image,
                    textSubtype: nil,
                    text: nil,
                    image: image,
                    isFavorite: entity.isFavorite,
                    isPinned: entity.isPinned,
                    isEncrypted: entity.isEncrypted,
                    sourceBundleID: entity.sourceBundleID
                )
            }
        } catch {
            NSLog("[ClipFlow] Falha ao decodificar item: \(error.localizedDescription)")
            return nil
        }
    }

    func toggleFavorite(itemID: UUID) {
        update(itemID: itemID) { item in
            item.isFavorite.toggle()
        }
    }

    func togglePin(itemID: UUID) {
        update(itemID: itemID) { item in
            item.isPinned.toggle()
            item.updatedAt = Date()
        }
    }

    func delete(itemID: UUID) {
        let descriptor = FetchDescriptor<ClipboardItemEntity>(predicate: #Predicate { $0.id == itemID })
        guard let found = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(found)
        try? modelContext.save()
    }

    func clearAll() {
        let descriptor = FetchDescriptor<ClipboardItemEntity>()
        let items = (try? modelContext.fetch(descriptor)) ?? []
        for item in items {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func update(itemID: UUID, block: (ClipboardItemEntity) -> Void) {
        let descriptor = FetchDescriptor<ClipboardItemEntity>(predicate: #Predicate { $0.id == itemID })
        guard let item = try? modelContext.fetch(descriptor).first else { return }
        block(item)
        item.updatedAt = Date()
        try? modelContext.save()
    }

    private func decryptIfNeeded(_ item: ClipboardItemEntity) throws -> Data {
        if item.isEncrypted {
            return try cryptoService.decrypt(item.payload)
        }
        return item.payload
    }

    private func isConsecutiveDuplicate(hash: String) throws -> Bool {
        let descriptor = FetchDescriptor<ClipboardItemEntity>()
        let latest = try modelContext.fetch(descriptor).max { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }
        return latest?.contentHash == hash
    }

    private func enforceHistoryLimit() throws {
        let limit = settings.historyLimit
        let descriptor = FetchDescriptor<ClipboardItemEntity>()
        let allItems = try modelContext.fetch(descriptor).sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }

        guard allItems.count > limit else {
            return
        }

        var overflow = allItems.count - limit
        let removable = allItems.reversed().filter { !$0.isPinned }

        for item in removable where overflow > 0 {
            modelContext.delete(item)
            overflow -= 1
        }

        if overflow > 0 {
            // Se tudo estiver fixado, ainda mantém o limite para evitar crescimento infinito.
            let pinnedCandidates = allItems.reversed().filter { $0.isPinned }
            for item in pinnedCandidates where overflow > 0 {
                modelContext.delete(item)
                overflow -= 1
            }
        }
    }
}
