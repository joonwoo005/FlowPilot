import SwiftUI

struct OnboardingPrioritiesView: View {
    @ObservedObject var state: OnboardingState
    let step: OnboardingStep
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var hasAppeared = false
    @State private var showAddSheet = false
    @State private var newPriorityName = ""

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: step, onBack: onBack)
                .opacity(hasAppeared ? 1 : 0)

            // Title
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("What matters most")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.textPrimary)

                Text("to you?")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.accentPrimary)

                Text("Add the priorities you want to make time for")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)

            // Priority list
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(state.priorities) { priority in
                        PriorityRow(
                            priority: priority,
                            onDelete: {
                                withAnimation(.spring(response: 0.3)) {
                                    state.priorities.removeAll { $0.id == priority.id }
                                }
                            }
                        )
                    }

                    AddPriorityButton { showAddSheet = true }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, 120)
            }
            .opacity(hasAppeared ? 1 : 0)

            Spacer(minLength: 0)

            PrimaryButton(
                title: "Continue",
                action: onContinue,
                isEnabled: !state.priorities.isEmpty
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
            .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddPrioritySheet(
                name: $newPriorityName,
                existingNames: state.priorities.map { $0.name.lowercased() },
                onAdd: {
                    let trimmed = newPriorityName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isDuplicate = state.priorities.contains { $0.name.lowercased() == trimmed.lowercased() }

                    if !trimmed.isEmpty && !isDuplicate {
                        let autoColor = Priority.nextColor(forIndex: state.priorities.count)
                        let newPriority = Priority(
                            id: UUID(),
                            name: trimmed,
                            color: autoColor,
                            hoursPerWeek: 5
                        )
                        withAnimation {
                            state.priorities.append(newPriority)
                        }
                        newPriorityName = ""
                        showAddSheet = false
                    }
                },
                onCancel: {
                    newPriorityName = ""
                    showAddSheet = false
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Priority Row
struct PriorityRow: View {
    let priority: Priority
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(priority.color)
                .frame(width: 10, height: 10)

            Text(priority.name)
                .font(Typography.bodyLarge)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textMuted)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.surfaceSecondary))
                .onTapGesture {
                    Haptics.impact(.light)
                    onDelete()
                }
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Add Priority Button
struct AddPriorityButton: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentPrimary)

            Text("Add Priority")
                .font(Typography.bodyMedium)
                .foregroundColor(.accentPrimary)

            Spacer()
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.accentPrimary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundColor(Color.accentPrimary.opacity(0.3))
                )
        )
        .onTapGesture {
            Haptics.impact(.light)
            action()
        }
    }
}

// MARK: - Add Priority Sheet
struct AddPrioritySheet: View {
    @Binding var name: String
    let existingNames: [String]
    let onAdd: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool
    @State private var showLimitError = false

    private let characterLimit = 20

    private var isDuplicate: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !trimmed.isEmpty && existingNames.contains(trimmed)
    }

    private var canAdd: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isDuplicate
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Cancel")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .onTapGesture { onCancel() }

                Spacer()

                Text("New Priority")
                    .font(Typography.labelMedium)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("Add")
                    .font(Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(canAdd ? .accentPrimary : .textMuted)
                    .onTapGesture {
                        if canAdd { onAdd() }
                    }
            }
            .padding(.top, Spacing.base)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                TextField("", text: $name)
                    .font(Typography.bodyLarge)
                    .foregroundColor(.textPrimary)
                    .focused($isFocused)
                    .placeholder(when: name.isEmpty) {
                        Text("Priority name")
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.surfacePrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .stroke((showLimitError || isDuplicate) ? Color.accentError : (isFocused ? Color.accentPrimary : Color.surfaceBorder), lineWidth: 1)
                            )
                    )
                    .onChange(of: name) {
                        if name.count > characterLimit {
                            name = String(name.prefix(characterLimit))
                            showLimitError = true
                            Haptics.impact(.heavy)
                        } else {
                            showLimitError = false
                        }
                    }

                HStack {
                    if showLimitError {
                        Text("Maximum \(characterLimit) characters")
                            .font(Typography.labelSmall)
                            .foregroundColor(.accentError)
                    } else if isDuplicate {
                        Text("Priority already exists")
                            .font(Typography.labelSmall)
                            .foregroundColor(.accentError)
                    }

                    Spacer()

                    Text("\(name.count)/\(characterLimit)")
                        .font(Typography.labelSmall)
                        .foregroundColor((showLimitError || isDuplicate) ? .accentError : .textMuted)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
        .onAppear { isFocused = true }
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        OnboardingPrioritiesView(
            state: OnboardingState(),
            step: .priorities,
            onContinue: {},
            onBack: {}
        )
    }
}
