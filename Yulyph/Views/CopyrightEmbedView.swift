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
                Text(StegoService.StrengthLevel(rawValue: UInt8(strengthIndex))?.label ?? "标准")
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
        .padding(.horizontal, 20)
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

// MARK: - MultiImagePicker

struct MultiImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 20
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
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

// MARK: - CopyrightResultView

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
        } catch { }
    }
}

#Preview {
    CopyrightEmbedView()
}
