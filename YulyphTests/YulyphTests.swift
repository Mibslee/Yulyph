import XCTest
import UIKit
@testable import Yulyph

// MARK: - FECService Tests

class FECTests: XCTestCase {

    func testEncodeDecodeRoundtrip() throws {
        let original = "Hello, Yulyph! This is a test message for FEC encoding.".data(using: .utf8)!
        let encoded = FECService.shared.encode(original)
        XCTAssertGreaterThan(encoded.count, original.count, "FEC 编码应该增加数据长度")

        let decoded = FECService.shared.decode(encoded)
        XCTAssertEqual(decoded, original, "FEC 编解码往返应该恢复原始数据")
    }

    func testSingleByteErrorCorrection() throws {
        let original = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$".data(using: .utf8)!
        let encoded = FECService.shared.encode(original)

        // 模拟单字节错误：翻转一个 bit
        var corrupted = Data(encoded)
        if corrupted.count > 0 {
            corrupted[0] ^= 0x01
        }

        let decoded = FECService.shared.decode(corrupted)
        XCTAssertEqual(decoded, original, "FEC 应该修正单字节错误")
    }
}

// MARK: - CryptoService Tests

class CryptoTests: XCTestCase {

    func testEncryptDecryptRoundtrip() throws {
        let password = "test_password_123"
        let plaintext = "This is a secret message for testing."

        let encrypted = try CryptoService.shared.encrypt(plaintext, with: password)
        XCTAssertFalse(encrypted.isEmpty)
        XCTAssertGreaterThan(encrypted.count, 16 + 12)

        let decrypted = try CryptoService.shared.decrypt(encrypted, with: password)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testDifferentPasswordFails() throws {
        let password1 = "password_1"
        let password2 = "password_2"
        let plaintext = "Secret data."

        let encrypted = try CryptoService.shared.encrypt(plaintext, with: password1)
        XCTAssertThrowsError(try CryptoService.shared.decrypt(encrypted, with: password2))
    }
}

// MARK: - StegoService Tests

class StegoServiceTests: XCTestCase {

    private func createTestImage(width: Int = 256, height: Int = 256, color: UIColor = .red) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// 创建带纹理的测试图片（自然图像，AC 系数丰富）
    private func createTexturedImage(width: Int = 256, height: Int = 256) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            for y in 0..<height {
                for x in 0..<width {
                    let r = CGFloat((x * 17 + y * 31) % 256) / 255.0
                    let g = CGFloat((x * 37 + y * 53) % 256) / 255.0
                    let b = CGFloat((x * 71 + y * 97) % 256) / 255.0
                    UIColor(red: r, green: g, blue: b, alpha: 1.0).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }

    // MARK: - DCT Mode Roundtrip

    func testDctEmbedExtractRoundtrip() throws {
        let image = createTexturedImage()
        let message = "Hello, DCT-QIM testing!".data(using: .utf8)!

        let embedded = try StegoService.shared.embed(data: message, into: image, mode: .dct, strength: .standard)
        XCTAssertEqual(embedded.cgImage?.width, image.cgImage?.width)

        let extracted = try StegoService.shared.extract(from: embedded)
        XCTAssertEqual(extracted, message)
    }

    func testDctDifferentStrengths() throws {
        let image = createTexturedImage()
        let message = "Strength test!".data(using: .utf8)!

        for strength in StegoService.StrengthLevel.allCases {
            let embedded = try StegoService.shared.embed(data: message, into: image, mode: .dct, strength: strength)
            let extracted = try StegoService.shared.extract(from: embedded)
            XCTAssertEqual(extracted, message, "Strength \(strength) 应正确嵌入/提取")
        }
    }

    // MARK: - LSB Mode Roundtrip

    func testLsbEmbedExtractRoundtrip() throws {
        let image = createTestImage(width: 128, height: 128)
        let message = "LSB mode test".data(using: .utf8)!

        let embedded = try StegoService.shared.embed(data: message, into: image, mode: .lsb)
        let extracted = try StegoService.shared.extract(from: embedded)
        XCTAssertEqual(extracted, message)
    }

    // MARK: - Copyright Embed/Extract

    func testCopyrightEmbedExtractPublic() throws {
        let image = createTexturedImage()
        let info = CopyrightInfo(creator: "测试作者", year: 2026, license: "CC-BY", isPublic: true, imageName: nil, detectedAt: Date())

        let embedded = try StegoService.shared.embedCopyright(info: info, into: image, password: nil, strength: .standard)
        XCTAssertEqual(embedded.cgImage?.width, image.cgImage?.width)

        let extracted = try StegoService.shared.extractCopyright(from: embedded, password: nil)
        XCTAssertEqual(extracted.creator, info.creator)
        XCTAssertEqual(extracted.year, info.year)
        XCTAssertEqual(extracted.license, info.license)
    }

    func testCopyrightEmbedExtractPrivate() throws {
        let image = createTexturedImage()
        let info = CopyrightInfo(creator: "Private Author", year: 2026, license: "ARR", isPublic: false, imageName: nil, detectedAt: Date())
        let password = "my_secret_copyright_key"

        let embedded = try StegoService.shared.embedCopyright(info: info, into: image, password: password, strength: .standard)

        let extracted = try StegoService.shared.extractCopyright(from: embedded, password: password)
        XCTAssertEqual(extracted.creator, info.creator)
        XCTAssertEqual(extracted.license, info.license)

        XCTAssertThrowsError(try StegoService.shared.extractCopyright(from: embedded, password: "wrong_password"))
    }

    func testCopyrightEmbedExtractDifferentStrengths() throws {
        let image = createTexturedImage()
        let info = CopyrightInfo(creator: "Strength Test", year: 2026, license: "CC-BY-SA", isPublic: true, imageName: nil, detectedAt: Date())

        for strength in StegoService.StrengthLevel.allCases {
            let embedded = try StegoService.shared.embedCopyright(info: info, into: image, password: nil, strength: strength)
            let extracted = try StegoService.shared.extractCopyright(from: embedded, password: nil)
            XCTAssertEqual(extracted.creator, info.creator)
        }
    }

    // MARK: - Mode Detection

    func testDetectDCTMode() throws {
        let image = createTexturedImage()
        let message = "Mode detection".data(using: .utf8)!
        let embedded = try StegoService.shared.embed(data: message, into: image, mode: .dct)

        let detectedMode = StegoService.shared.detectMode(from: embedded)
        XCTAssertEqual(detectedMode, .dct, "DCT 模式应被正确检测到")
    }

    func testDetectLSBMode() throws {
        let image = createTestImage()
        let message = "LSB detection".data(using: .utf8)!
        let embedded = try StegoService.shared.embed(data: message, into: image, mode: .lsb)

        let detectedMode = StegoService.shared.detectMode(from: embedded)
        XCTAssertEqual(detectedMode, .lsb)
    }

    func testDetectCopyrightMode() throws {
        let image = createTexturedImage()
        let info = CopyrightInfo(creator: "Detect Test", year: 2026, license: "CC-BY", isPublic: true, imageName: nil, detectedAt: Date())
        let embedded = try StegoService.shared.embedCopyright(info: info, into: image)

        let detectedMode = StegoService.shared.detectMode(from: embedded)
        XCTAssertEqual(detectedMode, .copyright)
    }

    // MARK: - Edge Cases

    func testImageTooSmallFails() throws {
        let image = createTestImage(width: 32, height: 32)
        let message = "Data".data(using: .utf8)!

        XCTAssertThrowsError(try StegoService.shared.embed(data: message, into: image, mode: .dct)) { error in
            XCTAssertTrue(error is StegoError)
        }
    }

    func testCapacityExceededFails() throws {
        let image = createTestImage(width: 16, height: 16)
        let tinyMessage = "tiny".data(using: .utf8)!

        XCTAssertThrowsError(try StegoService.shared.embed(data: tinyMessage, into: image, mode: .dct)) { error in
            XCTAssertTrue(error is StegoError)
        }
    }

    // MARK: - FEC + Stego Combined

    func testDctWithFECRoundtrip() throws {
        let image = createTexturedImage()
        let message = "FEC+DCT combined test message!".data(using: .utf8)!
        let encoded = FECService.shared.encode(message)

        let embedded = try StegoService.shared.embed(data: encoded, into: image, mode: .dct, strength: .enhanced)
        let extracted = try StegoService.shared.extract(from: embedded)
        let decoded = FECService.shared.decode(extracted)

        XCTAssertEqual(decoded, message)
    }
}
