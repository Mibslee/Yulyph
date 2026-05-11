import SwiftUI
import PhotosUI

struct EmbedView: View {
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var secretMessage = ""
    @State private var encryptionKey = ""
    @State private var enableFEC = false
    @State private var stegoMode: StegoMode = .dct
    @State private var strengthIndex: Double = 1  // 默认 .standard
    @State private var isProcessing = false
    @State private var showResult = false
    @State private var resultImage: UIImage?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    imagePickerSection
                    messageInputSection
                    keyInputSection
                    fecToggleSection
                    capacitySection
                    statusSection
                    actionButtonSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("隐藏信息")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .alert("错误", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showResult) {
            ResultView(image: resultImage)
        }
    }
    
    private var topAppBar: some View {
        HStack {
            HStack(spacing: 16) {
                Button {
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.primary)
                }
                
                Text("Yulyph")
                    .font(.headline)
                    .fontWeight(.bold)
                    .kerning(-0.5)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.blue)
                
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemBackground).opacity(0.7))
        .background(.ultraThinMaterial)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("隐藏信息")
                .font(.title)
                .fontWeight(.heavy)
                .kerning(-0.5)
            
            Text("利用先进的隐写术与加密技术，将私人信息安全地嵌入图片元数据中。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var imagePickerSection: some View {
        Button {
            showImagePicker = true
        } label: {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .cornerRadius(16)
                    .clipped()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 4) {
                        Text("选择图片")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("支持 PNG, JPG 或 HEIC")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .foregroundColor(.blue.opacity(0.3))
                )
            }
        }
        .frame(height: 180)
    }
    
    private var messageInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("秘密信息")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $secretMessage)
                    .frame(height: 120)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(.systemGray4).opacity(0.15), lineWidth: 2)
                    )
                
                Text("\(secretMessage.count) / 2048")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
    }
    
    private var keyInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("安全密钥")
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(.secondary)
            }
            
            SecureField("••••••••••••", text: $encryptionKey)
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(.systemGray4).opacity(0.1), lineWidth: 1)
                        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
                )
                .textContentType(.init(rawValue: ""))
                .keyboardType(.asciiCapable)
                .disableAutocorrection(true)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }
    
    private var fecToggleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 嵌入模式选择
            VStack(alignment: .leading, spacing: 10) {
                Text("嵌入模式")
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    modeButton(
                        mode: .dct,
                        icon: "shield.checkered",
                        title: "抗压缩",
                        subtitle: "频域 DCT-QIM"
                    )

                    modeButton(
                        mode: .lsb,
                        icon: "square.stack.3d.up",
                        title: "高容量",
                        subtitle: "空间域 LSB"
                    )
                }

                // 强度滑块（仅 DCT 模式显示）
                if stegoMode == .dct {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("嵌入强度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(StegoService.StrengthLevel(rawValue: UInt8(strengthIndex))?.label ?? "标准")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }

                        Slider(value: $strengthIndex, in: 0...3, step: 1)
                            .accentColor(.blue)

                        HStack {
                            Text("精细")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("最强")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Divider()

            // FEC 开关
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("纠错编码")
                        .font(.caption)
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(.secondary)

                    Text("启用 Reed-Solomon (FEC)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $enableFEC)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)

                Text("推荐")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("容量预览")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            if let image = selectedImage {
                let capacity = StegoService.shared.capacity(for: image, mode: stegoMode)
                let msgDataSize = secretMessage.utf8.count
                let totalNeeded = 9 + (enableFEC ? Int(Double(msgDataSize) * 1.15) : msgDataSize)
                let ratio = min(1.0, CGFloat(totalNeeded) / CGFloat(max(capacity, 1)))
                let isSufficient = totalNeeded <= capacity

                HStack(spacing: 12) {
                    Image(systemName: isSufficient ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isSufficient ? .green : .orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("可用容量")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatBytes(capacity))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isSufficient ? Color.green : Color.orange)
                                    .frame(width: geo.size.width * ratio, height: 8)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("消息大小")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatBytes(totalNeeded))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(isSufficient ? .primary : .orange)
                        }
                    }
                }

                if !isSufficient {
                    Text("图片太小，无法嵌入完整消息。建议使用更大的图片或切换到高容量模式。")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                Text("选择图片后显示容量信息")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    private func modeButton(mode: StegoMode, icon: String, title: String, subtitle: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                stegoMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(stegoMode == mode ? .white : .blue)
                    .frame(width: 36, height: 36)
                    .background(stegoMode == mode ? Color.blue : Color.blue.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(stegoMode == mode ? .primary : .secondary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(stegoMode == mode ? .secondary : .secondary.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(stegoMode == mode ? Color.blue.opacity(0.05) : Color(.systemGray6).opacity(0.5))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(stegoMode == mode ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
    }
    
    private var statusSection: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: 12, height: 12)
                        .blur(radius: 4)
                )
                .shadow(color: .blue.opacity(0.3), radius: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("加密就绪")
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(stegoMode == .dct ? "AES-256 + 频域 DCT-QIM" : "AES-256 + 空域 LSB")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.systemGray4).opacity(0.15), lineWidth: 1)
        )
    }
    
    private var actionButtonSection: some View {
        Button {
            processEmbed()
        } label: {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "lock.doc.fill")
                }
                
                Text(isProcessing ? "处理中..." : "加密并保存")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.2), radius: 10, y: 4)
        }
        .disabled(isProcessing || selectedImage == nil || secretMessage.isEmpty || encryptionKey.isEmpty)
        .opacity((selectedImage == nil || secretMessage.isEmpty || encryptionKey.isEmpty) ? 0.6 : 1)
    }
    
    private func processEmbed() {
        guard let image = selectedImage, !secretMessage.isEmpty, !encryptionKey.isEmpty else {
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let encryptedData = try CryptoService.shared.encrypt(secretMessage, with: encryptionKey)
                let payload = enableFEC ? FECService.shared.encode(encryptedData) : encryptedData
                let embeddedImage = try StegoService.shared.embed(data: payload, into: image, mode: self.stegoMode, strength: StegoService.StrengthLevel(rawValue: UInt8(self.strengthIndex)))
                
                DispatchQueue.main.async {
                    self.resultImage = embeddedImage
                    self.isProcessing = false
                    self.showResult = true
                    ActivityStore.shared.record(type: .embed, fileName: "Image_\(Int(Date().timeIntervalSince1970))", description: "\(self.stegoMode == .dct ? "DCT-QIM" : "LSB") · \(payload.count) bytes")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            // 使用 loadFileRepresentation 获取原始文件数据
            provider.loadFileRepresentation(forTypeIdentifier: "public.image") { url, error in
                if let url = url {
                    // 尝试从原始文件加载
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.parent.image = image
                        }
                    }
                } else {
                    // 回退到标准加载方式
                    self.loadImageFallback(provider: provider)
                }
            }
        }
        
        private func loadImageFallback(provider: NSItemProvider) {
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}


import Photos

class ImageSaver: NSObject {
    var onFinish: ((Bool, String) -> Void)?
    
    func save(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.onFinish?(false, "没有相册访问权限")
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                // 创建一个临时PNG文件
                guard let pngData = image.pngData() else { return }
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("yulyph_temp.png")
                try? pngData.write(to: tempURL)
                
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                request?.creationDate = Date()
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.onFinish?(true, "图片已成功保存到相册")
                    } else {
                        self.onFinish?(false, "保存失败: \(error?.localizedDescription ?? "未知错误")")
                    }
                }
            }
        }
    }
}

struct ResultView: View {
    let image: UIImage?
    @Environment(\.dismiss) var dismiss
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    @State private var imageSaver = ImageSaver()
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(16)
                        .padding()
                    
                    Text("图片已成功加密并嵌入隐藏信息")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("请妥善保管此图片，只有持有正确密钥的人才能提取隐藏信息。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Button {
                    saveAndShare()
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
                
                Button {
                    exportAsPNG()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("导出PNG文件")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Button {
                    shareAsPNG()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享PNG图片")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("提示", isPresented: $showSaveAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(saveMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }
    
    private func saveAndShare() {
        guard let image = image,
              let pngData = image.pngData() else {
            saveMessage = "无法生成图片数据"
            showSaveAlert = true
            return
        }

        let fileName = "Yulyph_Encrypted_\(Int(Date().timeIntervalSince1970)).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: tempURL)

            // 先保存到相册
            imageSaver.onFinish = { [self] success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.shareItems = [tempURL]
                        self.showShareSheet = true
                    } else {
                        self.shareItems = [tempURL]
                        self.showShareSheet = true
                    }
                }
            }
            imageSaver.save(image: image)
        } catch {
            saveMessage = "操作失败: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }

    private func saveImage() {
        guard let image = image else {
            saveMessage = "图片不存在"
            showSaveAlert = true
            return
        }
        
        imageSaver.onFinish = { success, message in
            DispatchQueue.main.async {
                self.saveMessage = message
                self.showSaveAlert = true
            }
        }
        imageSaver.save(image: image)
    }
    
    private func exportAsPNG() {
        guard let image = image,
              let pngData = image.pngData() else {
            saveMessage = "无法生成PNG数据"
            showSaveAlert = true
            return
        }
        
        let fileName = "Yulyph_Encrypted_\(Int(Date().timeIntervalSince1970)).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {
            saveMessage = "导出失败: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }
    
    private func shareAsPNG() {
        guard let image = image,
              let pngData = image.pngData() else {
            saveMessage = "无法生成PNG数据"
            showSaveAlert = true
            return
        }

        let fileName = "Yulyph_Encrypted_\(Int(Date().timeIntervalSince1970)).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {
            saveMessage = "分享失败: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    EmbedView()
}