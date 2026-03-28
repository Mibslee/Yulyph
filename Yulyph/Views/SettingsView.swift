import SwiftUI

struct SettingsView: View {
    @State private var enableWatermark = true
    @State private var watermarkText = "Yulyph"
    @State private var enableFECByDefault = true
    @State private var selectedLanguage = "中文"
    let languages = ["中文", "English"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                watermarkSection
                defaultSettingsSection
                languageSection
                aboutSection
                dangerZoneSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 100)
            .padding(.bottom, 100)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            topAppBar
        }
        .overlay(alignment: .bottom) {
            bottomNavBar
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
                
                Text("设置")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemBackground).opacity(0.7))
        .background(.ultraThinMaterial)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .frame(width: 80, height: 80)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            Text("应用设置")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("自定义您的 Yulyph 使用体验")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private var watermarkSection: some View {
        SettingsSection(title: "水印设置", icon: "signature") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "启用水印",
                    description: "在导出的图片上添加软件水印",
                    isOn: $enableWatermark
                )
                
                if enableWatermark {
                    Divider()
                    
                    HStack {
                        Text("水印文字")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        TextField("水印文字", text: $watermarkText)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private var defaultSettingsSection: some View {
        SettingsSection(title: "默认设置", icon: "slider.horizontal.3") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "默认启用 FEC 纠错",
                    description: "Reed-Solomon 纠错码可提高数据恢复率",
                    isOn: $enableFECByDefault
                )
                
                Divider()
                
                NavigationLink {
                    Text("加密强度设置")
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("加密强度")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text("AES-256-GCM (推荐)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var languageSection: some View {
        SettingsSection(title: "语言", icon: "globe") {
            HStack {
                Text("应用语言")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("语言", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: "关于", icon: "info.circle") {
            VStack(spacing: 12) {
                HStack {
                    Text("版本")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Divider()
                
                NavigationLink {
                    Text("隐私政策")
                } label: {
                    HStack {
                        Text("隐私政策")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                NavigationLink {
                    Text("使用条款")
                } label: {
                    HStack {
                        Text("使用条款")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var dangerZoneSection: some View {
        SettingsSection(title: "数据管理", icon: "exclamationmark.triangle") {
            VStack(spacing: 12) {
                Button {
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        
                        Text("清除所有历史记录")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                Button {
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.orange)
                        
                        Text("重置所有设置")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var bottomNavBar: some View {
        HStack {
            navBarItem(icon: "house", label: "首页", isActive: false)
            Spacer()
            navBarItem(icon: "paintbrush", label: "工具", isActive: false)
            Spacer()
            navBarItem(icon: "photo.stack", label: "库", isActive: false)
            Spacer()
            navBarItem(icon: "gearshape.fill", label: "设置", isActive: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .padding(.bottom, 16)
        .background(Color(.systemBackground).opacity(0.7))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
    
    private func navBarItem(icon: String, label: String, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(isActive ? .blue : .secondary)
            
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundColor(isActive ? .blue : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(12)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(.secondary)
            }
            
            content
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 20, y: 4)
    }
}

struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
}

#Preview {
    SettingsView()
}