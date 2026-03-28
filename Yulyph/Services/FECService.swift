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
    
    func decode(_ data: Data) -> Data? {
        var decoded = Data()
        let totalBlockSize = blockSize + paritySize
        
        for i in stride(from: 0, to: data.count, by: totalBlockSize) {
            let end = min(i + totalBlockSize, data.count)
            let chunk = data[i..<end]
            
            if chunk.count < totalBlockSize {
                decoded.append(chunk)
                continue
            }
            
            let dataBlock = chunk[0..<blockSize]
            let parityBlock = chunk[blockSize..<totalBlockSize]
            
            if verifyParity(dataBlock, parity: parityBlock) {
                decoded.append(dataBlock)
            } else {
                if let corrected = tryCorrect(dataBlock, parity: parityBlock) {
                    decoded.append(corrected)
                } else {
                    decoded.append(dataBlock)
                }
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
        let calculatedParity = calculateParity(data)
        return calculatedParity == parity
    }
    
    private func tryCorrect(_ data: Data, parity: Data) -> Data? {
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