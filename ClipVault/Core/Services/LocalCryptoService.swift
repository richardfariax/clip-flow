import CryptoKit
import Foundation

final class LocalCryptoService {
    private let serviceName = "com.clipvault.local-crypto"
    private let accountName = "primary-key"

    private lazy var key: SymmetricKey = {
        if let existing = KeychainHelper.loadData(service: serviceName, account: accountName) {
            return SymmetricKey(data: existing)
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        let _ = KeychainHelper.saveData(keyData, service: serviceName, account: accountName)
        return newKey
    }()

    func encrypt(_ data: Data) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw NSError(domain: "ClipVault.Crypto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Falha ao gerar payload criptografado"]) 
        }
        return combined
    }

    func decrypt(_ data: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }
}
