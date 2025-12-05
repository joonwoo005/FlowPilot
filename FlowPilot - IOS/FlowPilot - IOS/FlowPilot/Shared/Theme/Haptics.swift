import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Haptics
// Cross-platform haptic feedback
struct Haptics {
    static func impact(_ style: HapticStyle = .medium) {
        #if os(iOS)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .medium:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        }
        generator.impactOccurred()
        #elseif os(macOS)
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch style {
        case .light:
            performer.perform(.alignment, performanceTime: .default)
        case .medium:
            performer.perform(.generic, performanceTime: .default)
        case .heavy:
            performer.perform(.levelChange, performanceTime: .default)
        }
        #endif
    }

    static func notification(_ type: NotificationType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .warning:
            generator.notificationOccurred(.warning)
        case .error:
            generator.notificationOccurred(.error)
        }
        #elseif os(macOS)
        // macOS doesn't have notification haptics, use generic
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }

    static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #endif
    }

    enum HapticStyle {
        case light
        case medium
        case heavy
    }

    enum NotificationType {
        case success
        case warning
        case error
    }
}
