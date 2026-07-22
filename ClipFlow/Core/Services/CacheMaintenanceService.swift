import Foundation

enum CacheCategory: String, CaseIterable, Identifiable, Sendable {
    case applicationCaches
    case developerBuilds
    case logs

    var id: String { rawValue }

    var rootURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .applicationCaches:
            return home.appendingPathComponent("Library/Caches", isDirectory: true)
        case .developerBuilds:
            return home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
        case .logs:
            return home.appendingPathComponent("Library/Logs", isDirectory: true)
        }
    }
}

struct CacheScanResult: Identifiable, Equatable, Sendable {
    let category: CacheCategory
    let bytes: UInt64
    let itemCount: Int

    var id: CacheCategory { category }
}

struct CacheCleanupResult: Equatable, Sendable {
    let reclaimedBytes: UInt64
    let movedItemCount: Int
    let failures: [String]
}

@MainActor
final class CacheMaintenanceService: ObservableObject {
    @Published private(set) var results: [CacheCategory: CacheScanResult] = [:]
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var lastCleanup: CacheCleanupResult?
    @Published private(set) var errorMessage: String?

    func scan() {
        guard !isScanning, !isCleaning else { return }
        isScanning = true
        errorMessage = nil

        Task {
            let scanned = await Task.detached(priority: .utility) {
                CacheCategory.allCases.map(Self.scanCategory)
            }.value
            results = Dictionary(uniqueKeysWithValues: scanned.map { ($0.category, $0) })
            isScanning = false
        }
    }

    func moveToTrash(categories: Set<CacheCategory>) {
        guard !categories.isEmpty, !isScanning, !isCleaning else { return }
        isCleaning = true
        errorMessage = nil

        Task {
            let cleanup = await Task.detached(priority: .utility) {
                Self.clean(categories: categories)
            }.value
            lastCleanup = cleanup
            errorMessage = cleanup.failures.isEmpty ? nil : cleanup.failures.joined(separator: "\n")
            isCleaning = false
            scan()
        }
    }

    private nonisolated static func scanCategory(_ category: CacheCategory) -> CacheScanResult {
        let fileManager = FileManager.default
        let root = category.rootURL
        guard fileManager.fileExists(atPath: root.path),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else {
            return CacheScanResult(category: category, bytes: 0, itemCount: 0)
        }

        var bytes: UInt64 = 0
        var itemCount = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey
            ]), values.isSymbolicLink != true, values.isRegularFile == true else { continue }
            bytes += UInt64(max(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0, 0))
            itemCount += 1
        }
        return CacheScanResult(category: category, bytes: bytes, itemCount: itemCount)
    }

    private nonisolated static func clean(categories: Set<CacheCategory>) -> CacheCleanupResult {
        let fileManager = FileManager.default
        let protectedCacheName = Bundle.main.bundleIdentifier ?? "com.richadfarias.clipflow"
        var reclaimedBytes: UInt64 = 0
        var movedItemCount = 0
        var failures: [String] = []

        for category in categories {
            let root = category.rootURL.standardizedFileURL
            guard root.path.hasPrefix(fileManager.homeDirectoryForCurrentUser.path + "/Library/"),
                  let children = try? fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                  ) else { continue }

            for child in children where !(category == .applicationCaches && child.lastPathComponent == protectedCacheName) {
                let size = allocatedSize(of: child)
                do {
                    var trashedURL: NSURL?
                    try fileManager.trashItem(at: child, resultingItemURL: &trashedURL)
                    reclaimedBytes += size
                    movedItemCount += 1
                } catch {
                    failures.append("\(child.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        return CacheCleanupResult(
            reclaimedBytes: reclaimedBytes,
            movedItemCount: movedItemCount,
            failures: failures
        )
    }

    private nonisolated static func allocatedSize(of root: URL) -> UInt64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            let values = try? root.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            return UInt64(max(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0, 0))
        }

        var bytes: UInt64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey
            ]), values.isSymbolicLink != true, values.isRegularFile == true else { continue }
            bytes += UInt64(max(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0, 0))
        }
        return bytes
    }
}
