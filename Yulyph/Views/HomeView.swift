import SwiftUI

struct HomeView: View {
    @State private var recentActivities: [ActivityItem] = []
    
    private var appName: String {
        Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
        ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
        ?? "Yulyph"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    quickActionSection
                    templateSection
                    tipOfTheDaySection
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
        }
    }
    
    private var topAppBar: some View {
        HStack {
            HStack(spacing: 12) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                
                Text(appName)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.9))
        .background(.ultraThinMaterial)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("您的数字避风港")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("安全加密，隐藏信息于无形")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var quickActionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("核心功能")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                NavigationLink {
                    EmbedView()
                } label: {
                    actionCard(
                        icon: "eye.slash.fill",
                        iconColor: .blue,
                        title: "隐藏信息",
                        subtitle: "将秘密嵌入图片"
                    )
                }
                
                NavigationLink {
                    ExtractView()
                } label: {
                    actionCard(
                        icon: "lock.open.fill",
                        iconColor: .orange,
                        title: "提取信息",
                        subtitle: "解析隐藏数据"
                    )
                }
            }
        }
    }
    
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("创意模版")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            NavigationLink {
                TemplateLibraryView()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 48, height: 48)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("模版库")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("创建精美的海报和相框")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
        }
    }
    
    private func actionCard(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 48, height: 48)
                .background(iconColor.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var tipOfTheDaySection: some View {
        HStack(spacing: 16) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.orange)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("每日小贴士")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("隐藏数据时请使用高分辨率 PNG 图片，以防压缩导致数据损坏。")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近活动")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            if recentActivities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("暂无活动记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("开始使用隐藏或提取功能后，活动将显示在这里")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
        }
    }
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let fileName: String
    let type: ActivityType
    let description: String
    let date: Date
    
    enum ActivityType {
        case embed
        case extract
    }
}

#Preview {
    HomeView()
}
