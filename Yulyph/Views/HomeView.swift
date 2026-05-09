import SwiftUI

struct HomeView: View {
    @State private var recentActivities: [ActivityItem] = []
    @State private var heroAppeared = false
    @State private var cardsAppeared = false

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

    private var quickActionSection: some View {
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

    private var tipOfTheDaySection: some View {
        HStack(spacing: 14) {
            Image(systemName: "lightbulb.fill")
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.2)))

            VStack(alignment: .leading, spacing: 4) {
                Text("每日小贴士")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.75))

                Text("隐藏数据时请使用高分辨率 PNG 图片，以防压缩导致数据损坏。")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(18)
        .background(ThemeGradient.tipCard)
        .cornerRadius(20)
        .shadow(color: Color(hex: "0070eb").opacity(0.15), radius: 12, y: 4)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近活动")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary)

            if recentActivities.isEmpty {
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
