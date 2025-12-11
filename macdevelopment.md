# macOS Development Notes

## Project Structure

The macOS version is located at:
```
FlowPilot - IOS/FlowPilot-macOS/
```

**Important**: This folder is OUTSIDE the synchronized group (`FlowPilot - IOS/FlowPilot - IOS/`) to avoid build conflicts with iOS files.

## Key Differences from iOS

| Aspect | iOS | macOS |
|--------|-----|-------|
| Navigation | TabView (bottom tabs) | NavigationSplitView (sidebar) |
| Entry Point | FlowPilotiOSApp.swift | FlowPilotmacOSApp.swift |
| Typography | Typography+iOS.swift | Typography+macOS.swift |
| Target | iOS 17+ | macOS 14+ |

## Platform-Specific Code Patterns

### UIKit vs AppKit
When using platform-specific APIs, use conditional compilation:

```swift
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIColor = NSColor
#endif
```

### Google Sign-In Presentation
```swift
#if canImport(UIKit)
guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let rootViewController = windowScene.windows.first?.rootViewController else {
    throw AuthError.presentationError("No root view controller found")
}
let presentingController = rootViewController
#elseif canImport(AppKit)
guard let window = NSApplication.shared.keyWindow else {
    throw AuthError.presentationError("No key window found")
}
let presentingController = window
#endif
```

## Required Capabilities (Signing & Capabilities)

1. **App Sandbox** - with "Outgoing Connections (Client)" enabled
2. **Keychain Sharing** - for Firebase authentication

## Common Build Fixes

### Models Used in Pickers
Models used with SwiftUI Picker must conform to `Hashable`:
```swift
struct TimeBlock: Identifiable, Equatable, Hashable { ... }
```

### Views Not Filling Window
Add frame modifier to views:
```swift
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

### Views Exceeding Window Size
Wrap content in ScrollView or resize fixed-size elements:
```swift
ScrollView(showsIndicators: false) {
    VStack(spacing: 0) {
        // Content here
    }
}
```

### Duplicate Type Declarations
If iOS and macOS have views with same struct names, rename one:
```swift
// In SettingsView.swift (macOS)
struct SettingsAddPrioritySheet: View { ... }  // Not AddPrioritySheet
```

## Xcode Target Setup

1. Create new macOS target: **File → New → Target → macOS → App**
2. Add `FlowPilot-macOS` folder to project (only to macOS target)
3. Add `Shared` folder files to macOS target's **Build Phases → Compile Sources**
4. Add `GoogleService-Info.plist` to macOS target membership
5. Add required frameworks: FirebaseAuth, FirebaseCore, FirebaseFirestore, GoogleSignIn

## Files Modified for Cross-Platform Support

- `Shared/Services/AuthService.swift` - Platform conditionals for Google Sign-In
- `Shared/Services/CalendarService.swift` - UIColor/NSColor compatibility
- `Shared/Models/Domain/TimeBlock.swift` - Added Hashable conformance

## Design Guidelines

- Use `.frame(maxWidth: .infinity, maxHeight: .infinity)` on root views
- Wrap potentially long content in ScrollView
- Keep form content at reasonable max widths (400-600px) for readability
- Use macOS-appropriate controls (DatePicker with `.field` style, etc.)
