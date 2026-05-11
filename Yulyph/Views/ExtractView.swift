import SwiftUI
import PhotosUI

struct ExtractView: View {
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var decryptionKey = ""
    @State private var isProcessing = false
    @State private var extractedMessage: String?
    @State private var errorMessage: String?
    @State private var showKey = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imagePickerSection
                    keyInputSection
                    actionButtonSection
                    resultSection
                    metadataSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("提取信息")
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
    }
    
    private var imagePickerSection: some View {
        Button {
            showImagePicker = true
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                    .frame(width: 64, height: 64)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(spacing: 4) {
                    Text("上传加密图片")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("拖拽或点击浏览文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button {
                    showImagePicker = true
                } label: {
                    Text("选择文件")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(.systemGray4).opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(.blue.opacity(0.3))
            )
        }
        .overlay(alignment: .bottom) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .cornerRadius(16)
                    .clipped()
            }
        }
    }
    
    private var keyInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundColor(.blue)
                
                Text("安全密钥")
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(.secondary)
            }
            
            ZStack(alignment: .trailing) {
                if showKey {
                    TextField("输入 256位 解密密钥...", text: $decryptionKey)
                        .font(.system(.body, design: .monospaced))
                        .tracking(2)
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .textContentType(.init(rawValue: ""))
                        .keyboardType(.asciiCapable)
                        .disableAutocorrection(true)
                } else {
                    SecureField("输入 256位 解密密钥...", text: $decryptionKey)
                        .font(.system(.body, design: .monospaced))
                        .tracking(2)
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .textContentType(.init(rawValue: ""))
                        .keyboardType(.asciiCapable)
                        .disableAutocorrection(true)
                }
                
                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                        .padding(.trailing, 16)
                }
            }
            
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("密钥仅在本地处理，绝不会存储在我们的服务器上。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }
    
    private var actionButtonSection: some View {
        Button {
            processExtract()
        } label: {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "lock.open.fill")
                }
                
                Text(isProcessing ? "解析中..." : "解析信息")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
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
        .disabled(isProcessing || selectedImage == nil || decryptionKey.isEmpty)
        .opacity((selectedImage == nil || decryptionKey.isEmpty) ? 0.6 : 1)
    }
    
    private var resultSection: some View {
        VStack(spacing: 0) {
            if let message = extractedMessage {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("解密结果")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button {
                            UIPasteboard.general.string = message
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(message)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(16)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Text("等待解密处理...")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .overlay(
                    VStack {
                        Color.blue.opacity(0.2)
                            .frame(height: 4)
                            .cornerRadius(2)
                        Spacer()
                    }
                )
            }
        }
    }
    
    private var metadataSection: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "cpu")
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("引擎")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                        .foregroundColor(.secondary)
                    
                    Text("AES-GCM 256")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("信任评分")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                        .foregroundColor(.secondary)
                    
                    Text("100% 端到端加密")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func processExtract() {
        guard let image = selectedImage, !decryptionKey.isEmpty else {
            return
        }
        
        isProcessing = true
        errorMessage = nil
        extractedMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let extractedData = try StegoService.shared.extract(from: image)
                let encryptedData = FECService.shared.decode(extractedData)
                let decryptedMessage = try CryptoService.shared.decrypt(encryptedData, with: decryptionKey)
                
                DispatchQueue.main.async {
                    self.extractedMessage = decryptedMessage
                    self.isProcessing = false
                    ActivityStore.shared.record(type: .extract, fileName: "Image_\(Int(Date().timeIntervalSince1970))", description: "DCT · \(decryptedMessage.count) chars")
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

#Preview {
    ExtractView()
}