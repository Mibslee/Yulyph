import Foundation
import CryptoKit
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
    
    private let salt = "Yulyph2026Salt".data(using: .utf8)!
    
    private init() {}
    
    func deriveKey(from password: String) throws -> SymmetricKey {
        logger.info("开始派生密钥")
        
        guard let passwordData = password.data(using: .utf8) else {
            logger.error("密码数据无效")
            throw CryptoError.invalidKey
        }
        
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: "Yulyph-AES-GCM".data(using: .utf8)!,
            outputByteCount: 32
        )
        
        logger.info("密钥派生完成")
        return derivedKey
    }
    
    func encrypt(_ plaintext: String, with password: String) throws -> Data {
        logger.info("开始加密，文本长度: \(plaintext.count)")
        
        guard let data = plaintext.data(using: .utf8) else {
            logger.error("文本数据无效")
            throw CryptoError.invalidData
        }
        
        let key = try deriveKey(from: password)
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                logger.error("加密失败：无法组合数据")
                throw CryptoError.encryptionFailed
            }
            logger.info("加密成功，密文大小: \(combined.count) bytes")
            return combined
        } catch {
            logger.error("加密异常: \(error.localizedDescription)")
            throw CryptoError.encryptionFailed
        }
    }
    
    func decrypt(_ encryptedData: Data, with password: String) throws -> String {
        logger.info("开始解密，密文大小: \(encryptedData.count) bytes")
        
        let key = try deriveKey(from: password)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            guard let result = String(data: decryptedData, encoding: .utf8) else {
                logger.error("解密失败：无法转换为字符串")
                throw CryptoError.decryptionFailed
            }
            logger.info("解密成功，明文长度: \(result.count)")
            return result
        } catch {
            logger.error("解密异常: \(error.localizedDescription)")
            throw CryptoError.decryptionFailed
        }
    }
    
    func generateRandomKey() -> String {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        return keyData.base64EncodedString()
    }
}