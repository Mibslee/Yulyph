# Yulyph v1.6 — 版权水印功能 + UI 重构实现计划

> **For Hermes:** 使用 subagent-driven-development skill 逐任务执行。

**目标：** 在 Yulyph 中新增版权水印模块（嵌入 + 扫描识别），并重构首页 UI 为 Segmented Picker 切换「隐藏」/「版权」两大模块。

**架构：** 版权水印复用现有 `embedDCT`/`extractDCT`，新增 `StegoMode.copyright (0x02)` 版本标识。新增两个 SwiftUI 页面处理嵌入和扫描，摄像头扫描使用 `AVCaptureSession` 逐帧检测。

**技术栈：** SwiftUI / AVFoundation / PHPicker / Core Image

---

## Task 1: 添加 StegoMode.copyright 枚举值

**Objective:** 在 StegoMode 枚举中添加 copyright 模式

**Files:**
- Modify: `Yulyph/Services/StegoService.swift:35-38`

**Step 1: 添加枚举值**

```swift
enum StegoMode: UInt8 {
    case lsb = 0x00  // 高容量，空间域 LSB
    case dct = 0x01  // 抗压缩，频域 DCT-QIM
    case copyright = 0x02  // 版权水印
}
```

**Step 2: 验证**

运行 Xcode Build，确保无编译错误。

**Step 3: 提交**

```bash
git add Yulyph/Services/StegoService.swift
git commit -m "feat: add StegoMode.copyright enum value"
```

---

## Task 2: 创建 CopyrightInfo 模型

**Objective:** 创建版权信息数据结构

**Files:**
- Create: `Yulyph/Models/CopyrightInfo.swift`

**Step 1: 创建文件**

```swift
import Foundation

struct CopyrightInfo: Codable, Identifiable {
    let id = UUID()
    let creator: String
    let year: Int
    let license: String
    let isPublic: Bool  // true=无密钥，false=私有
    var imageName: String?
    var detectedAt: Date

    /// 从 JSON 字符串解析
    static func parse(from jsonString: String) -> CopyrightInfo? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let c = json["c"] as? String,
              let y = json["y"] as? Int,
              let l = json["l"] as? String else { return nil }
        return CopyrightInfo(creator: c, year: y, license: l, isPublic: true, imageName: nil, detectedAt: Date())
    }

    /// 序列化为 JSON 字符串
    func toJSON() -> String {
        let dict: [String: Any] = ["c": creator, "y": year, "l": license]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
```

**Step 2: 验证**

确认文件创建成功，无语法错误。

**Step 3: 提交**

```bash
git add Yulyph/Models/CopyrightInfo.swift
git commit -m "feat: add CopyrightInfo model"
```

---

## Task 3: 添加 embedCopyright 方法

**Objective:** 添加嵌入版权水印的公开 API

**Files:**
- Modify: `Yulyph/Services/StegoService.swift`（在 embed 方法后添加）

**Step 1: 添加 embedCopyright 方法**

在 `capacity(for:mode:)` 方法后添加：

```swift
/// 嵌入版权水印到图片中
/// - Parameters:
///   - info: 版权信息
///   - image: 载体图片
///   - password: 可选密钥，留空则不加密（公开版权）
///   - strength: 嵌入强度，默认 .standard
func embedCopyright(info: CopyrightInfo, into image: UIImage, password: String? = nil, strength: StrengthLevel? = nil) throws -> UIImage {
    var data = Data(info.toJSON().utf8)

    // 如果提供了密钥，加密元数据
    if let pwd = password, !pwd.isEmpty {
        data = try CryptoService.shared.encrypt(info.toJSON(), with: pwd)
    }

    let header = createHeader(data, mode: .copyright, strength: strength ?? .standard)
    let payload = header + data
    return try embed(data: payload, into: image, mode: .copyright, strength: strength)
}
```

**Step 2: 修改 embed 方法支持 copyright 模式**

在 `embed` 方法的 switch 中添加：

```swift
case .copyright:
    let level = strength ?? defaultStrength
    return try embedDCT(data: data, cgImage: cgImage, width: width, height: height, strength: level)
```

**Step 3: 验证**

确保 `embed(data:into:mode:strength:)` 可以接受 `.copyright` 模式。

**Step 4: 提交**

```bash
git add Yulyph/Services/StegoService.swift
git commit -m "feat: add embedCopyright method"
```

---

## Task 4: 添加 extractCopyright 方法

**Objective:** 添加从图片提取版权信息的 API

**Files:**
- Modify: `Yulyph/Services/StegoService.swift`

**Step 1: 添加 extractCopyright 方法**

在 `extract` 方法后添加：

```swift
/// 从图片中提取版权信息
/// - Parameters:
///   - image: 包含版权水印的图片
///   - password: 可选密钥（如果嵌入时提供了密钥）
func extractCopyright(from image: UIImage, password: String? = nil) throws -> CopyrightInfo {
    let rawData = try extract(from: image)

    var jsonString: String

    // 尝试直接解析（公开版权）
    if let s = String(data: rawData, encoding: .utf8) {
        jsonString = s
    } else if let pwd = password, !pwd.isEmpty {
        // 尝试解密（私有版权）
        jsonString = try CryptoService.shared.decrypt(rawData, with: pwd)
    } else {
        throw StegoError.corruptedData
    }

    guard var info = CopyrightInfo.parse(from: jsonString) else {
        throw StegoError.corruptedData
    }
    info.isPublic = password == nil || password?.isEmpty == true
    return info
}
```

**Step 2: 更新 extract 方法的版权检测**

在 `extract()` 方法的 DCT 检测逻辑中，读取到版本字节为 `0x02` 时调用 `extractCopyright`。在模式检测段末尾添加：

```swift
if modeByte == StegoMode.dct.rawValue {
    logger.info("检测到 DCT 编码模式")
    return try extractDCT(cgImage: cgImage, width: width, height: height)
} else if modeByte == StegoMode.copyright.rawValue {
    logger.info("检测到版权水印")
    return try extractCopyright(from: image)
}
```

注意：`extract()` 返回 `Data` 类型，版权模式需要特殊处理。需要将版权检测逻辑从版本字节匹配中移出，单独判断。改为：

在 `extract()` 的 DCT 检测块中，检测到 `0x02` 时直接调用 `extractCopyright(from:)` 并返回其 `CopyrightInfo`。需要将 `extract()` 的返回类型改为 `Any` 或者新增 `extractMode(from:)` 方法返回检测到的模式和数据。

更简单的方案：在 `extract()` 中，检测到 `0x02` 版本字节时，直接调用 `extractCopyright` 并返回其 `CopyrightInfo`。但 `extract()` 声明返回 `Data`，需要改变设计。

**替代方案（推荐）：** 在 `extract()` 检测到版权模式时，直接调用 `extractCopyright` 并抛出一个特殊错误携带版权信息，或者让 `extract()` 返回的 `Data` 能被 `extractCopyright` 识别。

最终方案：新增 `detectMode(from:)` 方法返回 `StegoMode?`，然后在 `CopyrightScanView` 中先调用 `detectMode`，如果是 `.copyright` 则调用 `extractCopyright`，否则调用 `extract`。

**Step 2: 添加 detectMode 方法**

在 `extract` 方法开头添加：

```swift
/// 检测图片中隐藏数据的编码模式
func detectMode(from image: UIImage) -> StegoMode? {
    let image = Self.normalizeOrientation(image)
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    let alignedW = (width / blockSize) * blockSize
    let alignedH = (height / blockSize) * blockSize

    // DCT 版权检测
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
        var modeByte: UInt8 = 0
        for j in 0..<8 {
            modeByte = (modeByte << 1) | modeByteBits[j]
        }
        if modeByte == StegoMode.copyright.rawValue {
            return .copyright
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
```

**Step 3: 更新 extract 中的版权检测**

在 `extract()` 方法中，找到版本字节检测逻辑，添加版权分支：

```swift
if modeByte == StegoMode.dct.rawValue {
    logger.info("检测到 DCT 编码模式")
    return try extractDCT(cgImage: cgImage, width: width, height: height)
} else if modeByte == StegoMode.copyright.rawValue {
    logger.info("检测到版权水印")
    return try extractCopyright(from: image)
}
```

但 `extract()` 返回 `Data`，版权模式返回 `CopyrightInfo`，类型不一致。需要修改返回类型或使用泛型。

**简化方案：** `extractCopyright` 不复用 `extract`，而是独立实现完整的 DCT 提取逻辑（读取 header → 提取数据 → 解析元数据）。这样 `extract()` 只需在检测到版权模式时抛出一个特殊错误，由调用方处理。

**最终方案：** 修改 `extract()` 返回类型为 `Any`，或者创建 `extractCopyrightRaw()` 内部方法。

最简洁的方案：让 `extract()` 在检测到版权模式时，直接返回加密的元数据 `Data`，然后 `CopyrightScanView` 拿到数据后再尝试解析/解密。这样 `extract()` 无需修改返回类型。

验证：在 `extract()` 中检测到 `0x02` 时，直接调用内部 DCT 提取逻辑返回 `Data`，调用方根据返回数据的内容判断是版权信息还是普通数据。

**Step 4: 修改 extract 方法**

在 `extract()` 的版本字节检测部分添加：

```swift
if modeByte == StegoMode.dct.rawValue {
    logger.info("检测到 DCT 编码模式")
    return try extractDCT(cgImage: cgImage, width: width, height: height)
} else if modeByte == StegoMode.copyright.rawValue {
    logger.info("检测到版权水印")
    return try extractCopyrightRaw(cgImage: cgImage, width: width, height: height)
}
```

添加 `extractCopyrightRaw` 私有方法（复制 `extractDCT` 的逻辑，但检测版本为 `0x02`）：

```swift
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
```

**Step 5: 验证**

确保编译通过，无类型错误。

**Step 6: 提交**

```bash
git add Yulyph/Services/StegoService.swift
git commit -m "feat: add detectMode and extractCopyright methods"
```

---

## Task 5: 创建 CopyrightEmbedView（标记版权页面）

**Objective:** 创建版权嵌入 UI 页面

**Files:**
- Create: `Yulyph/Views/CopyrightEmbedView.swift`

**Step 1: 创建文件**

```swift
import SwiftUI
import PhotosUI

struct CopyrightEmbedView: View {
    @State private var creatorName = ""
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var selectedLicense = "CC-BY"
    @State private var password = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var strengthIndex: Double = 1
    @State private var isProcessing = false
    @State private var resultImages: [UIImage] = []
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var showAlert = false

    private let licenses = ["CC-BY", "CC-BY-SA", "ARR", "自定义"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    infoSection
                    creatorSection
                    licenseSection
                    passwordSection
                    imageSection
                    strengthSection
                    actionButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("标记版权")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showImagePicker) {
            MultiImagePicker(images: $selectedImages)
        }
        .alert("错误", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showResult) {
            CopyrightResultView(images: resultImages)
        }
    }

    private var infoSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text("版权水印说明")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("在图片中嵌入不可见版权信息，其他人使用 Yulyph 扫描即可识别。留空密钥则公开版权，填密钥则私有。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var creatorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("创作者信息")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            TextField("创作者名称", text: $creatorName)
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)

            HStack {
                Text("年份")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Stepper("\(year)", value: $year, in: 2000...2100)
                    .font(.subheadline)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("许可证")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            Picker("许可证", selection: $selectedLicense) {
                ForEach(licenses, id: \.self) { license in
                    Text(license).tag(license)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("访问密钥")
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(.secondary)
                Text("留空则公开版权")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            SecureField("可选（留空=公开）", text: $password)
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择图片")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            Button {
                showImagePicker = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                    Text("点击选择图片")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("支持多选")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                )
            }

            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedImages.indices, id: \.self) { idx in
                            Image(uiImage: selectedImages[idx])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(8)
                        }
                    }
                }
                Text("\(selectedImages.count) 张图片已选择")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("嵌入强度")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            Slider(value: $strengthIndex, in: 0...3, step: 1)
                .accentColor(.blue)

            HStack {
                Text("精细")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(StrengthLevel(rawValue: UInt8(strengthIndex))?.label ?? "标准")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                Spacer()
                Text("最强")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    private var actionButton: some View {
        Button {
            processEmbed()
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.shield.fill")
                    Text("嵌入版权信息")
                }
            }
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!isValid || isProcessing)
    }

    private var isValid: Bool {
        !creatorName.isEmpty && !selectedImages.isEmpty
    }

    private func processEmbed() {
        isProcessing = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let info = CopyrightInfo(
                    creator: creatorName,
                    year: year,
                    license: selectedLicense,
                    isPublic: password.isEmpty,
                    imageName: nil,
                    detectedAt: Date()
                )
                let strength = StegoService.StrengthLevel(rawValue: UInt8(strengthIndex))
                let pwd = password.isEmpty ? nil : password

                var results: [UIImage] = []
                for image in selectedImages {
                    let embedded = try StegoService.shared.embedCopyright(info: info, into: image, password: pwd, strength: strength)
                    results.append(embedded)
                }

                DispatchQueue.main.async {
                    self.resultImages = results
                    self.isProcessing = false
                    self.showResult = true
                    ActivityStore.shared.record(type: .embed, fileName: "Copyright_\(self.creatorName)", description: "版权 · \(self.selectedLicense)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showAlert = true
                    self.isProcessing = false
                }
            }
        }
    }
}

struct MultiImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 20
        let picker = PHPickerViewController(configuration: config)
        picker.delializer = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiImagePicker

        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            var loadedImages: [UIImage] = []
            let group = DispatchGroup()

            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage {
                        loadedImages.append(img)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.parent.images = loadedImages
            }
        }
    }
}

struct CopyrightResultView: View {
    let images: [UIImage]
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("版权信息已嵌入")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("共 \(images.count) 张图片已标记版权水印")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(images.indices, id: \.self) { idx in
                            Image(uiImage: images[idx])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipped()
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                Button {
                    exportAndShare()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("保存并分享")
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    private func exportAndShare() {
        guard let firstImage = images.first, let pngData = firstImage.pngData() else { return }
        let fileName = "Yulyph_Copyright_\(Int(Date().timeIntervalSince1970)).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {}
    }
}

#Preview {
    CopyrightEmbedView()
}
```

**Step 2: 修复 PHPickerViewControllerDelegate 拼写**

将 `picker.delializer` 改为 `picker.delegate`。

**Step 3: 验证**

确保编译通过。

**Step 4: 提交**

```bash
git add Yulyph/Views/CopyrightEmbedView.swift
git commit -m "feat: add CopyrightEmbedView for marking copyright"
```

---

## Task 6: 创建 CopyrightScanView（扫描识别页面）

**Objective:** 创建版权扫描识别 UI 页面，支持摄像头和相册两种模式

**Files:**
- Create: `Yulyph/Views/CopyrightScanView.swift`

**Step 1: 创建文件**

```swift
import SwiftUI
import AVFoundation
import PhotosUI

struct CopyrightScanView: View {
    @State private var scanMode: ScanMode = .album
    @State private var detectedInfos: [CopyrightInfo] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var isScanning = false
    @State private var scanPassword = ""
    @State private var errorMessage: String?
    @State private var showAlert = false

    enum ScanMode: String, CaseIterable {
        case album = "相册"
        case camera = "摄像头"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("扫描模式", selection: $scanMode) {
                    ForEach(ScanMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if scanMode == .album {
                    albumModeView
                } else {
                    cameraModeView
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("扫描识别")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showImagePicker) {
            MultiImagePicker(images: $selectedImages)
        }
        .alert("错误", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var albumModeView: some View {
        VStack(spacing: 20) {
            if selectedImages.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("从相册选择图片")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("批量检测图片中的版权水印")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))

                    Button {
                        showImagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("选择图片")
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                Spacer()
            } else {
                if isScanning {
                    Spacer()
                    ProgressView("正在扫描...")
                        .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(detectedInfos) { info in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(info.creator)
                                        .font(.headline)
                                    HStack {
                                        Text("\(info.year)")
                                        Text("·")
                                        Text(info.license)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }

                VStack(spacing: 12) {
                    if !detectedInfos.isEmpty {
                        Text("识别到 \(detectedInfos.count) 张含版权水印的图片")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    HStack(spacing: 12) {
                        Button {
                            selectedImages = []
                            detectedInfos = []
                        } label: {
                            Text("重新选择")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }

                        Button {
                            scanSelectedImages()
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("开始扫描")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var cameraModeView: some View {
        CameraScanView(
            onDetected: { info in
                if !detectedInfos.contains(where: { $0.creator == info.creator && $0.year == info.year }) {
                    var newInfo = info
                    newInfo.detectedAt = Date()
                    detectedInfos.append(newInfo)
                }
            },
            password: $scanPassword
        )
    }

    private func scanSelectedImages() {
        isScanning = true
        detectedInfos = []

        DispatchQueue.global(qos: .userInitiated).async {
            for image in selectedImages {
                if let mode = StegoService.shared.detectMode(from: image), mode == .copyright {
                    do {
                        let rawData = try StegoService.shared.extract(from: image)
                        var jsonString: String

                        if let s = String(data: rawData, encoding: .utf8) {
                            jsonString = s
                        } else if !scanPassword.isEmpty {
                            jsonString = try CryptoService.shared.decrypt(rawData, with: scanPassword)
                        } else {
                            continue
                        }

                        if var info = CopyrightInfo.parse(from: jsonString) {
                            info.isPublic = scanPassword.isEmpty
                            info.imageName = "Image"
                            info.detectedAt = Date()
                            DispatchQueue.main.async {
                                self.detectedInfos.append(info)
                            }
                        }
                    } catch {
                        // 忽略单张图片的错误，继续扫描
                    }
                }
            }

            DispatchQueue.main.async {
                self.isScanning = false
                if self.detectedInfos.isEmpty {
                    self.errorMessage = "未在所选图片中检测到版权水印"
                    self.showAlert = true
                }
            }
        }
    }
}

struct CameraScanView: UIViewControllerRepresentable {
    let onDetected: (CopyrightInfo) -> Void
    @Binding var password: String

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onDetected = onDetected
        vc.password = password
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.password = password
    }
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onDetected: ((CopyrightInfo) -> Void)?
    var password: String = ""

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastProcessedTime: Date = .distantPast
    private let processingInterval: TimeInterval = 0.5

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async {
                self?.configureSession()
            }
        }
    }

    private func configureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.processing"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        self.previewLayer = previewLayer
        self.captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastProcessedTime) >= processingInterval else { return }
        lastProcessedTime = Date()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processFrame(image)
        }
    }

    private func processFrame(_ image: UIImage) {
        guard let mode = StegoService.shared.detectMode(from: image), mode == .copyright else { return }

        do {
            let rawData = try StegoService.shared.extract(from: image)
            var jsonString: String

            if let s = String(data: rawData, encoding: .utf8) {
                jsonString = s
            } else if !password.isEmpty {
                jsonString = try CryptoService.shared.decrypt(rawData, with: password)
            } else {
                return
            }

            if var info = CopyrightInfo.parse(from: jsonString) {
                info.isPublic = password.isEmpty
                DispatchQueue.main.async { [weak self] in
                    self?.onDetected?(info)
                }
            }
        } catch {}
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

#Preview {
    CopyrightScanView()
}
```

**Step 2: 验证**

确保编译通过。

**Step 3: 提交**

```bash
git add Yulyph/Views/CopyrightScanView.swift
git commit -m "feat: add CopyrightScanView for scanning copyright watermarks"
```

---

## Task 7: 重构 HomeView UI（添加 Segmented Picker）

**Objective:** 重构首页，添加「隐藏」/「版权」Tab 切换

**Files:**
- Modify: `Yulyph/Views/HomeView.swift`

**Step 1: 修改 HomeView**

将 `HomeView` 的内容改为：

```swift
import SwiftUI

struct HomeView: View {
    @StateObject private var activityStore = ActivityStore.shared
    @State private var heroAppeared = false
    @State private var cardsAppeared = false
    @State private var selectedModule: AppModule = .hide

    enum AppModule: String, CaseIterable {
        case hide = "隐藏"
        case copyright = "版权"
    }

    private var appName: String {
        Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? "Yulyph"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    modulePicker
                    moduleContent
                    templateSection
                    recentActivitySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 80)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .overlay(alignment: .top) {
                topAppBar
            }
            .onAppear {
                withAnimation(ThemeAnimation.spring) { heroAppeared = true }
                withAnimation(ThemeAnimation.spring.delay(0.15)) { cardsAppeared = true }
            }
        }
    }

    private var topAppBar: some View {
        HStack {
            HStack(spacing: 12) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .shadow(color: .blue.opacity(0.15), radius: 6, y: 2)

                Text(appName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("您的数字避风港")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 20)

            Text("安全加密，隐藏信息于无形")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 12)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(ThemeGradient.hero).frame(width: 40, height: 4)
                RoundedRectangle(cornerRadius: 2).fill(Color(.systemGray5)).frame(width: 20, height: 4)
            }
            .padding(.top, 4)
            .opacity(heroAppeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modulePicker: some View {
        Picker("模块", selection: $selectedModule) {
            ForEach(AppModule.allCases, id: \.self) { module in
                Text(module.rawValue).tag(module)
            }
        }
        .pickerStyle(.segmented)
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 24)
    }

    @ViewBuilder
    private var moduleContent: some View {
        switch selectedModule {
        case .hide:
            hideModuleCards
        case .copyright:
            copyrightModuleCards
        }
    }

    private var hideModuleCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("核心功能")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            HStack(spacing: 14) {
                NavigationLink { EmbedView() } label: {
                    actionCard(icon: "eye.slash.fill", gradient: ThemeGradient.ocean, title: "隐藏信息", subtitle: "将秘密嵌入图片")
                }
                .opacity(cardsAppeared ? 1 : 0)
                .offset(y: cardsAppeared ? 0 : 24)

                NavigationLink { ExtractView() } label: {
                    actionCard(icon: "lock.open.fill", gradient: ThemeGradient.warmSunset, title: "提取信息", subtitle: "解析隐藏数据")
                }
                .opacity(cardsAppeared ? 1 : 0)
                .offset(y: cardsAppeared ? 0 : 24)
            }
        }
    }

    private var copyrightModuleCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("版权功能")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            HStack(spacing: 14) {
                NavigationLink { CopyrightEmbedView() } label: {
                    actionCard(icon: "checkmark.seal.fill", gradient: LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing), title: "标记版权", subtitle: "嵌入版权水印")
                }
                .opacity(cardsAppeared ? 1 : 0)
                .offset(y: cardsAppeared ? 0 : 24)

                NavigationLink { CopyrightScanView() } label: {
                    actionCard(icon: "camera.viewfinder", gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing), title: "扫描识别", subtitle: "检测版权水印")
                }
                .opacity(cardsAppeared ? 1 : 0)
                .offset(y: cardsAppeared ? 0 : 24)
            }
        }
    }

    private var templateSection: some View {
        NavigationLink { TemplateLibraryView() } label: {
            HStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.title3)
                    .foregroundColor(.accentViolet)
                    .frame(width: 44, height: 44)
                    .background(Color.accentViolet.opacity(0.1))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text("模版库").font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                    Text("创建精美的海报和相框").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .opacity(cardsAppeared ? 1 : 0)
    }

    private func actionCard(icon: String, gradient: LinearGradient, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(gradient)
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近活动")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            if activityStore.activities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("暂无活动记录").font(.subheadline).fontWeight(.medium).foregroundColor(.secondary.opacity(0.7))
                    Text("开始使用隐藏或提取功能后，活动将显示在这里")
                        .font(.caption).foregroundColor(.secondary.opacity(0.5)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(20)
            } else {
                VStack(spacing: 8) {
                    ForEach(activityStore.activities.prefix(5)) { activity in
                        HStack(spacing: 12) {
                            Image(systemName: activity.type == .embed ? "eye.slash.fill" : "lock.open.fill")
                                .font(.caption)
                                .foregroundColor(activity.type == .embed ? .blue : .orange)
                                .frame(width: 28, height: 28)
                                .background((activity.type == .embed ? Color.blue : Color.orange).opacity(0.1))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.description)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(activity.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
```

**Step 2: 验证**

确保编译通过，UI 正确显示。

**Step 3: 提交**

```bash
git add Yulyph/Views/HomeView.swift
git commit -m "refactor: add segmented picker for hide/copyright modules in HomeView"
```

---

## Task 8: 配置 Info.plist 权限

**Objective:** 添加相机和相册权限描述

**Files:**
- Modify: `Yulyph/Info.plist`（或 `Yulyph/Supporting Files/Info.plist`）

**Step 1: 添加权限描述**

找到 Info.plist，添加以下键值：

```xml
<key>NSCameraUsageDescription</key>
<string>用于扫描识别图片中的版权水印</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>用于选择图片嵌入或检测版权水印</string>
```

**Step 2: 验证**

在 Xcode 中打开项目设置，确认权限描述已添加。

**Step 3: 提交**

```bash
git add Yulyph/Info.plist
git commit -m "config: add camera and photo library permissions"
```

---

## Task 9: 更新 CHANGELOG

**Objective:** 记录 v1.6 版本变更

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: 添加 v1.6 变更记录**

在 CHANGELOG.md 顶部添加：

```markdown
## v1.6 (开发中)

### 新增功能

- **版权水印模块** — 在图片中嵌入不可见版权信息，支持创作者、年份、许可证类型
- **版权扫描识别** — 支持摄像头实时扫描和相册批量检测含版权水印的图片
- **嵌入强度滑块** — DCT 模式支持 4 档强度调节（精细/标准/增强/最强）
- **实时容量预览** — 嵌入前实时显示图片容量和消息大小对比

### UI 重构

- **首页 Tab 切换** — Segmented Picker 切换「隐藏」和「版权」两大模块
- **最近活动功能** — 记录并展示最近 10 条嵌入/提取操作
- **保存并分享** — ResultView 合并保存和分享为一键操作

### 技术改进

- **QIM 算法重写** — 使用标准 QIM 公式，提升鲁棒性
- **DCT 两阶段嵌入** — header 用固定 delta，数据用用户指定 delta，解决 delta 协商问题
- **版权元数据格式** — 使用 JSON 格式，{c:creator, y:year, l:license}
```

**Step 2: 提交**

```bash
git add CHANGELOG.md
git commit -m "docs: update changelog for v1.6"
```

---

## 验证清单

- [ ] StegoMode.copyright 枚举值已添加
- [ ] CopyrightInfo 模型可正确解析/序列化 JSON
- [ ] embedCopyright 可嵌入带或不带密钥的版权水印
- [ ] extractCopyright 可提取并解析版权信息
- [ ] detectMode 可正确识别 copyright 模式
- [ ] CopyrightEmbedView 可多选图片批量嵌入
- [ ] CopyrightScanView 相册模式可批量检测
- [ ] CopyrightScanView 摄像头模式可实时扫描
- [ ] HomeView Segmented Picker 可正常切换模块
- [ ] 最近活动正确记录版权嵌入操作
- [ ] Info.plist 包含相机和相册权限描述
- [ ] 编译通过，无错误和警告
- [ ] 端到端测试：嵌入版权 → 保存 → 扫描识别，信息一致
