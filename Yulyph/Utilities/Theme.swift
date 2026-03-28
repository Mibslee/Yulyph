import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let primaryBlue = Color(hex: "0058bc")
    static let primaryContainer = Color(hex: "0070eb")
    static let onPrimary = Color.white
    static let onPrimaryContainer = Color(hex: "fefcff")
    static let primaryFixed = Color(hex: "d8e2ff")
    static let primaryFixedDim = Color(hex: "adc6ff")
    
    // MARK: - Secondary Colors
    static let secondary = Color(hex: "405e96")
    static let secondaryContainer = Color(hex: "a1befd")
    static let onSecondary = Color.white
    static let onSecondaryContainer = Color(hex: "2d4c83")
    static let secondaryFixed = Color(hex: "d8e2ff")
    static let secondaryFixedDim = Color(hex: "adc6ff")
    
    // MARK: - Tertiary Colors
    static let tertiary = Color(hex: "9e3d00")
    static let tertiaryContainer = Color(hex: "c64f00")
    static let onTertiary = Color.white
    static let onTertiaryContainer = Color(hex: "fffbff")
    static let tertiaryFixed = Color(hex: "ffdbcc")
    static let tertiaryFixedDim = Color(hex: "ffb595")
    
    // MARK: - Error Colors
    static let error = Color(hex: "ba1a1a")
    static let errorContainer = Color(hex: "ffdad6")
    static let onError = Color.white
    static let onErrorContainer = Color(hex: "93000a")
    
    // MARK: - Surface Colors
    static let surface = Color(hex: "f9f9fe")
    static let surfaceDim = Color(hex: "d9dade")
    static let surfaceBright = Color(hex: "f9f9fe")
    static let surfaceContainerLowest = Color.white
    static let surfaceContainerLow = Color(hex: "f3f3f8")
    static let surfaceContainer = Color(hex: "ededf2")
    static let surfaceContainerHigh = Color(hex: "e8e8ed")
    static let surfaceContainerHighest = Color(hex: "e2e2e7")
    static let surfaceVariant = Color(hex: "e2e2e7")
    
    // MARK: - Text Colors
    static let onSurface = Color(hex: "1a1c1f")
    static let onSurfaceVariant = Color(hex: "414755")
    static let onBackground = Color(hex: "1a1c1f")
    
    // MARK: - Outline Colors
    static let outline = Color(hex: "717786")
    static let outlineVariant = Color(hex: "c1c6d7")
    
    // MARK: - Inverse Colors
    static let inverseSurface = Color(hex: "2e3034")
    static let inverseOnSurface = Color(hex: "f0f0f5")
    static let inversePrimary = Color(hex: "adc6ff")
    
    // MARK: - Other
    static let background = Color(hex: "f9f9fe")
    static let surfaceTint = Color(hex: "005bc1")
    
    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension ShapeStyle where Self == Color {
    static var primaryBlue: Color { .primaryBlue }
    static var primaryContainer: Color { .primaryContainer }
    static var tertiary: Color { .tertiary }
    static var surface: Color { .surface }
    static var surfaceContainerLow: Color { .surfaceContainerLow }
    static var surfaceContainerLowest: Color { .surfaceContainerLowest }
    static var onSurface: Color { .onSurface }
    static var onSurfaceVariant: Color { .onSurfaceVariant }
}