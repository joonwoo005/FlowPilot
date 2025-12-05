import SwiftUI

// MARK: - Color Palette
// Dark minimal aesthetic with warm neutral accents
extension Color {
    // Backgrounds - deep charcoal with subtle warmth
    static let backgroundPrimary = Color(hex: "0D0D0F")
    static let backgroundSecondary = Color(hex: "141416")
    static let backgroundElevated = Color(hex: "1C1C1F")
    static let backgroundCard = Color(hex: "1F1F23")

    // Surfaces
    static let surfacePrimary = Color(hex: "252528")
    static let surfaceSecondary = Color(hex: "2A2A2E")
    static let surfaceBorder = Color(hex: "333338")

    // Text
    static let textPrimary = Color(hex: "FAFAFA")
    static let textSecondary = Color(hex: "A1A1AA")
    static let textMuted = Color(hex: "71717A")

    // Accents - warm coral as primary, sophisticated highlights
    static let accentPrimary = Color(hex: "FF6B5B")
    static let accentSecondary = Color(hex: "FF8A7A")
    static let accentWarm = Color(hex: "F59E0B")
    static let accentSuccess = Color(hex: "10B981")
    static let accentError = Color(hex: "EF4444")

    // Priority colors - muted, sophisticated
    static let priorityBlue = Color(hex: "3B82F6")
    static let priorityPurple = Color(hex: "8B5CF6")
    static let priorityGreen = Color(hex: "10B981")
    static let priorityOrange = Color(hex: "F59E0B")
    static let priorityPink = Color(hex: "EC4899")
    static let priorityCyan = Color(hex: "06B6D4")
}

// MARK: - Hex Color Initializer
extension Color {
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
