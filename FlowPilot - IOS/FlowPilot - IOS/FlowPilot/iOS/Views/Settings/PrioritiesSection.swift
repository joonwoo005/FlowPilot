import SwiftUI

struct PrioritiesSection: View {
    @ObservedObject var state: OnboardingState
    @State private var editingPriority: Priority? = nil
    @State private var showAddPriority = false

    private var totalAllocated: Double {
        state.priorities.reduce(0) { $0 + $1.hoursPerWeek }
    }

    private var availableHours: Double {
        state.sleepSchedule.availableHoursPerWeek
    }

    private var allocationPercentage: Double {
        guard availableHours > 0 else { return 0 }
        return min(1.0, totalAllocated / availableHours)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            SettingsSectionHeader(
                title: "Priorities",
                icon: "square.stack.3d.up.fill",
                iconColor: .priorityPurple
            )

            VStack(spacing: Spacing.sm) {
                // Hours Overview
                HoursOverviewCard(
                    allocated: totalAllocated,
                    available: availableHours,
                    percentage: allocationPercentage
                )

                // Priority List
                VStack(spacing: 0) {
                    ForEach(Array(state.priorities.enumerated()), id: \.element.id) { index, priority in
                        PrioritySettingsRow(
                            priority: priority,
                            isFirst: index == 0,
                            isLast: index == state.priorities.count - 1,
                            onEdit: {
                                editingPriority = priority
                            },
                            onDelete: {
                                withAnimation(.spring(response: 0.3)) {
                                    state.deletePriority(priority.id)
                                }
                            }
                        )

                        if index < state.priorities.count - 1 {
                            Rectangle()
                                .fill(Color.surfaceBorder)
                                .frame(height: 1)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )

                // Add Priority Button or Max Limit Message
                if state.canAddPriority {
                    SettingsAddPriorityButton {
                        showAddPriority = true
                    }
                } else {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.textMuted)

                        Text("Maximum of \(OnboardingState.maxPriorities) priorities reached")
                            .font(Typography.labelSmall)
                            .foregroundColor(.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                }
            }
        }
        .sheet(item: $editingPriority) { priority in
            EditPrioritySheet(
                priority: priority,
                state: state,
                onSave: { updatedPriority in
                    state.updatePriority(updatedPriority)
                    editingPriority = nil
                },
                onDelete: {
                    state.deletePriority(priority.id)
                    editingPriority = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddPriority) {
            SettingsAddPrioritySheet(state: state)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Priority Settings Row
struct PrioritySettingsRow: View {
    let priority: Priority
    let isFirst: Bool
    let isLast: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Color indicator with glow
            ZStack {
                Circle()
                    .fill(priority.color.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .blur(radius: 4)

                Circle()
                    .fill(priority.color)
                    .frame(width: 12, height: 12)
            }
            .shadow(color: priority.color.opacity(0.4), radius: 4, x: 0, y: 0)

            // Name
            Text(priority.name)
                .font(Typography.bodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            // Hours badge
            Text("\(Int(priority.hoursPerWeek))h")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(priority.color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(priority.color.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(priority.color.opacity(0.25), lineWidth: 1)
                        )
                )

            // Edit chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted)
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            Haptics.impact(.light)
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onEdit()
            }
        }
    }
}

// MARK: - Settings Add Priority Button
struct SettingsAddPriorityButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }

            Text("Add Priority")
                .font(Typography.bodyMedium)
                .foregroundColor(.accentPrimary)

            Spacer()
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .foregroundColor(Color.accentPrimary.opacity(0.4))
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            Haptics.impact(.light)
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }
    }
}

// MARK: - Settings Add Priority Sheet
struct SettingsAddPrioritySheet: View {
    @ObservedObject var state: OnboardingState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var hoursPerWeek: Double = 10
    @State private var isEditingHours = false
    @State private var hoursText = ""
    @State private var hoursError: String? = nil
    @FocusState private var isNameFocused: Bool
    @FocusState private var isHoursFocused: Bool

    private var autoColor: Color {
        Priority.nextColor(forIndex: state.priorities.count)
    }

    private var remainingHours: Double {
        state.sleepSchedule.availableHoursPerWeek - state.priorities.reduce(0) { $0 + $1.hoursPerWeek }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && state.canAddPriority
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Name Input
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Name")
                                .font(Typography.labelMedium)
                                .foregroundColor(.textSecondary)

                            TextField("Priority name", text: $name)
                                .font(Typography.bodyLarge)
                                .foregroundColor(.textPrimary)
                                .padding(Spacing.base)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                                .stroke(isNameFocused ? Color.accentPrimary : Color.surfaceBorder, lineWidth: isNameFocused ? 2 : 1)
                                        )
                                )
                                .focused($isNameFocused)
                        }

                        // Hours Input
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Hours per week")
                                    .font(Typography.labelMedium)
                                    .foregroundColor(.textSecondary)

                                Spacer()

                                Text("\(Int(remainingHours))h available")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(.textMuted)
                            }

                            if isEditingHours {
                                HStack {
                                    TextField("", text: $hoursText)
                                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        .foregroundColor(hoursError != nil ? .accentError : autoColor)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .focused($isHoursFocused)
                                        .onChange(of: hoursText) { _, newValue in
                                            validateHoursInput(newValue)
                                        }

                                    Text("h")
                                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                                .stroke(hoursError != nil ? Color.accentError : autoColor, lineWidth: 2)
                                        )
                                )

                                // Error message
                                if let error = hoursError {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text(error)
                                            .font(Typography.labelSmall)
                                    }
                                    .foregroundColor(.accentError)
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    Text("\(Int(hoursPerWeek))")
                                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        .foregroundColor(autoColor)
                                    Text("h")
                                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                                .stroke(Color.surfaceBorder, lineWidth: 1)
                                        )
                                )
                                .onTapGesture {
                                    Haptics.impact(.light)
                                    hoursText = "\(Int(hoursPerWeek))"
                                    isEditingHours = true
                                    isHoursFocused = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xl)
                }
            }
            .navigationTitle("Add Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Text("Add")
                        .font(Typography.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(isValid ? .accentPrimary : .textMuted)
                        .onTapGesture {
                            guard isValid, state.canAddPriority else { return }
                            Haptics.impact(.medium)
                            let newPriority = Priority(
                                id: UUID(),
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                color: autoColor,
                                hoursPerWeek: hoursPerWeek
                            )
                            state.addPriority(newPriority)
                            dismiss()
                        }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Text("Done")
                            .font(Typography.labelLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentPrimary)
                            .onTapGesture {
                                if isHoursFocused {
                                    commitHoursEdit()
                                }
                                isNameFocused = false
                                isHoursFocused = false
                            }
                    }
                }
            }
        }
    }

    private func validateHoursInput(_ input: String) {
        guard let value = Double(input) else {
            hoursError = input.isEmpty ? nil : "Enter a valid number"
            return
        }

        if value < 1 {
            hoursError = "Minimum 1 hour required"
        } else if value > remainingHours {
            hoursError = "Exceeds available hours (\(Int(remainingHours))h max)"
        } else {
            hoursError = nil
        }
    }

    private func commitHoursEdit() {
        if let value = Double(hoursText) {
            if value < 1 {
                hoursPerWeek = 1
            } else if value > remainingHours {
                hoursPerWeek = remainingHours
            } else {
                hoursPerWeek = value
            }
        }
        hoursError = nil
        isEditingHours = false
        isHoursFocused = false
    }
}

// MARK: - Color Picker
struct SettingsPriorityColorPicker: View {
    @Binding var selectedIndex: Int
    var usedColors: [Color] = []
    var currentColor: Color? = nil  // The color of the priority being edited (allowed to keep)

    private let colors = Priority.availableColors

    private func isColorDisabled(_ color: Color) -> Bool {
        // Allow the current color (for editing existing priority)
        if let current = currentColor, color == current {
            return false
        }
        return usedColors.contains(color)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(0..<colors.count, id: \.self) { index in
                let color = colors[index]
                let disabled = isColorDisabled(color)

                ColorCircle(
                    color: color,
                    isSelected: selectedIndex == index,
                    isDisabled: disabled,
                    onTap: {
                        guard !disabled else { return }
                        Haptics.impact(.light)
                        selectedIndex = index
                    }
                )
            }

            Spacer()
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Color Circle
private struct ColorCircle: View {
    let color: Color
    let isSelected: Bool
    var isDisabled: Bool = false
    let onTap: () -> Void

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .blur(radius: 6)
            }

            Circle()
                .fill(isDisabled ? color.opacity(0.2) : color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
                )
                .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 6, x: 0, y: 0)

            // Show X for disabled colors
            if isDisabled {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.textMuted)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        PrioritiesSection(state: {
            let state = OnboardingState()
            state.priorities = [
                Priority(id: UUID(), name: "Work", color: .priorityBlue, hoursPerWeek: 40),
                Priority(id: UUID(), name: "Health", color: .priorityGreen, hoursPerWeek: 10),
                Priority(id: UUID(), name: "Learning", color: .priorityPurple, hoursPerWeek: 8)
            ]
            return state
        }())
        .padding()
    }
}
