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
}

// MARK: - StegoService

class StegoService {
    static let shared = StegoService()

    private let minLength = 100
    private let maxLength = 12000
    private let maxDataSize = 1024 * 1024 // 1MB

    // DCT-QIM 参数
    private let blockSize = 8
    private let qimDelta: Float = 24.0  // 量化步长，越大越抗压缩但失真越大

    // 中频系数对 (row, col) — 避开 DC 和高频
    private let coeffPairs: [(Int, Int)] = [
        (2, 3), (3, 2), (4, 1), (1, 4),
        (3, 4), (4, 3), (5, 2), (2, 5)
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
    func embed(data: Data, into image: UIImage, mode: StegoMode = .dct) throws -> UIImage {
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
            return try embedDCT(data: data, cgImage: cgImage, width: width, height: height)
        }
    }

    /// 从图片中提取数据
    func extract(from image: UIImage) throws -> Data {
        logger.info("开始提取数据")

        let image = Self.normalizeOrientation(image)
        guard let cgImage = image.cgImage else {
            throw StegoError.imageLoadFailed
        }

        // 先尝试检测模式：读取第一个字节判断版本号
        let width = cgImage.width
        let height = cgImage.height

        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        // 读取第一个字节来判断编码模式
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

        if let mode = StegoMode(rawValue: firstByte) {
            logger.info("检测到编码模式: \(mode == .dct ? "DCT" : "LSB")")
            switch mode {
            case .lsb:
                return try extractLSB(cgImage: cgImage, width: width, height: height, headerOffset: 9)
            case .dct:
                return try extractDCT(cgImage: cgImage, width: width, height: height)
            }
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

    private func embedDCT(data: Data, cgImage: CGImage, width: Int, height: Int) throws -> UIImage {
        // 裁剪到 8 的倍数
        let alignedW = (width / blockSize) * blockSize
        let alignedH = (height / blockSize) * blockSize

        guard alignedW >= 64 && alignedH >= 64 else {
            throw StegoError.imageTooSmall
        }

        let header = createHeader(data, mode: .dct)
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

        logger.info("DCT 嵌入: \(blocksX)x\(blocksY) blocks, 容量 \(maxBits/8) bytes")

        // 提取 R/G/B 三个通道的灰度矩阵
        guard let pixelData = getPixelData(from: cgImage) else {
            throw StegoError.imageLoadFailed
        }

        // 对 R 通道做 DCT 嵌入（人眼对红色最不敏感）
        var channelR = extractChannel(pixelData, channel: 0, width: width, height: height, alignedW: alignedW, alignedH: alignedH)

        var bitIndex = 0

        for blockY in stride(from: 0, to: alignedH, by: blockSize) {
            for blockX in stride(from: 0, to: alignedW, by: blockSize) {
                guard bitIndex < bits.count else { break }

                // 提取 8x8 块
                var block = [Float](repeating: 0, count: 64)
                for r in 0..<blockSize {
                    for c in 0..<blockSize {
                        let idx = (blockY + r) * alignedW + (blockX + c)
                        block[r * blockSize + c] = Float(channelR[idx]) - 128.0
                    }
                }

                // 正向 DCT
                let coeffs = dct2d(block)

                // 在中频系数对上嵌入比特
                var modified = coeffs
                for pairIdx in 0..<coeffPairs.count {
                    guard bitIndex < bits.count else { break }
                    let (r1, c1) = coeffPairs[pairIdx]
                    let idx1 = r1 * blockSize + c1
                    // 使用对称位置作为配对
                    let r2 = c1, c2 = r1
                    let idx2 = r2 * blockSize + c2

                    embedQIM(c1: &modified[idx1], c2: &modified[idx2], bit: bits[bitIndex], delta: qimDelta)
                    bitIndex += 1
                }

                // 反向 DCT
                let reconstructed = idct2d(modified)

                // 写回像素
                for r in 0..<blockSize {
                    for c in 0..<blockSize {
                        let idx = (blockY + r) * alignedW + (blockX + c)
                        let val = reconstructed[r * blockSize + c] + 128.0
                        channelR[idx] = UInt8(max(0, min(255, round(val))))
                    }
                }
            }
        }

        logger.info("DCT 嵌入完成: \(bitIndex) bits")

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

        // 先提取 header (9 bytes = 72 bits)
        let headerBits = extractDCTBits(from: channelR, alignedW: alignedW, alignedH: alignedH, count: 72, maxBits: maxBits)
        let headerBytes = bitsToBytes(headerBits)

        guard headerBytes.count >= 9 else { throw StegoError.noHiddenData }
        guard headerBytes[0] == StegoMode.dct.rawValue else { throw StegoError.corruptedData }

        // 校验魔数
        let magic = Data(headerBytes[5..<9])
        guard magic == Data([0x59, 0x55, 0x4C, 0x50]) else { throw StegoError.noHiddenData }

        // 数据长度
        let dataLength = Data(headerBytes[1..<5]).withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
        guard dataLength <= maxDataSize else { throw StegoError.corruptedData }

        // 提取全部 header + payload
        let totalBitsNeeded = (9 + Int(dataLength)) * 8
        guard totalBitsNeeded <= maxBits else { throw StegoError.corruptedData }

        let allBits = extractDCTBits(from: channelR, alignedW: alignedW, alignedH: alignedH, count: totalBitsNeeded, maxBits: maxBits)
        let allBytes = bitsToBytes(allBits)

        let startIndex = 9
        let endIndex = startIndex + Int(dataLength)
        guard allBytes.count >= endIndex else { throw StegoError.corruptedData }

        let extracted = Data(allBytes[startIndex..<endIndex])
        logger.info("DCT 提取成功: \(extracted.count) bytes")
        return extracted
    }

    private func extractDCTBits(from channel: [UInt8], alignedW: Int, alignedH: Int, count: Int, maxBits: Int) -> [UInt8] {
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

                    let bit = extractQIM(c1: coeffs[idx1], c2: coeffs[idx2], delta: qimDelta)
                    bits.append(bit)
                    bitIndex += 1
                }
            }
        }
        return bits
    }

    // MARK: - QIM (Quantization Index Modulation)

    private func embedQIM(c1: inout Float, c2: inout Float, bit: UInt8, delta: Float) {
        let halfDelta = delta / 2.0
        let diff = c1 - c2
        let quantized = floor(diff / halfDelta + 0.5) * halfDelta

        if bit == 0 {
            // 使 diff 落在 delta 的偶数倍附近
            if quantized.truncatingRemainder(dividingBy: delta) != 0 {
                c1 = c1 - (quantized - (quantized / delta).rounded() * delta)
            }
        } else {
            // 使 diff 落在 delta 的奇数倍附近
            if quantized.truncatingRemainder(dividingBy: delta) == 0 {
                c1 = c1 + halfDelta
            }
        }

        // 确保修改后 diff 的奇偶性正确
        let newDiff = c1 - c2
        let q = round(newDiff / delta)
        if bit == 0 && q.truncatingRemainder(dividingBy: 2) != 0 {
            c1 = c1 + delta
        } else if bit == 1 && q.truncatingRemainder(dividingBy: 2) == 0 {
            c1 = c1 + delta
        }
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

    /// Header 格式: version(1) + length(4 bigEndian) + magic(4) = 9 bytes
    private func createHeader(_ data: Data, mode: StegoMode) -> Data {
        var header = Data()
        header.append(mode.rawValue)
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
