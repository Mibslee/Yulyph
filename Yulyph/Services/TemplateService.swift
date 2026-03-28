import UIKit
import SwiftUI

enum TemplateStyle: String, Hashable {
    case xiaohongshu  // 小红书风格：大字海报
    case frame        // 相框风格：图片+白框+logo
}

enum XiaohongshuColor: String, CaseIterable {
    case orangePink = "橙粉渐变"
    case bluePurple = "蓝紫渐变"
    case greenTeal = "绿青渐变"
    case redOrange = "红橙渐变"
    case purplePink = "紫粉渐变"
    
    var colors: [UIColor] {
        switch self {
        case .orangePink: return [.systemOrange, .systemPink]
        case .bluePurple: return [.systemBlue, .systemPurple]
        case .greenTeal: return [.systemGreen, .systemTeal]
        case .redOrange: return [.systemRed, .orange]
        case .purplePink: return [.systemPurple, .systemPink]
        }
    }
}

struct TemplateItem: Identifiable, Hashable {
    let id = UUID()
    let imageName: String
    let title: String
    let category: String
    let description: String
    let style: TemplateStyle
    var colorOptions: [XiaohongshuColor] = []
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TemplateItem, rhs: TemplateItem) -> Bool {
        lhs.id == rhs.id
    }
    
    static let sampleTemplates = [
        TemplateItem(
            imageName: "template_xiaohongshu",
            title: "小红书风格",
            category: "社交媒体",
            description: "鲜艳色彩，大字标题，适合小红书分享",
            style: .xiaohongshu,
            colorOptions: XiaohongshuColor.allCases
        ),
        TemplateItem(
            imageName: "template_frame",
            title: "简约相框",
            category: "相框",
            description: "白色相框，简约风格，右下角显示品牌logo",
            style: .frame
        )
    ]
}
