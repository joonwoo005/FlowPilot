import SwiftUI

// MARK: - Custom Picker (macOS)
/// A styled dropdown picker with dark theme styling

struct CustomPicker<T: Hashable, Content: View>: View {
    @Binding var selection: T?
    let options: [T]
    let placeholder: String
    var accentColor: Color = .accentPrimary
    var allowClear: Bool = true
    @ViewBuilder let content: (T) -> Content
    var selectedContent: ((T) -> Content)?

    @State private var showDropdown: Bool = false
    @State private var isHovered: Bool = false

    init(
        selection: Binding<T?>,
        options: [T],
        placeholder: String = "Select...",
        accentColor: Color = .accentPrimary,
        allowClear: Bool = true,
        @ViewBuilder content: @escaping (T) -> Content,
        selectedContent: ((T) -> Content)? = nil
    ) {
        self._selection = selection
        self.options = options
        self.placeholder = placeholder
        self.accentColor = accentColor
        self.allowClear = allowClear
        self.content = content
        self.selectedContent = selectedContent
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Selected item or placeholder
            if let selected = selection {
                if let selectedContent = selectedContent {
                    selectedContent(selected)
                } else {
                    content(selected)
                }
            } else {
                Text(placeholder)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textMuted)
            }

            Spacer()

            // Clear button
            if allowClear && selection != nil {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
                    .onTapGesture {
                        Haptics.impact(.light)
                        selection = nil
                    }
            }

            // Chevron
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted)
                .rotationEffect(.degrees(showDropdown ? 180 : 0))
                .animation(.spring(response: 0.25), value: showDropdown)
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(showDropdown ? accentColor : (isHovered ? Color.surfaceBorder.opacity(1.5) : Color.surfaceBorder), lineWidth: showDropdown ? 2 : 1)
                )
        )
        .shadow(color: showDropdown ? accentColor.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            Haptics.impact(.light)
            showDropdown.toggle()
        }
        .popover(isPresented: $showDropdown, arrowEdge: .bottom) {
            dropdownContent
        }
        .animation(.easeOut(duration: 0.2), value: showDropdown)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Dropdown Content

    private var dropdownContent: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection != nil && selection == option

                    HStack {
                        content(option)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(accentColor)
                        }
                    }
                    .padding(.horizontal, Spacing.base)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(isSelected ? accentColor.opacity(0.15) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        selection = option
                        showDropdown = false
                    }
                }
            }
            .padding(Spacing.sm)
        }
        .frame(maxHeight: 300)
        .background(Color.backgroundSecondary)
    }
}

// MARK: - Time Block Picker (specialized for time blocks)

struct TimeBlockPicker: View {
    @Binding var selectedBlock: TimeBlock?
    let blocks: [TimeBlock]
    var placeholder: String = "Assign to block"
    var allowClear: Bool = true

    @State private var showDropdown: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Block indicator
            if let block = selectedBlock {
                Circle()
                    .fill(block.priorityColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: block.priorityColor.opacity(0.5), radius: 4, x: 0, y: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.priorityName)
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(block.formattedTimeRange)
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }
            } else {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)

                Text(placeholder)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textMuted)
            }

            Spacer()

            // Clear button
            if allowClear && selectedBlock != nil {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
                    .onTapGesture {
                        Haptics.impact(.light)
                        selectedBlock = nil
                    }
            }

            // Chevron
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted)
                .rotationEffect(.degrees(showDropdown ? 180 : 0))
                .animation(.spring(response: 0.25), value: showDropdown)
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(showDropdown ? Color.accentPrimary : (isHovered ? Color.surfaceBorder.opacity(1.5) : Color.surfaceBorder), lineWidth: showDropdown ? 2 : 1)
                )
        )
        .shadow(color: showDropdown ? Color.accentPrimary.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            Haptics.impact(.light)
            showDropdown.toggle()
        }
        .popover(isPresented: $showDropdown, arrowEdge: .bottom) {
            blockDropdownContent
        }
        .animation(.easeOut(duration: 0.2), value: showDropdown)
    }

    private var blockDropdownContent: some View {
        VStack(spacing: 2) {
            if blocks.isEmpty {
                Text("No blocks available")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textMuted)
                    .padding(Spacing.lg)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(blocks) { block in
                            let isSelected = selectedBlock?.id == block.id

                            HStack(spacing: Spacing.sm) {
                                Circle()
                                    .fill(block.priorityColor)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: block.priorityColor.opacity(0.4), radius: 3, x: 0, y: 0)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(block.priorityName)
                                        .font(Typography.bodyMedium)
                                        .foregroundColor(.textPrimary)

                                    Text(block.formattedTimeRange)
                                        .font(Typography.labelSmall)
                                        .foregroundColor(.textMuted)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(block.priorityColor)
                                }
                            }
                            .padding(.horizontal, Spacing.base)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .fill(isSelected ? block.priorityColor.opacity(0.15) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.impact(.light)
                                selectedBlock = block
                                showDropdown = false
                            }
                        }
                    }
                    .padding(Spacing.sm)
                }
                .frame(maxHeight: 250)
            }
        }
        .frame(minWidth: 220)
        .background(Color.backgroundSecondary)
    }
}

// MARK: - Priority Picker

struct PriorityPicker: View {
    @Binding var selectedPriority: Priority?
    let priorities: [Priority]
    var placeholder: String = "Select priority"
    var allowClear: Bool = true

    @State private var showDropdown: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let priority = selectedPriority {
                Circle()
                    .fill(priority.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: priority.color.opacity(0.5), radius: 4, x: 0, y: 0)

                Text(priority.name)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textPrimary)
            } else {
                Image(systemName: "tag")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)

                Text(placeholder)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textMuted)
            }

            Spacer()

            if allowClear && selectedPriority != nil {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
                    .onTapGesture {
                        Haptics.impact(.light)
                        selectedPriority = nil
                    }
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted)
                .rotationEffect(.degrees(showDropdown ? 180 : 0))
                .animation(.spring(response: 0.25), value: showDropdown)
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(showDropdown ? Color.accentPrimary : (isHovered ? Color.surfaceBorder.opacity(1.5) : Color.surfaceBorder), lineWidth: showDropdown ? 2 : 1)
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            Haptics.impact(.light)
            showDropdown.toggle()
        }
        .popover(isPresented: $showDropdown, arrowEdge: .bottom) {
            priorityDropdownContent
        }
    }

    private var priorityDropdownContent: some View {
        VStack(spacing: 2) {
            ForEach(priorities) { priority in
                let isSelected = selectedPriority?.id == priority.id

                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(priority.color)
                        .frame(width: 10, height: 10)

                    Text(priority.name)
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(priority.color)
                    }
                }
                .padding(.horizontal, Spacing.base)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(isSelected ? priority.color.opacity(0.15) : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    selectedPriority = priority
                    showDropdown = false
                }
            }
        }
        .padding(Spacing.sm)
        .background(Color.backgroundSecondary)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()

        VStack(spacing: Spacing.xl) {
            CustomPicker(
                selection: .constant(nil as String?),
                options: ["Option 1", "Option 2", "Option 3"],
                placeholder: "Select option"
            ) { option in
                Text(option)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textPrimary)
            }
            .frame(width: 200)

            PriorityPicker(
                selectedPriority: .constant(nil),
                priorities: [
                    Priority(id: UUID(), name: "Work", color: .priorityBlue, hoursPerWeek: 40),
                    Priority(id: UUID(), name: "Health", color: .priorityGreen, hoursPerWeek: 10)
                ]
            )
            .frame(width: 200)
        }
        .padding(Spacing.xl)
    }
}
