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
        VStack(spacing: 0) {
            CameraScanContainer(
                onDetected: { info in
                    if !detectedInfos.contains(where: { $0.creator == info.creator && $0.year == info.year }) {
                        var newInfo = info
                        newInfo.detectedAt = Date()
                        DispatchQueue.main.async {
                            self.detectedInfos.append(newInfo)
                        }
                    }
                },
                password: $scanPassword
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 识别结果底部栏
            if !detectedInfos.isEmpty {
                VStack(spacing: 8) {
                    Text("已识别 \(detectedInfos.count) 张版权图片")
                        .font(.caption)
                        .foregroundColor(.green)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(detectedInfos) { info in
                                VStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    Text(info.creator)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .padding(8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }

            // 密码输入
            VStack(spacing: 4) {
                TextField("输入密钥（识别私有版权）", text: $scanPassword)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Text("如果版权图片使用了密钥保护，需要输入才能识别")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
        }
    }

    private func scanSelectedImages() {
        isScanning = true
        detectedInfos = []

        DispatchQueue.global(qos: .userInitiated).async {
            for image in selectedImages {
                if let mode = StegoService.shared.detectMode(from: image), mode == .copyright {
                    do {
                        let info = try StegoService.shared.extractCopyright(from: image, password: scanPassword.isEmpty ? nil : scanPassword)
                        DispatchQueue.main.async {
                            self.detectedInfos.append(info)
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

// MARK: - Camera Scan

struct CameraScanContainer: UIViewControllerRepresentable {
    let onDetected: (CopyrightInfo) -> Void
    @Binding var password: String

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onDetected = onDetected
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
        view.backgroundColor = .black
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
            let info = try StegoService.shared.extractCopyright(from: image, password: password.isEmpty ? nil : password)
            DispatchQueue.main.async { [weak self] in
                self?.onDetected?(info)
            }
        } catch { }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

#Preview {
    CopyrightScanView()
}
