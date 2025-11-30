import { useState, useEffect } from "react";
import {
  View,
  Text,
  Pressable,
  FlatList,
  TextInput,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { useAuthStore, useUserStore } from "@/stores";
import { priorityRepository, userRepository } from "@/services/repositories";
import { Priority } from "@/types";
import { GradientBackground, GlassCard, KeyboardDoneBar } from "@/components/ui";
import { colors, typography, spacing, borderRadius } from "@/theme";

const INPUT_ACCESSORY_ID = "allocateHoursInput";

interface PriorityAllocation extends Priority {
  allocatedHours: number;
}

export default function AllocateScreen() {
  const [priorities, setPriorities] = useState<PriorityAllocation[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const { user } = useAuthStore();
  const { profile } = useUserStore();

  const weeklyAwakeHours = (profile?.awakeHoursPerDay ?? 16) * 7;

  useEffect(() => {
    if (!user?.uid) return;

    const unsubscribe = priorityRepository.subscribeAll(user.uid, (data) => {
      setPriorities(
        data.map((p) => ({
          ...p,
          allocatedHours: p.weeklyHoursTarget,
        }))
      );
    });

    return () => unsubscribe();
  }, [user?.uid]);

  const totalAllocated = priorities.reduce(
    (sum, p) => sum + (p.allocatedHours || 0),
    0
  );
  const remainingHours = weeklyAwakeHours - totalAllocated;
  const progressPercent = Math.min((totalAllocated / weeklyAwakeHours) * 100, 100);

  const handleHoursChange = async (id: string, hours: string) => {
    const numHours = Math.max(0, parseInt(hours) || 0);
    setPriorities((prev) =>
      prev.map((p) =>
        p.id === id ? { ...p, allocatedHours: numHours } : p
      )
    );

    // Auto-save to Firestore so values persist across navigation
    if (user?.uid) {
      try {
        await priorityRepository.updateWeeklyHours(user.uid, id, numHours);
      } catch (error) {
        console.error("Failed to save hours:", error);
      }
    }
  };

  const handleComplete = async () => {
    if (!user?.uid || remainingHours < 0) return;

    setIsLoading(true);
    try {
      await userRepository.completeOnboarding(user.uid);
      router.replace("/(main)");
    } catch (error) {
      console.error("Failed to complete setup:", error);
    } finally {
      setIsLoading(false);
    }
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
                <View style={styles.dotCompleted} />
                <View style={styles.dotCompleted} />
                <View style={[styles.dot, styles.dotActive]} />
              </View>
              <Text style={styles.stepText}>Step 4 of 4</Text>
            </View>
            <View style={styles.headerSpacer} />
          </View>

          <View style={styles.content}>
            {/* Icon Header */}
            <View style={styles.iconContainer}>
              <View style={styles.iconGlow} />
              <View style={styles.iconCircle}>
                <Ionicons name="time" size={32} color={colors.status.success} />
              </View>
            </View>

            <Text style={styles.title}>Allocate Hours</Text>
            <Text style={styles.subtitle}>
              How many hours per week do you want{"\n"}to dedicate to each priority?
            </Text>

            {/* Summary Card */}
            <GlassCard style={styles.summaryCard}>
              <View style={styles.summaryHeader}>
                <View>
                  <Text style={styles.summaryLabel}>Weekly Budget</Text>
                  <Text style={styles.summaryTotal}>{weeklyAwakeHours}h available</Text>
                </View>
                <View style={styles.remainingBadge}>
                  <Text style={[
                    styles.remainingValue,
                    remainingHours < 0 && styles.remainingNegative,
                    remainingHours === 0 && styles.remainingZero,
                  ]}>
                    {remainingHours}h
                  </Text>
                  <Text style={styles.remainingLabel}>remaining</Text>
                </View>
              </View>

              {/* Progress Bar */}
              <View style={styles.progressContainer}>
                <View style={styles.progressTrack}>
                  <View
                    style={[
                      styles.progressFill,
                      { width: `${progressPercent}%` },
                      remainingHours < 0 && styles.progressOverflow,
                    ]}
                  />
                </View>
                <Text style={styles.progressText}>
                  {totalAllocated}h allocated
                </Text>
              </View>
            </GlassCard>

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
                  <View style={styles.hoursInputContainer}>
                    <TextInput
                      style={styles.hoursInput}
                      keyboardType="number-pad"
                      value={item.allocatedHours.toString()}
                      onChangeText={(text) => handleHoursChange(item.id, text)}
                      inputAccessoryViewID={INPUT_ACCESSORY_ID}
                      placeholder="0"
                      placeholderTextColor={colors.text.muted}
                      selectTextOnFocus
                    />
                    <Text style={styles.hoursLabel}>h/wk</Text>
                  </View>
                </GlassCard>
              )}
            />

            {/* Warning if over budget */}
            {remainingHours < 0 && (
              <View style={styles.warningBanner}>
                <Ionicons name="warning" size={18} color={colors.status.error} />
                <Text style={styles.warningText}>
                  You've allocated {Math.abs(remainingHours)}h more than available
                </Text>
              </View>
            )}

            {/* Complete Button */}
            <Pressable
              style={({ pressed }) => [
                styles.button,
                (remainingHours < 0 || isLoading) && styles.buttonDisabled,
                pressed && remainingHours >= 0 && !isLoading && styles.buttonPressed,
              ]}
              onPress={handleComplete}
              disabled={remainingHours < 0 || isLoading}
            >
              {isLoading ? (
                <Text style={styles.buttonText}>Setting up...</Text>
              ) : (
                <>
                  <Text style={[
                    styles.buttonText,
                    (remainingHours < 0) && styles.buttonTextDisabled,
                  ]}>
                    Complete Setup
                  </Text>
                  <Ionicons
                    name="checkmark-circle"
                    size={20}
                    color={remainingHours >= 0 ? "#fff" : colors.text.muted}
                  />
                </>
              )}
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
    paddingTop: spacing.lg,
  },
  iconContainer: {
    alignItems: "center",
    marginBottom: spacing.lg,
  },
  iconGlow: {
    position: "absolute",
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: colors.status.success,
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
    marginBottom: spacing.lg,
  },
  summaryCard: {
    padding: spacing.base,
    marginBottom: spacing.lg,
  },
  summaryHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: spacing.md,
  },
  summaryLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginBottom: 2,
  },
  summaryTotal: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  remainingBadge: {
    alignItems: "flex-end",
  },
  remainingValue: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.bold,
    color: colors.status.success,
  },
  remainingNegative: {
    color: colors.status.error,
  },
  remainingZero: {
    color: colors.primary.blue,
  },
  remainingLabel: {
    fontSize: typography.fontSize.xs,
    color: colors.text.muted,
  },
  progressContainer: {
    gap: spacing.xs,
  },
  progressTrack: {
    height: 6,
    backgroundColor: colors.surface.border,
    borderRadius: 3,
    overflow: "hidden",
  },
  progressFill: {
    height: "100%",
    backgroundColor: colors.status.success,
    borderRadius: 3,
  },
  progressOverflow: {
    backgroundColor: colors.status.error,
  },
  progressText: {
    fontSize: typography.fontSize.xs,
    color: colors.text.muted,
    textAlign: "right",
  },
  list: {
    flex: 1,
    marginBottom: spacing.sm,
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
  hoursInputContainer: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
  },
  hoursInput: {
    width: 56,
    height: 40,
    backgroundColor: colors.surface.secondary,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: colors.surface.border,
    textAlign: "center",
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  hoursLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    width: 32,
  },
  warningBanner: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: spacing.sm,
    backgroundColor: "rgba(239, 68, 68, 0.15)",
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: "rgba(239, 68, 68, 0.3)",
    padding: spacing.md,
    marginBottom: spacing.md,
  },
  warningText: {
    fontSize: typography.fontSize.sm,
    color: colors.status.error,
    fontWeight: typography.fontWeight.medium,
  },
  button: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.status.success,
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
