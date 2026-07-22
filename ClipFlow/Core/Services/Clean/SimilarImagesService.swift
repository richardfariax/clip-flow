import Foundation
import CoreGraphics
import ImageIO

/// Grupo de imagens visualmente parecidas (dHash com distância de Hamming baixa).
struct SimilarImageGroup: Identifiable {
    let id = UUID()
    let items: [CleanFileItem]

    /// Espaço recuperável mantendo a maior/mais recente.
    var wastedBytes: UInt64 {
        items.dropFirst().reduce(0) { $0 + $1.bytes }
    }
}

/// Detecção de imagens similares (não idênticas) via perceptual hash.
/// Varre imagens soltas em Mesa, Downloads e Imagens — não toca na
/// biblioteca do Photos.
@MainActor
final class SimilarImagesService: ObservableObject {
    @Published private(set) var groups: [SimilarImageGroup] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedCount = 0

    var totalWastedBytes: UInt64 {
        groups.reduce(0) { $0 + $1.wastedBytes }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        groups = []
        scannedCount = 0

        Task {
            let outcome = await Task.detached(priority: .utility) { () -> (groups: [SimilarImageGroup], count: Int) in
                Self.findSimilarImages()
            }.value
            groups = outcome.groups
            scannedCount = outcome.count
            isScanning = false
        }
    }

    func trash(urls: Set<URL>) {
        guard !urls.isEmpty else { return }
        _ = FileSweeper.trash(urls: Array(urls))
        groups = groups.compactMap { group in
            let remaining = group.items.filter { !urls.contains($0.url) }
            guard remaining.count > 1 else { return nil }
            return SimilarImageGroup(items: remaining)
        }
    }

    // MARK: - Busca

    private nonisolated static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp", "webp"
    ]
    /// Distância de Hamming máxima (de 64 bits) para considerar "similar".
    private nonisolated static let maxHammingDistance = 8
    private nonisolated static let maxScannedImages = 3000

    nonisolated static func findSimilarImages() -> (groups: [SimilarImageGroup], count: Int) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = ["Desktop", "Downloads", "Pictures"].map {
            home.appendingPathComponent($0, isDirectory: true)
        }

        // Coleta imagens (fora de pacotes como .photoslibrary).
        var images: [(item: CleanFileItem, hash: UInt64)] = []
        var count = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            for case let url as URL in enumerator {
                guard imageExtensions.contains(url.pathExtension.lowercased()),
                      let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true,
                      let size = values.fileSize.map(UInt64.init),
                      size > 50_000 else { continue }
                count += 1
                guard count <= maxScannedImages else { break }
                guard let hash = dHash(of: url) else { continue }
                images.append((
                    CleanFileItem(url: url, bytes: size, modifiedAt: values.contentModificationDate),
                    hash
                ))
            }
        }

        // Agrupamento guloso por distância de Hamming.
        var used = Set<Int>()
        var groups: [SimilarImageGroup] = []
        for i in images.indices where !used.contains(i) {
            var members = [images[i].item]
            for j in images.indices where j > i && !used.contains(j) {
                if (images[i].hash ^ images[j].hash).nonzeroBitCount <= maxHammingDistance {
                    members.append(images[j].item)
                    used.insert(j)
                }
            }
            if members.count > 1 {
                used.insert(i)
                // Maior primeiro: sugerimos manter a de melhor qualidade.
                groups.append(SimilarImageGroup(items: members.sorted { $0.bytes > $1.bytes }))
            }
        }
        return (groups.sorted { $0.wastedBytes > $1.wastedBytes }, min(count, maxScannedImages))
    }

    /// dHash 8x8: reduz para 9x8 em tons de cinza e compara pixels vizinhos.
    nonisolated static func dHash(of url: URL) -> UInt64? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 32,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let width = 9, height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .low
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        var bit = 0
        for row in 0..<height {
            for col in 0..<(width - 1) {
                if pixels[row * width + col] > pixels[row * width + col + 1] {
                    hash |= 1 << UInt64(bit)
                }
                bit += 1
            }
        }
        return hash
    }
}
