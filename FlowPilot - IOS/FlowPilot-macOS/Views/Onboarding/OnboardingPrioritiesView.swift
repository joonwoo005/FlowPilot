import SwiftUI

struct OnboardingPrioritiesView: View {
    @ObservedObject var state: OnboardingState
    let step: OnboardingStep
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var hasAppeared = false
    @State private var newPriorityName = ""
    @FocusState private var isAddFieldFocused: Bool

    private let characterLimit = 20

    private var isDuplicate: Bool {
        let trimmed = newPriorityName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !trimmed.isEmpty && state.priorities.contains { $0.name.lowercased() == trimmed }
    }

    private var canAdd: Bool {
        let trimmed = newPriorityName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isDuplicate && state.canAddPriority
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Spacing.xl)

            // Main content - single column layout
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Title
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("What matters most")
                        .font(Typography.headlineLarge)
                        .foregroundColor(.textPrimary)

                    Text("to you?")
                        .font(Typography.headlineLarge)
                        .foregroundColor(.accentPrimary)
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)

                // Add priority bar (horizontal, above grid)
                addPriorityBar
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)

                // Priority grid or empty state
                if state.priorities.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    priorityGrid
                }

                Spacer()

                // Continue button
                HStack {
                    Spacer()
                    PrimaryButton(
                        title: "Continue",
                        action: onContinue,
                        isEnabled: !state.priorities.isEmpty
                    )
                    .frame(width: 180)
                }
                .opacity(hasAppeared ? 1 : 0)
            }
            .frame(maxWidth: 700)
            .padding(.horizontal, Spacing.xxxl)
            .padding(.bottom, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                hasAppeared = true
            }
            // Auto-focus the text field after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isAddFieldFocused = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "star.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentPrimary.opacity(0.6))
            }

            VStack(spacing: Spacing.sm) {
                Text("No priorities yet")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Text("Add your first priority to get started")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, Spacing.xxxl)
    }

    // MARK: - Priority Grid

    private var priorityGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: Spacing.md),
            GridItem(.flexible(), spacing: Spacing.md),
            GridItem(.flexible(), spacing: Spacing.md)
        ]

        return LazyVGrid(columns: columns, spacing: Spacing.md) {
            ForEach(state.priorities) { priority in
                PriorityCard(
                    priority: priority,
                    onDelete: {
                        withAnimation(.spring(response: 0.3)) {
                            state.priorities.removeAll { $0.id == priority.id }
                        }
                    }
                )
            }
        }
        .opacity(hasAppeared ? 1 : 0)
    }

    // MARK: - Add Priority Bar (Horizontal)

    private var addPriorityBar: some View {
        HStack(spacing: Spacing.md) {
            if !state.canAddPriority {
                // Max limit message
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textMuted)

                Text("Maximum of \(OnboardingState.maxPriorities) priorities reached")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textMuted)

                Spacer()
            } else {
                // Name input
                TextField("Add a priority...", text: $newPriorityName)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.surfacePrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .stroke(
                                        isDuplicate ? Color.accentError : (isAddFieldFocused ? Color.accentPrimary : Color.surfaceBorder),
                                        lineWidth: isAddFieldFocused ? 2 : 1
                                    )
                            )
                    )
                    .focused($isAddFieldFocused)
                    .onChange(of: newPriorityName) {
                        if newPriorityName.count > characterLimit {
                            newPriorityName = String(newPriorityName.prefix(characterLimit))
                            Haptics.impact(.heavy)
                        }
                    }
                    .onSubmit {
                        addPriority()
                    }

                // Validation or character count
                if isDuplicate {
                    Text("Already exists")
                        .font(Typography.labelSmall)
                        .foregroundColor(.accentError)
                        .fixedSize()
                } else {
                    Text("\(newPriorityName.count)/\(characterLimit)")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                        .fixedSize()
                }

                // Add button
                Text("Add")
                    .font(Typography.labelLarge)
                    .foregroundColor(canAdd ? .white : .textMuted)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(canAdd ? Color.accentPrimary : Color.surfaceSecondary)
                    )
                    .onTapGesture {
                        addPriority()
                    }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Add Priority Action

    private func addPriority() {
        guard canAdd, state.canAddPriority else { return }

        Haptics.impact(.medium)

        let trimmed = newPriorityName.trimmingCharacters(in: .whitespacesAndNewlines)
        let autoColor = Priority.nextColor(forIndex: state.priorities.count)
        let newPriority = Priority(
            id: UUID(),
            name: trimmed,
            color: autoColor,
            hoursPerWeek: 5
        )

        withAnimation(.spring(response: 0.3)) {
            state.priorities.append(newPriority)
        }

        newPriorityName = ""
    }
}

// MARK: - Priority Card

struct PriorityCard: View {
    let priority: Priority
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(priority.color)
                .frame(width: 4)

            // Content
            HStack {
                Text(priority.name)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Delete button (visible on hover)
                if isHovered {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textMuted)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.surfaceSecondary))
                        .onTapGesture {
                            Haptics.impact(.light)
                            onDelete()
                        }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isHovered ? priority.color.opacity(0.5) : Color.surfaceBorder, lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: isHovered ? priority.color.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        OnboardingPrioritiesView(
            state: {
                let s = OnboardingState()
                s.priorities = [
                    Priority(id: UUID(), name: "Work", color: .priorityBlue, hoursPerWeek: 10),
                    Priority(id: UUID(), name: "Health", color: .priorityGreen, hoursPerWeek: 5),
                    Priority(id: UUID(), name: "Family", color: .priorityPurple, hoursPerWeek: 8)
                ]
                return s
            }(),
            step: .priorities,
            onContinue: {},
            onBack: {}
        )
    }
    .frame(width: 900, height: 700)
}
