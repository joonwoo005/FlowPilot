import SwiftUI

struct TextInputField: View {
    let placeholder: String
    @Binding var text: String
    var isLarge: Bool = false
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField("", text: $text)
                .font(isLarge ? Typography.headlineLarge : Typography.bodyLarge)
                .foregroundColor(.textPrimary)
                .focused($isFocused)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .font(isLarge ? Typography.headlineLarge : Typography.bodyLarge)
                        .foregroundColor(.textMuted)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, isLarge ? Spacing.lg : Spacing.base)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(
                                    isFocused ? Color.accentPrimary : Color.surfaceBorder,
                                    lineWidth: isFocused ? 2 : 1
                                )
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isFocused = false
                }
                .font(Typography.labelLarge)
                .foregroundColor(.accentPrimary)
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var text = ""
        @FocusState var focused: Bool

        var body: some View {
            VStack(spacing: 20) {
                TextInputField(
                    placeholder: "Enter your name",
                    text: $text,
                    isFocused: $focused
                )

                TextInputField(
                    placeholder: "Large input",
                    text: $text,
                    isLarge: true,
                    isFocused: $focused
                )
            }
            .padding()
            .background(Color.backgroundPrimary)
        }
    }

    return PreviewWrapper()
}
