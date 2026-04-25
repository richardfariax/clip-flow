import Foundation

#if canImport(Sparkle)
import Sparkle

@MainActor
final class UpdateManager: NSObject {
    private(set) var updaterController: SPUStandardUpdaterController?

    override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}

#else

@MainActor
final class UpdateManager {
    func checkForUpdates() {
        NSLog("[ClipVault] Sparkle não configurado. Adicione o pacote Sparkle no Xcode.")
    }
}

#endif
