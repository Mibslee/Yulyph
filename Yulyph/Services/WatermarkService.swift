import UIKit

class WatermarkService {
    static let shared = WatermarkService()
    
    private init() {}
    
    func addWatermark(to image: UIImage, text: String = "Yulyph", opacity: CGFloat = 0.3) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: image.size.width * 0.03, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(opacity)
            ]
            
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedString.size()
            
            let x = image.size.width - textSize.width - 20
            let y = image.size.height - textSize.height - 20
            
            attributedString.draw(at: CGPoint(x: x, y: y))
        }
    }
    
    func addLogoWatermark(to image: UIImage, logoSize: CGFloat = 50, opacity: CGFloat = 0.3) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let logoRect = CGRect(
                x: image.size.width - logoSize - 20,
                y: image.size.height - logoSize - 20,
                width: logoSize,
                height: logoSize
            )
            
            let logoImage = createLogoImage(size: CGSize(width: logoSize, height: logoSize))
            logoImage.draw(in: logoRect, blendMode: .normal, alpha: opacity)
        }
    }
    
    private func createLogoImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            ctx.setFillColor(UIColor.white.cgColor)
            
            let centerX = size.width / 2
            let centerY = size.height / 2
            let radius = min(size.width, size.height) * 0.4
            
            ctx.addArc(center: CGPoint(x: centerX, y: centerY), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            ctx.fillPath()
            
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: radius * 0.8, weight: .bold),
                .foregroundColor: UIColor.blue
            ]
            
            let text = "Y"
            let attributedText = NSAttributedString(string: text, attributes: textAttributes)
            let textSize = attributedText.size()
            
            let textRect = CGRect(
                x: centerX - textSize.width / 2,
                y: centerY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            attributedText.draw(in: textRect)
        }
    }
}