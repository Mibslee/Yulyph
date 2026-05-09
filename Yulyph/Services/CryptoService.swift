import Foundation
import CryptoKit
import CommonCrypto
import os.log

private let logger = Logger(subsystem: "com.shanestudio.yulyph", category: "CryptoService")

enum CryptoError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case invalidData

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "加密失败"
        case .decryptionFailed: return "解密失败，请检查密钥是否正确"
        case .invalidKey: return "密钥格式无效"
        case .invalidData: return "数据格式无效"
        }
    }
}

class CryptoService {
    static let shared = CryptoService()

    private let saltLength = 16
    private let pbkdf2Iterations = 100_000

    private init() {}

    func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidKey
        }

        var derivedKey = [UInt8](repeating: 0, count: 32)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password,
            passwordData.count,
            [UInt8](salt),
            salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(pbkdf2Iterations),
            &derivedKey,
            derivedKey.count
        )

        guard status == kCCSuccess else {
            logger.error("PBKDF2 密钥派生失败: \(status)")
            throw CryptoError.invalidKey
        }

        return SymmetricKey(data: derivedKey)
    }

    func encrypt(_ plaintext: String, with password: String) throws -> Data {
        guard let data = plaintext.data(using: .utf8) else {
            throw CryptoError.invalidData
        }

        // 生成随机 salt
        var saltBytes = [UInt8](repeating: 0, count: saltLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, saltLength, &saltBytes)
        let salt = Data(saltBytes)

        let key = try deriveKey(from: password, salt: salt)

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            // 输出格式: salt(16) + nonce(12) + ciphertext + tag(16)
            var output = salt
            output.append(combined)
            return output
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    func decrypt(_ encryptedData: Data, with password: String) throws -> String {
        guard encryptedData.count > saltLength + 12 + 16 else {
            throw CryptoError.invalidData
        }

        // 提取 salt
        let salt = encryptedData.prefix(saltLength)
        let ciphertext = encryptedData.dropFirst(saltLength)

        let key = try deriveKey(from: password, salt: Data(salt))

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            guard let result = String(data: decryptedData, encoding: .utf8) else {
                throw CryptoError.decryptionFailed
            }
            return result
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    func generateRandomKey() -> String {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        return keyData.base64EncodedString()
    }
}
