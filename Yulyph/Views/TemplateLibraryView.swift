import SwiftUI
import PhotosUI

struct TemplateLibraryView: View {
    @State private var selectedCategory = "全部模版"
    let categories = ["全部模版", "社交媒体", "相框"]
    
    var filteredTemplates: [TemplateItem] {
        if selectedCategory == "全部模版" {
            return TemplateItem.sampleTemplates
        }
        return TemplateItem.sampleTemplates.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                categorySection
                templateGridSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemBackground))
        .navigationTitle("模版库")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择模版，创建精美内容")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.subheadline)
                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? Color.blue : Color(.systemGray6))
                            .cornerRadius(20)
                    }
                }
            }
        }
    }
    
    private var templateGridSection: some View {
        VStack(spacing: 24) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(filteredTemplates) { template in
                    NavigationLink {
                        TemplateEditorView(template: template)
                    } label: {
                        TemplateCardView(template: template)
                    }
                }
            }
            
            // 更多模版提示
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text("更多模版，敬请期待")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("我们正在努力开发更多精美模版")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Template Card
struct TemplateCardView: View {
    let template: TemplateItem
    
    private var appName: String {
        Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
        ?? "Yulyph"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                templateBackground
                
                if template.style == .xiaohongshu {
                    VStack(spacing: 6) {
                        Text("momo")
                            .font(.system(size: 32, weight: .heavy))
                        Text("你来了")
                            .font(.system(size: 24, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if template.style == .frame {
                    // 相框样式：logo在右下角
                    HStack(spacing: 3) {
                        Image("logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                        Text(appName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(red: 0.8, green: 0.65, blue: 0.2))
                    }
                    .padding(6)
                }
            }
            .aspectRatio(3/4, contentMode: .fit)
            .cornerRadius(12)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(template.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var templateBackground: some View {
        switch template.style {
        case .xiaohongshu:
            LinearGradient(
                colors: [.orange, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .frame:
            // 相框预览：风景照片+明显白边
            ZStack {
                // 浅灰色背景，让白色相框更明显
                Color(.systemGray5)
                
                // 白色相框
                Color.white
                    .padding(8)
                
                // 模拟风景照片（更真实的渐变）
                VStack(spacing: 0) {
                    // 天空
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.7, blue: 0.9),
                            Color(red: 0.6, green: 0.85, blue: 0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // 山脉
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 0) {
                            // 远山
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 50))
                                path.addLine(to: CGPoint(x: 30, y: 15))
                                path.addLine(to: CGPoint(x: 60, y: 35))
                                path.addLine(to: CGPoint(x: 90, y: 10))
                                path.addLine(to: CGPoint(x: 120, y: 30))
                                path.addLine(to: CGPoint(x: 120, y: 50))
                                path.closeSubpath()
                            }
                            .fill(Color(red: 0.5, green: 0.6, blue: 0.7))
                            
                            Spacer()
                        }
                        .frame(height: 50)
                        .padding(.bottom, 20)
                    }
                    // 草地
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.6, blue: 0.3),
                            Color(red: 0.4, green: 0.7, blue: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 30)
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Template Editor
struct TemplateEditorView: View {
    let template: TemplateItem
    @State private var inputText = ""
    @State private var selectedImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var generatedImage: UIImage?
    @State private var selectedColor: XiaohongshuColor = .orangePink
    @State private var showImagePicker = false
    @State private var showShareSheet = false
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    @Environment(\.dismiss) var dismiss
    
    var needImage: Bool {
        template.style == .frame
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                previewSection
                if template.style == .xiaohongshu {
                    colorPickerSection
                }
                inputSection
                actionButtons
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle(template.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if generatedImage != nil {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = generatedImage {
                ShareSheet(items: [image])
            }
        }
        .alert("提示", isPresented: $showSaveAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(saveMessage)
        }
        .onChange(of: inputText) { _ in
            updatePreview()
        }
        .onChange(of: selectedImage) { _ in
            updatePreview()
        }
        .onChange(of: selectedColor) { _ in
            updatePreview()
        }
    }
    
    private var previewSection: some View {
        ZStack {
            if let image = generatedImage ?? previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(3/4, contentMode: .fit)
                    .cornerRadius(16)
                    .shadow(radius: 8)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(gradientForStyle(template.style))
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        if needImage {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("点击下方选择图片")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        } else {
                            Text("输入文字预览")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    }
            }
        }
    }
    
    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择颜色")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(template.colorOptions, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            VStack(spacing: 4) {
                                LinearGradient(
                                    colors: color.colors.map { Color($0) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(width: 50, height: 50)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 3)
                                )
                                
                                Text(color.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 12) {
            if needImage {
                Button {
                    showImagePicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo")
                        Text(selectedImage == nil ? "选择图片" : "更换图片")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            
            if !needImage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("输入文字")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("支持换行")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 100, maxHeight: 150)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if inputText.isEmpty {
                                Text("在此输入...")
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.leading, 12)
                                    .padding(.top, 16)
                            }
                        }
                }
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                generateImage()
            } label: {
                Text("生成图片")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canGenerate ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!canGenerate)
            
            if generatedImage != nil {
                Button {
                    saveToAlbum()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("保存到相册")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var canGenerate: Bool {
        if needImage {
            return selectedImage != nil
        }
        return !inputText.isEmpty
    }
    
    private func gradientForStyle(_ style: TemplateStyle) -> LinearGradient {
        switch style {
        case .xiaohongshu:
            return LinearGradient(
                colors: selectedColor.colors.map { Color($0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .frame:
            return LinearGradient(colors: [.gray.opacity(0.2), .gray.opacity(0.1)], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private func updatePreview() {
        guard !needImage else {
            if let image = selectedImage {
                previewImage = renderImage(text: "", image: image, includeWatermark: false)
            } else {
                previewImage = nil
            }
            return
        }
        
        guard !inputText.isEmpty else {
            previewImage = nil
            return
        }
        
        previewImage = renderImage(text: inputText, image: nil, includeWatermark: false)
    }
    
    private func generateImage() {
        if needImage, let image = selectedImage {
            generatedImage = renderImage(text: "", image: image, includeWatermark: true)
        } else {
            generatedImage = renderImage(text: inputText, image: nil, includeWatermark: true)
        }
    }
    
    private func renderImage(text: String, image: UIImage?, includeWatermark: Bool) -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            switch template.style {
            case .xiaohongshu:
                let colors = selectedColor.colors.map { $0.cgColor }
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
                ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                drawText(text, fontSize: 160, in: ctx, size: size, watermark: includeWatermark)
                
            case .frame:
                if let img = image {
                    drawFrameImage(img, in: ctx, size: size, watermark: includeWatermark)
                }
            }
        }
    }
    
    private func drawText(_ text: String, fontSize: CGFloat, in ctx: CGContext, size: CGSize, watermark: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // 计算文字实际需要的高度
        let maxWidth = size.width - 120
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        // 垂直居中绘制
        let textY = (size.height - boundingRect.height) / 2
        let textRect = CGRect(x: 60, y: textY, width: maxWidth, height: boundingRect.height + 100)
        attributedString.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        if watermark {
            drawWatermark(in: ctx, size: size)
        }
    }
    
    private func drawFrameImage(_ image: UIImage, in ctx: CGContext, size: CGSize, watermark: Bool) {
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        
        let padding: CGFloat = 60
        let imageRect = CGRect(x: padding, y: padding, width: size.width - padding * 2, height: size.height - padding * 2 - 80)
        
        if let cgImage = image.cgImage {
            ctx.saveGState()
            
            // 翻转坐标系以修正图片方向
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
            
            let flippedRect = CGRect(
                x: padding,
                y: size.height - imageRect.maxY,
                width: imageRect.width,
                height: imageRect.height
            )
            
            ctx.draw(cgImage, in: flippedRect)
            ctx.restoreGState()
        }
        
        // 在右下角添加logo和文字
        drawLogoAndText(in: ctx, size: size)
    }
    
    private func drawLogoAndText(in ctx: CGContext, size: CGSize) {
        // 获取应用名称
        let appName = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? "Yulyph"
        
        // 绘制logo图片（增大一倍）
        if let logoImage = UIImage(named: "logo"),
           let logoCGImage = logoImage.cgImage {
            let logoSize: CGFloat = 80  // 从40增大到80
            let logoX = size.width - 380  // 调整位置
            let logoY: CGFloat = size.height - 110  // 调整位置
            
            let logoRect = CGRect(x: logoX, y: logoY, width: logoSize, height: logoSize)
            ctx.draw(logoCGImage, in: logoRect)
            
            // 绘制金色文字（增大一倍）
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .medium),  // 从24增大到48
                .foregroundColor: UIColor(red: 0.8, green: 0.65, blue: 0.2, alpha: 1.0) // 金色
            ]
            let text = NSAttributedString(string: appName, attributes: textAttrs)
            text.draw(at: CGPoint(x: logoX + logoSize + 12, y: logoY + 16))  // 调整文字位置
        }
    }
    
    private func drawWatermark(in ctx: CGContext, size: CGSize) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ]
        let watermark = NSAttributedString(string: "聿符 Yulyph", attributes: attrs)
        watermark.draw(at: CGPoint(x: size.width - 150, y: size.height - 45))
    }
    
    private func saveToAlbum() {
        guard let image = generatedImage else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.saveMessage = "没有相册访问权限"
                    self.showSaveAlert = true
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                guard let pngData = image.pngData() else { return }
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("yulyph_template.png")
                try? pngData.write(to: tempURL)
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.saveMessage = "图片已保存到相册"
                    } else {
                        self.saveMessage = "保存失败: \(error?.localizedDescription ?? "未知错误")"
                    }
                    self.showSaveAlert = true
                }
            }
        }
    }
}
