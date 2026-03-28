import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import os.log

private let logger = Logger(subsystem: "com.shanestudio.yulyph", category: "StegoService")

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

class StegoService {
    static let shared = StegoService()
    
    private let minLength = 100
    private let maxLength = 8000
    private let maxDataSize = 1024 * 1024 // 1MB max
    
    private init() {}
    
    func embed(data: Data, into image: UIImage) throws -> UIImage {
        logger.info("开始嵌入数据，数据大小: \(data.count) bytes")
        
        guard let cgImage = image.cgImage else {
            logger.error("图片加载失败")
            throw StegoError.imageLoadFailed
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        logger.info("图片尺寸: \(width) x \(height)")
        
        guard width >= minLength && height >= minLength else {
            logger.error("图片太小: \(width) x \(height)")
            throw StegoError.imageTooSmall
        }
        
        guard width <= maxLength && height <= maxLength else {
            logger.error("图片太大: \(width) x \(height)")
            throw StegoError.imageTooLarge
        }
        
        let maxCapacity = (width * height * 3) / 8
        logger.info("最大容量: \(maxCapacity) bytes")
        
        guard data.count <= maxCapacity else {
            logger.error("数据超出容量: \(data.count) > \(maxCapacity)")
            throw StegoError.capacityExceeded
        }
        
        guard let pixelData = getPixelData(from: cgImage) else {
            logger.error("获取像素数据失败")
            throw StegoError.imageLoadFailed
        }
        
        logger.info("像素数据大小: \(pixelData.count)")
        
        let dataWithHeader = createDataWithHeader(data)
        var modifiedPixels = pixelData
        
        var bitIndex = 0
        let bits = dataWithHeader.flatMap { byte in
            (0..<8).map { bit in
                (byte >> (7 - bit)) & 1
            }
        }
        
        logger.info("总比特数: \(bits.count)")
        
        let pixelCount = modifiedPixels.count
        for i in stride(from: 0, to: pixelCount - 3, by: 4) {
            guard bitIndex < bits.count else { break }
            
            for channel in 0..<3 {
                guard bitIndex < bits.count else { break }
                
                let value = (modifiedPixels[i + channel] & 0xFE) | bits[bitIndex]
                modifiedPixels[i + channel] = value
                bitIndex += 1
            }
            
            if i % 100000 == 0 {
                logger.debug("处理进度: \(i)/\(pixelCount)")
            }
        }
        
        logger.info("嵌入完成，处理了 \(bitIndex) 个比特")
        
        guard let resultImage = createImage(from: modifiedPixels, width: width, height: height) else {
            logger.error("创建图片失败")
            throw StegoError.embedFailed
        }
        
        logger.info("嵌入成功")
        return resultImage
    }
    
    func extract(from image: UIImage) throws -> Data {
        logger.info("开始提取数据")
        
        guard let cgImage = image.cgImage else {
            logger.error("图片加载失败")
            throw StegoError.imageLoadFailed
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        logger.info("图片尺寸: \(width) x \(height)")
        
        guard let pixelData = getPixelData(from: cgImage) else {
            logger.error("获取像素数据失败")
            throw StegoError.imageLoadFailed
        }
        
        logger.info("像素数据大小: \(pixelData.count)")
        
        // 首先提取头部信息获取数据长度
        var headerBits: [UInt8] = []
        let headerByteCount = 8 // 4字节长度 + 4字节魔数
        let headerBitCount = headerByteCount * 8
        
        var bitCount = 0
        for i in stride(from: 0, to: pixelData.count - 3, by: 4) {
            guard bitCount < headerBitCount else { break }
            
            for channel in 0..<3 {
                guard bitCount < headerBitCount else { break }
                headerBits.append(pixelData[i + channel] & 1)
                bitCount += 1
            }
        }
        
        // 解析头部
        var headerBytes: [UInt8] = []
        for i in stride(from: 0, to: headerBits.count - 7, by: 8) {
            var byte: UInt8 = 0
            for j in 0..<8 {
                byte = (byte << 1) | headerBits[i + j]
            }
            headerBytes.append(byte)
        }
        
        let headerData = Data(headerBytes)
        
        // 检查魔数
        guard headerData.count >= 8 else {
            logger.error("头部数据不完整")
            throw StegoError.noHiddenData
        }
        
        let magic = headerData[4..<8]
        guard magic == Data([0x59, 0x55, 0x4C, 0x50]) else {
            logger.error("魔数不匹配")
            throw StegoError.noHiddenData
        }
        
        // 获取数据长度
        let lengthData = headerData[0..<4]
        let dataLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        logger.info("数据长度: \(dataLength) bytes")
        
        guard dataLength <= maxDataSize else {
            logger.error("数据长度异常: \(dataLength)")
            throw StegoError.corruptedData
        }
        
        // 提取完整数据
        let totalBitsNeeded = (Int(dataLength) + headerByteCount) * 8
        var allBits: [UInt8] = []
        
        bitCount = 0
        for i in stride(from: 0, to: pixelData.count - 3, by: 4) {
            guard bitCount < totalBitsNeeded else { break }
            
            for channel in 0..<3 {
                guard bitCount < totalBitsNeeded else { break }
                allBits.append(pixelData[i + channel] & 1)
                bitCount += 1
            }
        }
        
        // 转换为字节
        var allBytes: [UInt8] = []
        for i in stride(from: 0, to: allBits.count - 7, by: 8) {
            var byte: UInt8 = 0
            for j in 0..<8 {
                byte = (byte << 1) | allBits[i + j]
            }
            allBytes.append(byte)
        }
        
        // 跳过头部，获取实际数据
        let startIndex = headerByteCount
        let endIndex = startIndex + Int(dataLength)
        
        guard allBytes.count >= endIndex else {
            logger.error("数据不完整: \(allBytes.count) < \(endIndex)")
            throw StegoError.corruptedData
        }
        
        let extractedData = Data(allBytes[startIndex..<endIndex])
        logger.info("提取成功，数据大小: \(extractedData.count) bytes")
        
        return extractedData
    }
    
    private func getPixelData(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pixelData
    }
    
    private func createImage(from pixelData: [UInt8], width: Int, height: Int) -> UIImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
            return nil
        }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func createDataWithHeader(_ data: Data) -> Data {
        var header = Data()
        var length = UInt32(data.count)
        header.append(Data(bytes: &length, count: 4))
        header.append(contentsOf: [0x59, 0x55, 0x4C, 0x50])
        header.append(data)
        return header
    }
}