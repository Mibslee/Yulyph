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
    @State private var shareState: ShareState = .idle

    enum ShareState {
        case idle
        case sharing
        case success
        case error(String)

        var isIdle: Bool { if case .idle = self { return true }; return false }
        var isSharing: Bool { if case .sharing = self { return true }; return false }
        var isSuccess: Bool { if case .success = self { return true }; return false }
        var isError: Bool { if case .error = self { return true }; return false }

        var errorMessage: String? {
            if case .error(let msg) = self { return msg }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
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
                                if shareState.isSharing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("保存并分享")
                                }
                            }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(shareState.isIdle ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .disabled(shareState.isSharing)
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding(.top, 40)
                }

                if case .idle = shareState {} else if case .sharing = shareState {} else {
                    shareToast
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheetWithCompletion(items: shareItems) { success in
                    if success {
                        shareState = .success
                    } else {
                        shareState = .error("分享被取消")
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if shareState.isSuccess || shareState.isError {
                            shareState = .idle
                        }
                    }
                }
            }
        }
    }

    private var shareToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                if case .success = shareState {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已保存并分享")
                } else if shareState.isError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text(shareState.errorMessage ?? "分享失败")
                } else {
                    EmptyView()
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.bottom, 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(duration: 0.3), value: shareState.isError)
    }

    private func exportAndShare() {
        shareState = .sharing

        var pngDatas: [Data] = []
        for image in images {
            if let pngData = image.pngData() {
                pngDatas.append(pngData)
            }
        }

        guard !pngDatas.isEmpty else {
            shareState = .error("图片处理失败")
            scheduleReset()
            return
        }

        if pngDatas.count == 1 {
            let fileName = "Yulyph_Copyright_\(Int(Date().timeIntervalSince1970)).png"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try pngDatas[0].write(to: tempURL)
                shareItems = [tempURL]
                showShareSheet = true
            } catch {
                shareState = .error("保存失败")
                scheduleReset()
            }
        } else {
            var shareImages: [UIImage] = []
            for data in pngDatas {
                if let img = UIImage(data: data) {
                    shareImages.append(img)
                }
            }
            guard !shareImages.isEmpty else {
                shareState = .error("图片处理失败")
                scheduleReset()
                return
            }

            let activityVC = UIActivityViewController(activityItems: shareImages, applicationActivities: nil)
            activityVC.completionWithItemsHandler = { _, success, _, _ in
                DispatchQueue.main.async {
                    self.shareState = success ? .success : .error("分享被取消")
                    self.scheduleReset()
                }
            }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true) {
                    // Dismissal happens via completion handler
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.shareState.isSharing {
                            self.shareState = .idle
                        }
                    }
                }
            } else {
                shareState = .error("无法打开分享界面")
                scheduleReset()
            }
        }
    }

    private func scheduleReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if !self.shareState.isIdle && !self.shareState.isSharing {
                self.shareState = .idle
            }
        }
    }
}

// MARK: - ShareSheet with completion

struct ShareSheetWithCompletion: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, success, _, _ in
            onComplete(success)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CopyrightEmbedView()
}
