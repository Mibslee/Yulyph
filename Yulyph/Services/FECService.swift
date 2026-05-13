import Foundation

class FECService {
    static let shared = FECService()

    private let blockSize = 223
    private let paritySize = 32

    private init() {}

    func encode(_ data: Data) -> Data {
        var encoded = Data()

        for chunk in data.chunked(into: blockSize) {
            encoded.append(chunk)
            let parity = calculateParity(chunk)
            encoded.append(parity)
        }

        return encoded
    }

    func decode(_ data: Data) -> Data {
        var decoded = Data()
        let totalBlockSize = blockSize + paritySize

        for i in stride(from: 0, to: data.count, by: totalBlockSize) {
            let end = min(i + totalBlockSize, data.count)
            let chunk = data[i..<end]

            let dataEnd: Int
            let dataBlock: Data
            let parityBlock: Data

            if chunk.count < totalBlockSize {
                // 结尾不完整块：data + parity，其中 parity 在末尾
                guard chunk.count > paritySize else {
                    // 数据不足，直接丢弃
                    continue
                }
                dataEnd = chunk.count - paritySize
                dataBlock = chunk[0..<dataEnd]
                parityBlock = chunk[dataEnd..<chunk.count]
            } else {
                dataEnd = blockSize
                dataBlock = chunk[0..<dataEnd]
                parityBlock = chunk[dataEnd..<totalBlockSize]
            }

            if verifyParity(dataBlock, parity: parityBlock) {
                decoded.append(dataBlock)
            } else if let corrected = tryCorrect(dataBlock, parity: parityBlock) {
                decoded.append(corrected)
            } else {
                // 无法修正，保留原始数据（调用方可自行判断）
                decoded.append(dataBlock)
            }
        }

        return decoded
    }

    private func calculateParity(_ data: Data) -> Data {
        var parity = Data(repeating: 0, count: paritySize)

        for (index, byte) in data.enumerated() {
            parity[index % paritySize] ^= byte
        }

        return parity
    }

    private func verifyParity(_ data: Data, parity: Data) -> Bool {
        return calculateParity(data) == parity
    }

    /// 尝试修正单字节错误：对每个字节翻转，检查 parity 是否恢复。
    private func tryCorrect(_ data: Data, parity: Data) -> Data? {
        let bytes = [UInt8](data)
        let parityBytes = [UInt8](parity)
        var corrected = bytes

        for i in 0..<corrected.count {
            let parityIndex = i % paritySize
            // 计算当前 parity 中该位置的期望值
            var expected: UInt8 = 0
            for j in stride(from: parityIndex, to: bytes.count, by: paritySize) {
                if j == i { continue }
                expected ^= bytes[j]
            }
            // 翻转后应该使得 parity[parityIndex] == expected ^ newValue
            let targetParity = parityBytes[parityIndex]
            let neededValue = targetParity ^ expected
            if neededValue != bytes[i] {
                corrected[i] = neededValue
                if calculateParity(Data(corrected)) == parity {
                    return Data(corrected)
                }
                corrected[i] = bytes[i] // 还原
            }
        }

        return nil
    }
}

extension Data {
    func chunked(into size: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0

        while offset < count {
            let end = Swift.min(offset + size, count)
            let chunk = self[offset..<end]
            chunks.append(Data(chunk))
            offset = end
        }

        return chunks
    }
}
