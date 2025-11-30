import { useState, useEffect } from "react";
import {
  View,
  Text,
  TextInput,
  Pressable,
  FlatList,
  KeyboardAvoidingView,
  StyleSheet,
  Platform,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { useAuthStore } from "@/stores";
import { priorityRepository } from "@/services/repositories";
import { Priority } from "@/types";
import { GradientBackground, GlassCard, KeyboardDoneBar } from "@/components/ui";
import { colors, typography, spacing, borderRadius } from "@/theme";

const INPUT_ACCESSORY_ID = "prioritiesInput";

const PRIORITY_COLORS = [
  "#FF6B6B",
  "#4ECDC4",
  "#45B7D1",
  "#96CEB4",
  "#FFEAA7",
  "#DDA0DD",
  "#98D8C8",
  "#F7DC6F",
];

export default function PrioritiesScreen() {
  const [input, setInput] = useState("");
  const [priorities, setPriorities] = useState<Priority[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isFocused, setIsFocused] = useState(false);
  const { user } = useAuthStore();

  useEffect(() => {
    if (!user?.uid) return;

    const unsubscribe = priorityRepository.subscribeAll(user.uid, (data) => {
      setPriorities(data);
    });

    return () => unsubscribe();
  }, [user?.uid]);

  const handleAddPriority = async () => {
    if (!input.trim() || !user?.uid) return;

    const priorityName = input.trim();
    setInput(""); // Clear immediately

    setIsLoading(true);
    try {
      const color = PRIORITY_COLORS[priorities.length % PRIORITY_COLORS.length];
      await priorityRepository.createWithOrder(
        user.uid,
        { name: priorityName, color },
        priorities.length
      );
    } catch (error) {
      console.error("Failed to add priority:", error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleDeletePriority = async (id: string) => {
    if (!user?.uid) return;

    try {
      await priorityRepository.delete(user.uid, id);
    } catch (error) {
      console.error("Failed to delete priority:", error);
    }
  };

  const handleContinue = () => {
    router.push("/(onboarding)/sleep");
  };

  const handleBack = () => {
    router.back();
  };

  return (
    <GradientBackground>
      <SafeAreaView style={styles.container} edges={["top", "bottom"]}>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          style={styles.flex}
        >
          {/* Header with Back Button */}
          <View style={styles.header}>
            <Pressable onPress={handleBack} style={styles.backButton}>
              <Ionicons name="chevron-back" size={24} color={colors.text.secondary} />
            </Pressable>
            <View style={styles.stepIndicator}>
              <View style={styles.stepDots}>
                <View style={styles.dotCompleted} />
                <View style={[styles.dot, styles.dotActive]} />
                <View style={styles.dot} />
                <View style={styles.dot} />
              </View>
              <Text style={styles.stepText}>Step 2 of 4</Text>
            </View>
            <View style={styles.headerSpacer} />
          </View>

          <View style={styles.content}>
            {/* Icon Header */}
            <View style={styles.iconContainer}>
              <View style={styles.iconGlow} />
              <View style={styles.iconCircle}>
                <Ionicons name="flag" size={32} color={colors.primary.purple} />
              </View>
            </View>

            <Text style={styles.title}>Your Priorities</Text>
            <Text style={styles.subtitle}>
              What areas of life do you want to{"\n"}allocate time for?
            </Text>

            {/* Input Section */}
            <View style={styles.inputSection}>
              <Text style={styles.label}>ADD A PRIORITY</Text>
              <View style={styles.inputRow}>
                <View style={[
                  styles.inputContainer,
                  isFocused && styles.inputContainerFocused
                ]}>
                  <TextInput
                    style={styles.input}
                    placeholder="e.g., Studying, Exercise, Work"
                    placeholderTextColor={colors.text.muted}
                    value={input}
                    onChangeText={setInput}
                    onSubmitEditing={handleAddPriority}
                    onFocus={() => setIsFocused(true)}
                    onBlur={() => setIsFocused(false)}
                    blurOnSubmit={false}
                    returnKeyType="done"
                    inputAccessoryViewID={INPUT_ACCESSORY_ID}
                  />
                </View>
                <Pressable
                  style={({ pressed }) => [
                    styles.addButton,
                    (!input.trim() || isLoading) && styles.addButtonDisabled,
                    pressed && input.trim() && styles.addButtonPressed,
                  ]}
                  onPress={handleAddPriority}
                  disabled={!input.trim() || isLoading}
                >
                  <Ionicons
                    name="add"
                    size={24}
                    color={input.trim() ? "#fff" : colors.text.muted}
                  />
                </Pressable>
              </View>
            </View>

            {/* Priority List */}
            <FlatList
              data={priorities}
              keyExtractor={(item) => item.id}
              style={styles.list}
              contentContainerStyle={styles.listContent}
              showsVerticalScrollIndicator={false}
              renderItem={({ item }) => (
                <GlassCard style={styles.priorityItem}>
                  <View style={[styles.colorDot, { backgroundColor: item.color }]} />
                  <Text style={styles.priorityName}>{item.name}</Text>
                  <Pressable
                    onPress={() => handleDeletePriority(item.id)}
                    style={({ pressed }) => [
                      styles.deleteButton,
                      pressed && styles.deleteButtonPressed,
                    ]}
                  >
                    <Ionicons name="close" size={18} color={colors.status.error} />
                  </Pressable>
                </GlassCard>
              )}
              ListEmptyComponent={
                <View style={styles.emptyState}>
                  <Ionicons name="flag-outline" size={40} color={colors.text.muted} />
                  <Text style={styles.emptyTitle}>No priorities yet</Text>
                  <Text style={styles.emptyText}>
                    Add at least one priority to continue
                  </Text>
                </View>
              }
            />

            {/* Continue Button */}
            <Pressable
              style={({ pressed }) => [
                styles.button,
                priorities.length === 0 && styles.buttonDisabled,
                pressed && priorities.length > 0 && styles.buttonPressed,
              ]}
              onPress={handleContinue}
              disabled={priorities.length === 0}
            >
              <Text style={[styles.buttonText, priorities.length === 0 && styles.buttonTextDisabled]}>
                Continue
              </Text>
              <Ionicons
                name="arrow-forward"
                size={20}
                color={priorities.length > 0 ? "#fff" : colors.text.muted}
              />
            </Pressable>
          </View>
        </KeyboardAvoidingView>
        <KeyboardDoneBar inputAccessoryViewID={INPUT_ACCESSORY_ID} />
      </SafeAreaView>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  flex: {
    flex: 1,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: spacing.base,
    paddingTop: spacing.sm,
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.surface.secondary,
    alignItems: "center",
    justifyContent: "center",
  },
  stepIndicator: {
    flex: 1,
    alignItems: "center",
  },
  stepDots: {
    flexDirection: "row",
    gap: spacing.sm,
    marginBottom: spacing.xs,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.surface.border,
  },
  dotActive: {
    backgroundColor: colors.primary.blue,
    width: 24,
  },
  dotCompleted: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.status.success,
  },
  stepText: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
  },
  headerSpacer: {
    width: 40,
  },
  content: {
    flex: 1,
    paddingHorizontal: spacing.xl,
    paddingTop: spacing.xl,
  },
  iconContainer: {
    alignItems: "center",
    marginBottom: spacing.xl,
  },
  iconGlow: {
    position: "absolute",
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: colors.primary.purple,
    opacity: 0.15,
  },
  iconCircle: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: colors.surface.elevated,
    borderWidth: 1,
    borderColor: colors.surface.border,
    alignItems: "center",
    justifyContent: "center",
  },
  title: {
    fontSize: typography.fontSize["2xl"],
    fontWeight: typography.fontWeight.bold,
    color: colors.text.primary,
    textAlign: "center",
    marginBottom: spacing.sm,
  },
  subtitle: {
    fontSize: typography.fontSize.base,
    color: colors.text.secondary,
    textAlign: "center",
    lineHeight: 22,
    marginBottom: spacing.xl,
  },
  inputSection: {
    marginBottom: spacing.lg,
  },
  label: {
    fontSize: typography.fontSize.xs,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.muted,
    letterSpacing: 1,
    marginBottom: spacing.sm,
    marginLeft: spacing.xs,
  },
  inputRow: {
    flexDirection: "row",
    gap: spacing.sm,
  },
  inputContainer: {
    flex: 1,
    backgroundColor: colors.surface.secondary,
    borderRadius: borderRadius.xl,
    borderWidth: 1,
    borderColor: colors.surface.border,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.base,
  },
  inputContainerFocused: {
    borderColor: colors.primary.blue,
    backgroundColor: colors.surface.elevated,
  },
  input: {
    fontSize: typography.fontSize.base,
    color: colors.text.primary,
    padding: 0,
  },
  addButton: {
    width: 52,
    backgroundColor: colors.primary.blue,
    borderRadius: borderRadius.xl,
    alignItems: "center",
    justifyContent: "center",
  },
  addButtonDisabled: {
    backgroundColor: colors.surface.secondary,
    borderWidth: 1,
    borderColor: colors.surface.border,
  },
  addButtonPressed: {
    opacity: 0.9,
  },
  list: {
    flex: 1,
    marginBottom: spacing.base,
  },
  listContent: {
    gap: spacing.sm,
  },
  priorityItem: {
    flexDirection: "row",
    alignItems: "center",
    padding: spacing.base,
  },
  colorDot: {
    width: 14,
    height: 14,
    borderRadius: 7,
    marginRight: spacing.md,
  },
  priorityName: {
    flex: 1,
    fontSize: typography.fontSize.md,
    color: colors.text.primary,
    fontWeight: typography.fontWeight.medium,
  },
  deleteButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "rgba(239, 68, 68, 0.15)",
    alignItems: "center",
    justifyContent: "center",
  },
  deleteButtonPressed: {
    backgroundColor: "rgba(239, 68, 68, 0.25)",
  },
  emptyState: {
    alignItems: "center",
    paddingVertical: spacing["3xl"],
    gap: spacing.sm,
  },
  emptyTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.medium,
    color: colors.text.secondary,
  },
  emptyText: {
    color: colors.text.muted,
    textAlign: "center",
    fontSize: typography.fontSize.sm,
  },
  button: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.primary.blue,
    borderRadius: borderRadius.xl,
    paddingVertical: spacing.lg,
    gap: spacing.sm,
    marginBottom: spacing.base,
  },
  buttonDisabled: {
    backgroundColor: colors.surface.secondary,
    borderWidth: 1,
    borderColor: colors.surface.border,
  },
  buttonPressed: {
    opacity: 0.9,
    transform: [{ scale: 0.98 }],
  },
  buttonText: {
    color: "#fff",
    fontWeight: typography.fontWeight.semibold,
    fontSize: typography.fontSize.md,
  },
  buttonTextDisabled: {
    color: colors.text.muted,
  },
});
