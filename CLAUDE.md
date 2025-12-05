# FlowPilot - Project Instructions

## Overview
FlowPilot is a time blocking + task management app built with SwiftUI, supporting both iOS and macOS with different UIs from a single codebase.

## Multi-Platform Architecture

This project uses a **"Shared Core + Platform Shells"** pattern.

### Folder Structure
```
FlowPilot/
├── Shared/           # Shared across all platforms (both targets)
│   ├── Models/       # Domain models and state objects
│   ├── ViewModels/   # Platform-agnostic business logic
│   ├── Services/     # Repositories, sync, etc.
│   └── Theme/        # Colors, Spacing, CornerRadius, Haptics
│
├── iOS/              # iOS target only
│   ├── App/          # FlowPilotiOSApp.swift entry point
│   ├── Theme/        # Typography+iOS.swift
│   ├── Views/        # All iOS views (Components, Onboarding, etc.)
│   └── Navigation/   # MainTabView (tab-based navigation)
│
├── macOS/            # macOS target only
│   ├── App/          # FlowPilotmacOSApp.swift entry point
│   ├── Theme/        # Typography+macOS.swift
│   ├── Views/        # All macOS views (Main, Onboarding, Settings)
│   └── MenuBar/      # Menu bar extra (future)
```

### Key Patterns

1. **Shared ViewModels**: All business logic lives in `Shared/ViewModels/`. Platform Views consume these via `@StateObject` or `@ObservedObject`.

2. **Platform Entry Points**:
   - iOS: `iOS/App/FlowPilotiOSApp.swift`
   - macOS: `macOS/App/FlowPilotmacOSApp.swift`

3. **Theme Extensions**:
   - Shared: Colors, Spacing, CornerRadius (identical on both platforms)
   - Platform-specific: Typography (different sizes for mobile vs desktop)

4. **Navigation**:
   - iOS: `TabView` (tabs at bottom)
   - macOS: `NavigationSplitView` (sidebar + detail)

### Adding New Features

1. Create ViewModel in `Shared/ViewModels/`
2. Create iOS View in `iOS/Views/`
3. Create macOS View in `macOS/Views/`
4. Both Views use the same ViewModel

### Xcode Target Configuration

- **FlowPilot iOS**: iOS 17+, includes `Shared/` and `iOS/` folders
- **FlowPilot macOS**: macOS 14+, includes `Shared/` and `macOS/` folders

When adding new files:
- `Shared/` files → Add to BOTH targets
- `iOS/` files → iOS target only
- `macOS/` files → macOS target only

## Development Guidelines

- Use SwiftUI for all UI
- Follow the dark minimal aesthetic defined in `Shared/Theme/Colors.swift`
- Use `Haptics.impact()` for haptic feedback (works on both platforms)
- Always use the design system tokens (Typography, Spacing, CornerRadius, Colors)
- No need to build to test.
- Remember to update the correct file within the xcode project.