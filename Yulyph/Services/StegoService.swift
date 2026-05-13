import UIKit
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.shanestudio.yulyph", category: "StegoService")

// MARK: - Errors

enum StegoError: Error, LocalizedError {
    case imageLoadFailed
    case imageTooSmall
    case imageTooLarge
    case capacityExceeded
    case embedFailed
    case extractFailed
    case noHiddenData
    case corruptedData

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed: return "图片加载失败"
        case .imageTooSmall: return "图片尺寸太小，无法嵌入数据"
        case .imageTooLarge: return "图片文件过大"
        case .capacityExceeded: return "图片容量不足，无法嵌入更多信息"
        case .embedFailed: return "嵌入数据失败"
        case .extractFailed: return "提取数据失败"
        case .noHiddenData: return "未检测到隐藏数据"
        case .corruptedData: return "数据已损坏"
        }
    }
}

// MARK: - Stego Mode

enum StegoMode: UInt8 {
    case lsb = 0x00  // 高容量，空间域 LSB
    case dct = 0x01  // 抗压缩，频域 DCT-QIM
    case copyright = 0x02  // 版权水印
}

// MARK: - StegoService

class StegoService {
    static let shared = StegoService()

    private let minLength = 100
    private let maxLength = 12000
    private let maxDataSize = 1024 * 1024 // 1MB

    // DCT-QIM 参数
    private let blockSize = 8

    // 嵌入强度预设
    enum StrengthLevel: UInt8, CaseIterable {
        case fine = 0      // delta=16, 失真最小
        case standard = 1  // delta=24, 默认平衡
        case enhanced = 2  // delta=32, 更抗压缩
        case maxRobust = 3 // delta=48, 最抗压缩

        var delta: Float {
            switch self {
            case .fine:      return 16.0
            case .standard:  return 24.0
            case .enhanced:  return 32.0
            case .maxRobust: return 48.0
            }
        }

        var label: String {
            switch self {
            case .fine:      return "精细"
            case .standard:  return "标准"
            case .enhanced:  return "增强"
            case .maxRobust: return "最强"
            }
        }
    }

    private let defaultStrength: StrengthLevel = .standard

    // 中频系数对 (row, col) — 避开 DC 和高频，每对的两个系数独立不重复。
    // 必须确保任意两对 (r1,c1) 与 (r2,c2) 不共享相同系数：
    //   {r1*8+c1, c1*8+r1} ∩ {r2*8+c2, c2*8+r2} = ∅
    private let coeffPairs: [(Int, Int)] = [
        (2, 3), (4, 1), (3, 4), (5, 2),
        (1, 5), (2, 6), (3, 7), (0, 3)
    ]

    // 预计算 DCT 余弦表
    private lazy var cosTable: [[Float]] = {
        var table = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 8)
        for k in 0..<8 {
            for n in 0..<8 {
                table[k][n] = cosf(Float.pi * Float(k) * (2.0 * Float(n) + 1.0) / 16.0)
            }
        }
        return table
    }()

    private init() {}

    // MARK: - Public API

    /// 嵌入数据到图片中
    /// - Parameters:
    ///   - data: 要嵌入的加密数据
    ///   - image: 载体图片
    ///   - mode: .lsb 高容量 / .dct 抗压缩
    ///   - strength: DCT 嵌入强度，默认 .standard
    func embed(data: Data, into image: UIImage, mode: StegoMode = .dct, strength: StrengthLevel? = nil) throws -> UIImage {
        logger.info("开始嵌入数据，大小: \(data.count) bytes，模式: \(mode == .dct ? "DCT" : "LSB")")

        let image = Self.normalizeOrientation(image)
        guard let cgImage = image.cgImage else {
            throw StegoError.imageLoadFailed
        }

        let width = cgImage.width
        let height = cgImage.height
        logger.info("图片尺寸: \(width) x \(height)")

        guard width >= minLength && height >= minLength else { throw StegoError.imageTooSmall }
        guard width <= maxLength && height <= maxLength else { throw StegoError.imageTooLarge }

        switch mode {
        case .lsb:
            return try embedLSB(data: data, cgImage: cgImage, width: width, height: height)
        case .dct:
            let level = strength ?? defaultStrength
            return try embedDCT(data: data, cgImage: cgImage, width: width, height: height, strength: level)
        case .copyright:
            let level = strength ?? defaultStrength
            return try embedDCT(data: data, cgImage: cgImage, width: width, height: height, strength: level, mode: .copyright)
        }
    }

    /// 计算图片在指定模式下的可用容量（字节）
    func capacity(for image: UIImage, mode: StegoMode) -> Int {
        let image = Self.normalizeOrientation(image)
        guard let cgImage = image.cgImage else { return 0 }
        let width = cgImage.width
        let height = cgImage.height

        switch mode {
        case .lsb:
            return (width * height * 3) / 8
        case .dct:
            let alignedW = (width / blockSize) * blockSize
            let alignedH = (height / blockSize) * blockSize
            let totalBlocks = (alignedW / blockSize) * (alignedH / blockSize)
            return (totalBlocks * coeffPairs.count) / 8
        case .copyright:
            let alignedW = (width / blockSize) * blockSize
            let alignedH = (height / blockSize) * blockSize
            let totalBlocks = (alignedW / blockSize) * (alignedH / blockSize)
            return (totalBlocks * coeffPairs.count) / 8
        }
    }

    /// 检测图片中隐藏数据的编码模式
    func detectMode(from image: UIImage) -> StegoMode? {
        let image = Self.normalizeOrientation(image)
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let alignedW = (width / blockSize) * blockSize
        let alignedH = (height / blockSize) * blockSize

        // DCT 模式检测 — 从第一个 8x8 块的 DCT 系数中读取模式字节。
        // 注意：不跨块投票，因为第 0 块包含 mode byte，后续块包含 strength/length bytes。
        if alignedW >= 64 && alignedH >= 64,
           let pixelData = getPixelData(from: cgImage) {
            let channelR = extractChannel(pixelData, channel: 0, width: width, height: height, alignedW: alignedW, alignedH: alignedH)

            // 尝试多个 delta 值：header 固定用 24，但压缩后可能偏移
            let deltasToTry: [Float] = [24.0, 16.0, 32.0, 48.0]

            // 只检查第一个 8x8 块
            var block = [Float](repeating: 0, count: 64)
            for r in 0..<blockSize {
                for c in 0..<blockSize {
                    let idx = r * alignedW + c
                    block[r * blockSize + c] = Float(channelR[idx]) - 128.0
                }
            }
            let coeffs = dct2d(block)

            for delta in deltasToTry {
                var modeByte: UInt8 = 0
                for i in 0..<8 {
                    let (r1, c1) = coeffPairs[i]
                    let r2 = c1, c2 = r1
                    let bit = extractQIM(c1: coeffs[r1 * blockSize + c1], c2: coeffs[r2 * blockSize + c2], delta: delta)
                    modeByte = (modeByte << 1) | bit
                }
                if modeByte == StegoMode.copyright.rawValue {
                    return .copyright
                }
                if modeByte == StegoMode.dct.rawValue {
                    return .dct
                }
            }
        }

        // 空域 LSB 检测
        if let pixelData = getPixelData(from: cgImage) {
            var firstByte: UInt8 = 0
            var bitCount = 0
            for i in stride(from: 0, to: pixelData.count, by: 4) {
                guard bitCount < 8 else { break }
                for channel in 0..<3 {
                    guard bitCount < 8 else { break }
                    firstByte = (firstByte << 1) | (pixelData[i + channel] & 1)
                    bitCount += 1
                }
            }
            if firstByte == StegoMode.lsb.rawValue {
                return .lsb
            }
            if firstByte == StegoMode.dct.rawValue {
                return .dct
            }
        }
        return nil
    }

    /// 嵌入版权水印到图片中
    /// - Parameters:
    ///   - info: 版权信息
    ///   - image: 载体图片
    ///   - password: 可选密钥，留空则不加密（公开版权）
    ///   - strength: 嵌入强度，默认 .standard
    func embedCopyright(info: CopyrightInfo, into image: UIImage, password: String? = nil, strength: StegoService.StrengthLevel? = nil) throws -> UIImage {
        var data = Data(info.toJSON().utf8)

        // 如果提供了密钥，加密元数据
        if let pwd = password, !pwd.isEmpty {
            data = try CryptoService.shared.encrypt(info.toJSON(), with: pwd)
        }

        // embed 会在 embedDCT 中为 data 统一创建 header，此处不预加 header
        return try embed(data: data, into: image, mode: .copyright, strength: strength)
    }

    /// 从图片中提取版权信息
    func extractCopyright(from image: UIImage, password: String? = nil) throws -> CopyrightInfo {
        let normalizedImage = Self.normalizeOrientation(image)
        guard let cgImage = normalizedImage.cgImage else {
            throw StegoError.imageLoadFailed
        }
        let rawData = try extractCopyrightRaw(cgImage: cgImage, width: cgImage.width, height: cgImage.height)

        var jsonString: String
        let isPublic = password == nil || password?.isEmpty == true

        // 尝试直接解析（公开版权）
        if let s = String(data: rawData, encoding: .utf8) {
            jsonString = s
        } else if let pwd = password, !pwd.isEmpty {
            // 尝试解密（私有版权）
            jsonString = try CryptoService.shared.decrypt(rawData, with: pwd)
        } else {
            throw StegoError.corruptedData
        }

        guard let parsed = CopyrightInfo.parse(from: jsonString) else {
            throw StegoError.corruptedData
        }
        return CopyrightInfo(creator: parsed.creator, year: parsed.year, license: parsed.license, isPublic: isPublic, imageName: parsed.imageName, detectedAt: parsed.detectedAt)
    }

    /// 从图片中提取数据
    func extract(from image: UIImage) throws -> Data {
        logger.info("开始提取数据")

        let image = Self.normalizeOrientation(image)
        guard let cgImage = image.cgImage else {
            throw StegoError.imageLoadFailed
        }

        let width = cgImage.width
        let height = cgImage.height
        let alignedW = (width / blockSize) * blockSize
        let alignedH = (height / blockSize) * blockSize

        // 优先尝试 DCT 模式检测：从第一个 8x8 块的 DCT 系数中读取版本字节
        if alignedW >= 64 && alignedH >= 64,
           let pixelData = getPixelData(from: cgImage) {
            let channelR = extractChannel(pixelData, channel: 0, width: width, height: height, alignedW: alignedW, alignedH: alignedH)

            var block = [Float](repeating: 0, count: 64)
            for r in 0..<blockSize {
                for c in 0..<blockSize {
                    block[r * blockSize + c] = Float(channelR[r * alignedW + c]) - 128.0
                }
            }

            let coeffs = dct2d(block)
            var modeByteBits = [UInt8]()
            for i in 0..<8 {
                let (r1, c1) = coeffPairs[i]
                let r2 = c1, c2 = r1
                modeByteBits.append(extractQIM(c1: coeffs[r1 * blockSize + c1], c2: coeffs[r2 * blockSize + c2], delta: 24.0))
            }

            if modeByteBits.count == 8 {
                var modeByte: UInt8 = 0
                for j in 0..<8 {
                    modeByte = (modeByte << 1) | modeByteBits[j]
                }
                if modeByte == StegoMode.dct.rawValue {
                    logger.info("检测到 DCT 编码模式")
                    return try extractDCT(cgImage: cgImage, width: width, height: height)
                } else if modeByte == StegoMode.copyright.rawValue {
                    logger.info("检测到版权水印")
                    return try extractCopyrightRaw(cgImage: cgImage, width: width, height: height)
                }
            }
        }

        // 回退到空域 LSB 模式检测
        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        var firstByteBits: [UInt8] = []
        var bitCount = 0
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            guard bitCount < 8 else { break }
            for channel in 0..<3 {
                guard bitCount < 8 else { break }
                firstByteBits.append(pixelData[i + channel] & 1)
                bitCount += 1
            }
        }

        var firstByte: UInt8 = 0
        for j in 0..<8 {
            firstByte = (firstByte << 1) | firstByteBits[j]
        }

        if firstByte == StegoMode.lsb.rawValue {
            logger.info("检测到 LSB 编码模式")
            return try extractLSB(cgImage: cgImage, width: width, height: height, headerOffset: 9)
        }

        // 向后兼容：旧版 LSB 无版本字节，直接用魔数判断
        logger.info("未检测到版本字节，使用旧版 LSB 兼容模式")
        return try extractLSBLegacy(cgImage: cgImage, width: width, height: height)
    }

    // MARK: - LSB Mode (高容量)

    private func embedLSB(data: Data, cgImage: CGImage, width: Int, height: Int) throws -> UIImage {
        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        let maxCapacity = (width * height * 3) / 8
        guard data.count <= maxCapacity else {
            throw StegoError.capacityExceeded
        }

        let header = createHeader(data, mode: .lsb)
        let payload = header + data
        var modifiedPixels = pixelData

        let bits = payload.flatMap { byte in
            (0..<8).map { bit in (byte >> (7 - bit)) & 1 }
        }

        var bitIndex = 0
        let pixelCount = modifiedPixels.count
        for i in stride(from: 0, to: pixelCount, by: 4) {
            guard bitIndex < bits.count else { break }
            for channel in 0..<3 {
                guard bitIndex < bits.count else { break }
                modifiedPixels[i + channel] = (modifiedPixels[i + channel] & 0xFE) | bits[bitIndex]
                bitIndex += 1
            }
        }

        logger.info("LSB 嵌入完成: \(bitIndex) bits")
        guard let resultImage = createImage(from: modifiedPixels, width: width, height: height) else {
            throw StegoError.embedFailed
        }
        return resultImage
    }

    private func extractLSB(cgImage: CGImage, width: Int, height: Int, headerOffset: Int) throws -> Data {
        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        // 跳过 headerOffset 字节（已由调用方读取版本字节）
        // header 结构: version(1) + length(4) + magic(4) = 9 bytes
        let headerByteCount = 9
        let totalHeaderBits = headerByteCount * 8

        // 提取全部 header bits
        var allHeaderBits: [UInt8] = []
        var bc = 0
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            guard bc < totalHeaderBits else { break }
            for channel in 0..<3 {
                guard bc < totalHeaderBits else { break }
                allHeaderBits.append(pixelData[i + channel] & 1)
                bc += 1
            }
        }

        // 解析 header 字节
        let headerBytes = bitsToBytes(allHeaderBits)
        guard headerBytes.count >= headerByteCount else { throw StegoError.noHiddenData }

        // 校验魔数 (bytes 5..8)
        let magic = Data(headerBytes[5..<9])
        guard magic == Data([0x59, 0x55, 0x4C, 0x50]) else { throw StegoError.noHiddenData }

        // 数据长度 (bytes 1..4)
        let dataLength = Data(headerBytes[1..<5]).withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
        guard dataLength <= maxDataSize else { throw StegoError.corruptedData }

        // 提取完整 header + payload
        let totalBits = (headerByteCount + Int(dataLength)) * 8
        var allBits: [UInt8] = []
        bc = 0
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            guard bc < totalBits else { break }
            for channel in 0..<3 {
                guard bc < totalBits else { break }
                allBits.append(pixelData[i + channel] & 1)
                bc += 1
            }
        }

        let allBytes = bitsToBytes(allBits)
        let startIndex = headerByteCount
        let endIndex = startIndex + Int(dataLength)
        guard allBytes.count >= endIndex else { throw StegoError.corruptedData }

        let extracted = Data(allBytes[startIndex..<endIndex])
        logger.info("LSB 提取成功: \(extracted.count) bytes")
        return extracted
    }

    /// 旧版兼容提取（无版本字节，header 为 length(4) + magic(4) = 8 bytes）
    private func extractLSBLegacy(cgImage: CGImage, width: Int, height: Int) throws -> Data {
        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        let headerByteCount = 8
        let headerBitCount = headerByteCount * 8

        var headerBits: [UInt8] = []
        var bc = 0
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            guard bc < headerBitCount else { break }
            for channel in 0..<3 {
                guard bc < headerBitCount else { break }
                headerBits.append(pixelData[i + channel] & 1)
                bc += 1
            }
        }

        let headerBytes = bitsToBytes(headerBits)
        guard headerBytes.count >= headerByteCount else { throw StegoError.noHiddenData }

        let magic = Data(headerBytes[4..<8])
        guard magic == Data([0x59, 0x55, 0x4C, 0x50]) else { throw StegoError.noHiddenData }

        let dataLength = Data(headerBytes[0..<4]).withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
        guard dataLength <= maxDataSize else { throw StegoError.corruptedData }

        let totalBits = (headerByteCount + Int(dataLength)) * 8
        var allBits: [UInt8] = []
        bc = 0
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            guard bc < totalBits else { break }
            for channel in 0..<3 {
                guard bc < totalBits else { break }
                allBits.append(pixelData[i + channel] & 1)
                bc += 1
            }
        }

        let allBytes = bitsToBytes(allBits)
        let endIndex = headerByteCount + Int(dataLength)
        guard allBytes.count >= endIndex else { throw StegoError.corruptedData }

        let extracted = Data(allBytes[headerByteCount..<endIndex])
        logger.info("旧版 LSB 提取成功: \(extracted.count) bytes")
        return extracted
    }

    // MARK: - DCT-QIM Mode (抗压缩)

    private func embedDCT(data: Data, cgImage: CGImage, width: Int, height: Int, strength: StrengthLevel, mode: StegoMode = .dct) throws -> UIImage {
        let qimDelta = strength.delta
        // 裁剪到 8 的倍数
        let alignedW = (width / blockSize) * blockSize
        let alignedH = (height / blockSize) * blockSize

        guard alignedW >= 64 && alignedH >= 64 else {
            throw StegoError.imageTooSmall
        }

        let header = createHeader(data, mode: mode, strength: strength)
        let payload = header + data

        let bits = payload.flatMap { byte in
            (0..<8).map { bit in (byte >> (7 - bit)) & 1 }
        }

        // 计算容量：每 8x8 块可用 coeffPairs.count 个比特
        let blocksX = alignedW / blockSize
        let blocksY = alignedH / blockSize
        let totalBlocks = blocksX * blocksY
        let bitsPerBlock = coeffPairs.count
        let maxBits = totalBlocks * bitsPerBlock

        guard bits.count <= maxBits else {
            logger.error("DCT 容量不足: 需要 \(bits.count) bits, 最大 \(maxBits)")
            throw StegoError.capacityExceeded
        }

        logger.info("DCT 嵌入: \(blocksX)x\(blocksY) blocks, 容量 \(maxBits/8) bytes, 强度 \(qimDelta)")

        // 提取 R 通道灰度矩阵
        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        var channelR = extractChannel(pixelData, channel: 0, width: width, height: height, alignedW: alignedW, alignedH: alignedH)

        // 两阶段嵌入：第一阶段 header 用固定 delta，第二阶段数据用指定 delta
        let headerBits = Array(bits.prefix(header.count * 8))
        let dataBits = Array(bits.dropFirst(header.count * 8))
        let headerBlockCount = (headerBits.count + bitsPerBlock - 1) / bitsPerBlock  // header 占用的块数

        // 阶段一：嵌入 header
        var bitIndex = 0
        var blockIndex = 0

        for blockY in stride(from: 0, to: alignedH, by: blockSize) {
            for blockX in stride(from: 0, to: alignedW, by: blockSize) {
                guard bitIndex < headerBits.count else { break }

                var block = [Float](repeating: 0, count: 64)
                for r in 0..<blockSize {
                    for c in 0..<blockSize {
                        let idx = (blockY + r) * alignedW + (blockX + c)
                        block[r * blockSize + c] = Float(channelR[idx]) - 128.0
                    }
                }

                let coeffs = dct2d(block)
                var modified = coeffs
                for pairIdx in 0..<coeffPairs.count {
                    guard bitIndex < headerBits.count else { break }
                    let (r1, c1) = coeffPairs[pairIdx]
                    let idx1 = r1 * blockSize + c1
                    let r2 = c1, c2 = r1
                    let idx2 = r2 * blockSize + c2

                    var v1 = modified[idx1]
                    var v2 = modified[idx2]
                    embedQIM(c1: &v1, c2: &v2, bit: headerBits[bitIndex], delta: 24.0)
                    modified[idx1] = v1
                    modified[idx2] = v2
                    bitIndex += 1
                }

                let reconstructed = idct2d(modified)
                for r in 0..<blockSize {
                    for c in 0..<blockSize {
                        let idx = (blockY + r) * alignedW + (blockX + c)
                        let val = reconstructed[r * blockSize + c] + 128.0
                        channelR[idx] = UInt8(max(0, min(255, round(val))))
                    }
                }
                blockIndex += 1
            }
        }

        // 阶段二：嵌入数据（跳过 header 已占用的块，防止覆盖）
        bitIndex = 0
        blockIndex = 0

        for blockY in stride(from: 0, to: alignedH, by: blockSize) {
            for blockX in stride(from: 0, to: alignedW, by: blockSize) {
                defer { blockIndex += 1 }
                guard bitIndex < dataBits.count else { break }
                // 跳过 header 已占用的块
                guard blockIndex >= headerBlockCount else { continue }

                var block = [Float](repeating: 0, count: 64)
                for r in 0..<blockSize {
                    for c in 0..<blockSize {
                        let idx = (blockY + r) * alignedW + (blockX + c)
                        block[r * blockSize + c] = Float(channelR[idx]) - 128.0
                    }
                }

                let coeffs = dct2d(block)
                var modified = coeffs
                for pairIdx in 0..<coeffPairs.count {
                    guard bitIndex < dataBits.count else { break }
                    let (r1, c1) = coeffPairs[pairIdx]
                    let idx1 = r1 * blockSize + c1
                    let r2 = c1, c2 = r1
                    let idx2 = r2 * blockSize + c2

                    var v1 = modified[idx1]
                    var v2 = modified[idx2]
                    embedQIM(c1: &v1, c2: &v2, bit: dataBits[bitIndex], delta: qimDelta)
                    modified[idx1] = v1
                    modified[idx2] = v2
                    bitIndex += 1
                }

                let reconstructed = idct2d(modified)
                for r in 0..<blockSize {
                    for c in 0..<blockSize {
                        let idx = (blockY + r) * alignedW + (blockX + c)
                        let val = reconstructed[r * blockSize + c] + 128.0
                        channelR[idx] = UInt8(max(0, min(255, round(val))))
                    }
                }
                blockIndex += 1
            }
        }

        logger.info("DCT 嵌入完成: header \(headerBits.count) bits + data \(dataBits.count) bits")

        // 将修改后的 R 通道写回像素数据
        var resultPixels = pixelData
        injectChannel(&resultPixels, channel: 0, data: channelR, width: width, height: height, alignedW: alignedW, alignedH: alignedH)

        guard let resultImage = createImage(from: resultPixels, width: width, height: height) else {
            throw StegoError.embedFailed
        }
        return resultImage
    }

    private func extractDCT(cgImage: CGImage, width: Int, height: Int) throws -> Data {
        let alignedW = (width / blockSize) * blockSize
        let alignedH = (height / blockSize) * blockSize

        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        let channelR = extractChannel(pixelData, channel: 0, width: width, height: height, alignedW: alignedW, alignedH: alignedH)

        let blocksX = alignedW / blockSize
        let blocksY = alignedH / blockSize
        let totalBlocks = blocksX * blocksY
        let maxBits = totalBlocks * coeffPairs.count

        // 先提取 header (10 bytes = 80 bits)
        let headerBits = extractDCTBits(from: channelR, alignedW: alignedW, alignedH: alignedH, count: 80, maxBits: maxBits)
        let headerBytes = bitsToBytes(headerBits)

        guard headerBytes.count >= 10 else { throw StegoError.noHiddenData }
        guard headerBytes[0] == StegoMode.dct.rawValue else { throw StegoError.corruptedData }

        // 读取 strength 索引
        let strengthIndex = headerBytes[1]
        let strength = StrengthLevel(rawValue: strengthIndex) ?? .standard
        let qimDelta = strength.delta

        // 校验魔数
        let magic = Data(headerBytes[6..<10])
        guard magic == Data([0x59, 0x55, 0x4C, 0x50]) else { throw StegoError.noHiddenData }

        // 数据长度
        let dataLength = Data(headerBytes[2..<6]).withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
        guard dataLength <= maxDataSize else { throw StegoError.corruptedData }

        // 提取全部 header + payload
        let totalBitsNeeded = (10 + Int(dataLength)) * 8
        guard totalBitsNeeded <= maxBits else { throw StegoError.corruptedData }

        let allBits = extractDCTBits(from: channelR, alignedW: alignedW, alignedH: alignedH, count: totalBitsNeeded, maxBits: maxBits, qimDelta: qimDelta)
        let allBytes = bitsToBytes(allBits)

        let startIndex = 10
        let endIndex = startIndex + Int(dataLength)
        guard allBytes.count >= endIndex else { throw StegoError.corruptedData }

        let extracted = Data(allBytes[startIndex..<endIndex])
        logger.info("DCT 提取成功: \(extracted.count) bytes")
        return extracted
    }

    private func extractCopyrightRaw(cgImage: CGImage, width: Int, height: Int) throws -> Data {
        let alignedW = (width / blockSize) * blockSize
        let alignedH = (height / blockSize) * blockSize

        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        let channelR = extractChannel(pixelData, channel: 0, width: width, height: height, alignedW: alignedW, alignedH: alignedH)

        let blocksX = alignedW / blockSize
        let blocksY = alignedH / blockSize
        let totalBlocks = blocksX * blocksY
        let maxBits = totalBlocks * coeffPairs.count

        // 提取 header (10 bytes = 80 bits)
        let headerBits = extractDCTBits(from: channelR, alignedW: alignedW, alignedH: alignedH, count: 80, maxBits: maxBits)
        let headerBytes = bitsToBytes(headerBits)

        guard headerBytes.count >= 10 else { throw StegoError.noHiddenData }
        guard headerBytes[0] == StegoMode.copyright.rawValue else { throw StegoError.corruptedData }

        let strengthIndex = headerBytes[1]
        let strength = StrengthLevel(rawValue: strengthIndex) ?? .standard
        let qimDelta = strength.delta

        let magic = Data(headerBytes[6..<10])
        guard magic == Data([0x59, 0x55, 0x4C, 0x50]) else { throw StegoError.noHiddenData }

        let dataLength = Data(headerBytes[2..<6]).withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
        guard dataLength <= maxDataSize else { throw StegoError.corruptedData }

        let totalBitsNeeded = (10 + Int(dataLength)) * 8
        guard totalBitsNeeded <= maxBits else { throw StegoError.corruptedData }

        let allBits = extractDCTBits(from: channelR, alignedW: alignedW, alignedH: alignedH, count: totalBitsNeeded, maxBits: maxBits, qimDelta: qimDelta)
        let allBytes = bitsToBytes(allBits)

        let startIndex = 10
        let endIndex = startIndex + Int(dataLength)
        guard allBytes.count >= endIndex else { throw StegoError.corruptedData }

        return Data(allBytes[startIndex..<endIndex])
    }

    private func extractDCTBits(from channel: [UInt8], alignedW: Int, alignedH: Int, count: Int, maxBits: Int, qimDelta: Float? = nil) -> [UInt8] {
        let delta = qimDelta ?? 24.0
        var bits = [UInt8]()
        bits.reserveCapacity(count)
        var bitIndex = 0

        for blockY in stride(from: 0, to: alignedH, by: blockSize) {
            for blockX in stride(from: 0, to: alignedW, by: blockSize) {
                guard bitIndex < count else { break }

                var block = [Float](repeating: 0, count: 64)
                for r in 0..<blockSize {
                    for c in 0..<blockSize {
                        let idx = (blockY + r) * alignedW + (blockX + c)
                        block[r * blockSize + c] = Float(channel[idx]) - 128.0
                    }
                }

                let coeffs = dct2d(block)

                for pairIdx in 0..<coeffPairs.count {
                    guard bitIndex < count else { break }
                    let (r1, c1) = coeffPairs[pairIdx]
                    let idx1 = r1 * blockSize + c1
                    let r2 = c1, c2 = r1
                    let idx2 = r2 * blockSize + c2

                    let bit = extractQIM(c1: coeffs[idx1], c2: coeffs[idx2], delta: delta)
                    bits.append(bit)
                    bitIndex += 1
                }
            }
        }
        return bits
    }

    // MARK: - QIM (Quantization Index Modulation)

    private func embedQIM(c1: inout Float, c2: inout Float, bit: UInt8, delta: Float) {
        let diff = c1 - c2
        let q = round(diff / delta)
        // bit=0 → 偶数量化区间，bit=1 → 奇数量化区间
        let targetQ = (bit == 0)
            ? q - q.truncatingRemainder(dividingBy: 2)
            : q - q.truncatingRemainder(dividingBy: 2) + 1
        let adjustment = targetQ * delta - diff
        // 对称分配：c1 和 c2 各承担一半调整，减少单系数扰动幅度
        c1 = c1 + adjustment * 0.5
        c2 = c2 - adjustment * 0.5
    }

    private func extractQIM(c1: Float, c2: Float, delta: Float) -> UInt8 {
        let diff = c1 - c2
        let q = round(diff / delta)
        return q.truncatingRemainder(dividingBy: 2) == 0 ? 0 : 1
    }

    // MARK: - 2D DCT (8x8 block)

    private func dct2d(_ block: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: 64)

        // 对每行做 1D DCT
        var rows = [Float](repeating: 0, count: 64)
        for r in 0..<blockSize {
            let row = Array(block[r * blockSize..<(r + 1) * blockSize])
            let transformed = dct1d(row)
            for c in 0..<blockSize {
                rows[r * blockSize + c] = transformed[c]
            }
        }

        // 对每列做 1D DCT
        for c in 0..<blockSize {
            var col = [Float](repeating: 0, count: blockSize)
            for r in 0..<blockSize {
                col[r] = rows[r * blockSize + c]
            }
            let transformed = dct1d(col)
            for r in 0..<blockSize {
                result[r * blockSize + c] = transformed[r]
            }
        }

        return result
    }

    private func idct2d(_ coeffs: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: 64)

        // 对每列做 1D IDCT
        var cols = [Float](repeating: 0, count: 64)
        for c in 0..<blockSize {
            var col = [Float](repeating: 0, count: blockSize)
            for r in 0..<blockSize {
                col[r] = coeffs[r * blockSize + c]
            }
            let transformed = idct1d(col)
            for r in 0..<blockSize {
                cols[r * blockSize + c] = transformed[r]
            }
        }

        // 对每行做 1D IDCT
        for r in 0..<blockSize {
            let row = Array(cols[r * blockSize..<(r + 1) * blockSize])
            let transformed = idct1d(row)
            for c in 0..<blockSize {
                result[r * blockSize + c] = transformed[c]
            }
        }

        return result
    }

    /// DCT-II
    private func dct1d(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: 8)
        let scale0 = 1.0 / sqrtf(2.0)

        for k in 0..<8 {
            var sum: Float = 0
            for n in 0..<8 {
                sum += input[n] * cosTable[k][n]
            }
            let ck: Float = (k == 0) ? scale0 : 1.0
            output[k] = 0.5 * ck * sum
        }
        return output
    }

    /// DCT-III (inverse DCT)
    private func idct1d(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: 8)
        let scale0 = 1.0 / sqrtf(2.0)

        for n in 0..<8 {
            var sum: Float = 0
            for k in 0..<8 {
                let ck: Float = (k == 0) ? scale0 : 1.0
                sum += ck * input[k] * cosTable[k][n]
            }
            output[n] = 0.5 * sum
        }
        return output
    }

    // MARK: - Channel helpers

    /// 从 RGBA 像素中提取单通道灰度数据（裁剪到 alignedW x alignedH）
    private func extractChannel(_ pixelData: [UInt8], channel: Int, width: Int, height: Int, alignedW: Int, alignedH: Int) -> [UInt8] {
        var channelData = [UInt8](repeating: 0, count: alignedW * alignedH)
        for y in 0..<alignedH {
            for x in 0..<alignedW {
                let pixelIdx = (y * width + x) * 4 + channel
                channelData[y * alignedW + x] = pixelData[pixelIdx]
            }
        }
        return channelData
    }

    /// 将单通道数据写回 RGBA 像素
    private func injectChannel(_ pixelData: inout [UInt8], channel: Int, data: [UInt8], width: Int, height: Int, alignedW: Int, alignedH: Int) {
        for y in 0..<alignedH {
            for x in 0..<alignedW {
                let pixelIdx = (y * width + x) * 4 + channel
                pixelData[pixelIdx] = data[y * alignedW + x]
            }
        }
    }

    // MARK: - Bit/Byte conversion

    private func bitsToBytes(_ bits: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = []
        for i in stride(from: 0, to: bits.count - 7, by: 8) {
            var byte: UInt8 = 0
            for j in 0..<8 {
                byte = (byte << 1) | bits[i + j]
            }
            bytes.append(byte)
        }
        return bytes
    }

    // MARK: - Header

/// Header 格式:
    ///   LSB: version(1) + length(4 bigEndian) + magic(4) = 9 bytes
    ///   DCT/Copyright: version(1) + strength(1) + length(4 bigEndian) + magic(4) = 10 bytes
    private func createHeader(_ data: Data, mode: StegoMode, strength: StrengthLevel = .standard) -> Data {
        var header = Data()
        header.append(mode.rawValue)
        if mode == .dct || mode == .copyright {
            header.append(strength.rawValue)
        }
        var length = UInt32(data.count).bigEndian
        header.append(Data(bytes: &length, count: 4))
        header.append(contentsOf: [0x59, 0x55, 0x4C, 0x50])
        return header
    }

    // MARK: - Pixel/Image helpers

    private func getPixelData(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

    private func createImage(from pixelData: [UInt8], width: Int, height: Int) -> UIImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else { return nil }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
