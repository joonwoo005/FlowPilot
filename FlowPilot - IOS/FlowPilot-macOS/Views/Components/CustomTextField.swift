import SwiftUI

// MARK: - Custom Text Field (macOS)
/// A styled text field matching the app's dark design system with focus glow effects

struct CustomTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var label: String? = nil
    var axis: Axis = .horizontal
    var lineLimit: Int = 1
    var accentColor: Color = .accentPrimary
    var icon: String? = nil
    var characterLimit: Int? = nil
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovered: Bool = false

    private var isAtLimit: Bool {
        guard let limit = characterLimit else { return false }
        return text.count >= limit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Optional label
            if let label = label {
                Text(label)
                    .font(Typography.labelMedium)
                    .foregroundColor(.textSecondary)
            }

            // Input container
            HStack(spacing: Spacing.sm) {
                // Optional leading icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isFocused ? accentColor : .textMuted)
                        .animation(.easeOut(duration: 0.2), value: isFocused)
                }

                // Text field
                TextField("", text: $text, axis: axis)
                    .font(Typography.bodyLarge)
                    .foregroundColor(.textPrimary)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .lineLimit(lineLimit)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textMuted)
                    }
                    .onChange(of: text) {
                        if let limit = characterLimit, text.count > limit {
                            text = String(text.prefix(limit))
                            Haptics.impact(.heavy)
                        }
                    }
                    .onSubmit {
                        onSubmit?()
                    }

                // Character count (if limit set)
                if let limit = characterLimit {
                    Text("\(text.count)/\(limit)")
                        .font(Typography.labelSmall)
                        .foregroundColor(isAtLimit ? accentColor : .textMuted)
                        .animation(.easeOut(duration: 0.15), value: isAtLimit)
                }

                // Clear button
                if !text.isEmpty && isFocused {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textMuted)
                        .onTapGesture {
                            Haptics.impact(.light)
                            text = ""
                        }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.base)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(
                                isFocused ? accentColor : (isHovered ? Color.surfaceBorder.opacity(1.5) : Color.surfaceBorder),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isFocused ? accentColor.opacity(0.2) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 0
                    )
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
}

// MARK: - Multiline Variant

struct CustomTextEditor: View {
    @Binding var text: String
    var placeholder: String = ""
    var label: String? = nil
    var minHeight: CGFloat = 80
    var maxHeight: CGFloat = 200
    var accentColor: Color = .accentPrimary
    var characterLimit: Int? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovered: Bool = false

    private var isAtLimit: Bool {
        guard let limit = characterLimit else { return false }
        return text.count >= limit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Optional label
            if let label = label {
                Text(label)
                    .font(Typography.labelMedium)
                    .foregroundColor(.textSecondary)
            }

            // Editor container
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textMuted)
                        .padding(.horizontal, Spacing.base)
                        .padding(.vertical, Spacing.md)
                        .allowsHitTesting(false)
                }

                // Text editor
                TextEditor(text: $text)
                    .font(Typography.bodyLarge)
                    .foregroundColor(.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
                    .onChange(of: text) {
                        if let limit = characterLimit, text.count > limit {
                            text = String(text.prefix(limit))
                            Haptics.impact(.heavy)
                        }
                    }
            }
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(
                                isFocused ? accentColor : (isHovered ? Color.surfaceBorder.opacity(1.5) : Color.surfaceBorder),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isFocused ? accentColor.opacity(0.2) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 0
                    )
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }

            // Character count
            if let limit = characterLimit {
                HStack {
                    Spacer()
                    Text("\(text.count)/\(limit)")
                        .font(Typography.labelSmall)
                        .foregroundColor(isAtLimit ? accentColor : .textMuted)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()

        VStack(spacing: Spacing.xl) {
            CustomTextField(
                text: .constant(""),
                placeholder: "Search tasks...",
                icon: "magnifyingglass"
            )

            CustomTextField(
                text: .constant("Review quarterly report"),
                placeholder: "What do you need to do?",
                label: "Task Name",
                characterLimit: 50
            )

            CustomTextEditor(
                text: .constant(""),
                placeholder: "Add notes...",
                label: "Notes",
                characterLimit: 200
            )
        }
        .padding(Spacing.xl)
        .frame(width: 400)
    }
}
