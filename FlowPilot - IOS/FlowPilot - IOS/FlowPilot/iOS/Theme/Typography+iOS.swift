import SwiftUI

// MARK: - Typography (iOS)
// Using SF Pro with careful weight selection for hierarchy
// Optimized for mobile touch interfaces
struct Typography {
    // Display - for hero moments
    static let displayLarge = Font.system(size: 40, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 32, weight: .bold, design: .default)

    // Headlines
    static let headlineLarge = Font.system(size: 28, weight: .semibold, design: .default)
    static let headlineMedium = Font.system(size: 24, weight: .semibold, design: .default)
    static let headlineSmall = Font.system(size: 20, weight: .semibold, design: .default)

    // Body
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // Labels
    static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)

    // Monospace for numbers/time
    static let mono = Font.system(size: 17, weight: .medium, design: .monospaced)
    static let monoLarge = Font.system(size: 24, weight: .semibold, design: .monospaced)
}
