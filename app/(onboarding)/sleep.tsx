import { useState, useEffect } from "react";
import { View, Text, Pressable, StyleSheet, Modal } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import DateTimePicker from "@react-native-community/datetimepicker";
import { useAuthStore, useUserStore } from "@/stores";
import { userRepository } from "@/services/repositories";
import { calculateAwakeHours } from "@/utils";
import { GradientBackground, GlassCard } from "@/components/ui";
import { colors, typography, spacing, borderRadius } from "@/theme";

const timeStringToDate = (timeStr: string): Date => {
  const [hours, minutes] = timeStr.split(":").map(Number);
  const date = new Date();
  date.setHours(hours, minutes, 0, 0);
  return date;
};

const dateToTimeString = (date: Date): string => {
  return `${date.getHours().toString().padStart(2, "0")}:${date
    .getMinutes()
    .toString()
    .padStart(2, "0")}`;
};

const formatTime12Hour = (time: string): string => {
  const [hours, minutes] = time.split(":").map(Number);
  const period = hours >= 12 ? "PM" : "AM";
  const hour12 = hours % 12 || 12;
  return `${hour12}:${minutes.toString().padStart(2, "0")} ${period}`;
};

export default function SleepScreen() {
  const [sleepTime, setSleepTime] = useState("22:00");
  const [wakeTime, setWakeTime] = useState("06:00");
  const [tempSleepTime, setTempSleepTime] = useState("22:00");
  const [tempWakeTime, setTempWakeTime] = useState("06:00");
  const [showSleepPicker, setShowSleepPicker] = useState(false);
  const [showWakePicker, setShowWakePicker] = useState(false);
  const { user } = useAuthStore();
  const { profile } = useUserStore();

  // Load existing values if user comes back
  useEffect(() => {
    if (profile?.sleepTime) {
      setSleepTime(profile.sleepTime);
    }
    if (profile?.wakeTime) {
      setWakeTime(profile.wakeTime);
    }
  }, [profile?.sleepTime, profile?.wakeTime]);

  const awakeHoursPerDay = calculateAwakeHours(sleepTime, wakeTime);
  const sleepHours = 24 - awakeHoursPerDay;
  const weeklyAwakeHours = awakeHoursPerDay * 7;

  const handleSleepChange = (_: any, selectedDate?: Date) => {
    if (selectedDate) {
      setTempSleepTime(dateToTimeString(selectedDate));
    }
  };

  const handleWakeChange = (_: any, selectedDate?: Date) => {
    if (selectedDate) {
      setTempWakeTime(dateToTimeString(selectedDate));
    }
  };

  const openSleepPicker = () => {
    setTempSleepTime(sleepTime);
    setShowSleepPicker(true);
  };

  const openWakePicker = () => {
    setTempWakeTime(wakeTime);
    setShowWakePicker(true);
  };

  const confirmSleepTime = async () => {
    setSleepTime(tempSleepTime);
    setShowSleepPicker(false);

    // Auto-save
    if (user?.uid) {
      const awakeHours = calculateAwakeHours(tempSleepTime, wakeTime);
      await userRepository.updateSleepSchedule(user.uid, tempSleepTime, wakeTime, awakeHours);
    }
  };

  const confirmWakeTime = async () => {
    setWakeTime(tempWakeTime);
    setShowWakePicker(false);

    // Auto-save
    if (user?.uid) {
      const awakeHours = calculateAwakeHours(sleepTime, tempWakeTime);
      await userRepository.updateSleepSchedule(user.uid, sleepTime, tempWakeTime, awakeHours);
    }
  };

  const handleContinue = async () => {
    // Ensure sleep schedule is saved before continuing
    if (user?.uid) {
      try {
        await userRepository.updateSleepSchedule(user.uid, sleepTime, wakeTime, awakeHoursPerDay);
      } catch (error) {
        console.error("Failed to save sleep schedule:", error);
      }
    }
    router.push("/(onboarding)/allocate");
  };

  const handleBack = () => {
    router.back();
  };

  return (
    <GradientBackground>
      <SafeAreaView style={styles.container} edges={["top", "bottom"]}>
        {/* Header with Back Button */}
        <View style={styles.header}>
          <Pressable onPress={handleBack} style={styles.backButton}>
            <Ionicons name="chevron-back" size={24} color={colors.text.secondary} />
          </Pressable>
          <View style={styles.stepIndicator}>
            <View style={styles.stepDots}>
              <View style={styles.dotCompleted} />
              <View style={styles.dotCompleted} />
              <View style={[styles.dot, styles.dotActive]} />
              <View style={styles.dot} />
            </View>
            <Text style={styles.stepText}>Step 3 of 4</Text>
          </View>
          <View style={styles.headerSpacer} />
        </View>

        <View style={styles.content}>
          {/* Icon Header */}
          <View style={styles.iconContainer}>
            <View style={styles.iconGlow} />
            <View style={styles.iconCircle}>
              <Ionicons name="moon" size={32} color="#818CF8" />
            </View>
          </View>

          <Text style={styles.title}>Sleep Schedule</Text>
          <Text style={styles.subtitle}>
            When do you typically go to bed{"\n"}and wake up?
          </Text>

          {/* Time Selectors */}
          <View style={styles.timeSection}>
            <Pressable onPress={openSleepPicker}>
              <GlassCard style={styles.timeCard}>
                <View style={styles.timeIconContainer}>
                  <Ionicons name="bed-outline" size={22} color={colors.primary.purple} />
                </View>
                <View style={styles.timeInfo}>
                  <Text style={styles.timeLabel}>Bedtime</Text>
                  <Text style={styles.timeValue}>{formatTime12Hour(sleepTime)}</Text>
                </View>
                <Ionicons name="chevron-forward" size={20} color={colors.text.muted} />
              </GlassCard>
            </Pressable>

            <Pressable onPress={openWakePicker}>
              <GlassCard style={styles.timeCard}>
                <View style={[styles.timeIconContainer, styles.wakeIconContainer]}>
                  <Ionicons name="sunny-outline" size={22} color={colors.status.warning} />
                </View>
                <View style={styles.timeInfo}>
                  <Text style={styles.timeLabel}>Wake Time</Text>
                  <Text style={styles.timeValue}>{formatTime12Hour(wakeTime)}</Text>
                </View>
                <Ionicons name="chevron-forward" size={20} color={colors.text.muted} />
              </GlassCard>
            </Pressable>
          </View>

          {/* Summary Stats */}
          <GlassCard style={styles.summaryCard}>
            <View style={styles.summaryRow}>
              <View style={styles.summaryItem}>
                <Text style={styles.summaryValue}>{awakeHoursPerDay}</Text>
                <Text style={styles.summaryLabel}>Awake hours</Text>
              </View>
              <View style={styles.summaryDivider} />
              <View style={styles.summaryItem}>
                <Text style={styles.summaryValue}>{sleepHours}</Text>
                <Text style={styles.summaryLabel}>Sleep hours</Text>
              </View>
            </View>
            <View style={styles.weeklyRow}>
              <Ionicons name="calendar-outline" size={14} color={colors.primary.blue} />
              <Text style={styles.weeklyText}>
                {weeklyAwakeHours} hours available per week
              </Text>
            </View>
          </GlassCard>

          <View style={styles.spacer} />

          {/* Continue Button */}
          <Pressable
            style={({ pressed }) => [
              styles.button,
              pressed && styles.buttonPressed,
            ]}
            onPress={handleContinue}
          >
            <Text style={styles.buttonText}>Continue</Text>
            <Ionicons name="arrow-forward" size={20} color="#fff" />
          </Pressable>
        </View>

        {/* Sleep Time Picker Modal */}
        <Modal
          visible={showSleepPicker}
          transparent
          animationType="slide"
        >
          <Pressable style={styles.modalOverlay} onPress={() => setShowSleepPicker(false)}>
            <Pressable style={styles.modalContent} onPress={(e) => e.stopPropagation()}>
              <View style={styles.modalHeader}>
                <Pressable onPress={() => setShowSleepPicker(false)}>
                  <Text style={styles.modalCancel}>Cancel</Text>
                </Pressable>
                <Text style={styles.modalTitle}>Bedtime</Text>
                <Pressable onPress={confirmSleepTime}>
                  <Text style={styles.modalDone}>Done</Text>
                </Pressable>
              </View>
              <DateTimePicker
                value={timeStringToDate(tempSleepTime)}
                mode="time"
                is24Hour={false}
                display="spinner"
                onChange={handleSleepChange}
                themeVariant="dark"
                textColor={colors.text.primary}
              />
            </Pressable>
          </Pressable>
        </Modal>

        {/* Wake Time Picker Modal */}
        <Modal
          visible={showWakePicker}
          transparent
          animationType="slide"
        >
          <Pressable style={styles.modalOverlay} onPress={() => setShowWakePicker(false)}>
            <Pressable style={styles.modalContent} onPress={(e) => e.stopPropagation()}>
              <View style={styles.modalHeader}>
                <Pressable onPress={() => setShowWakePicker(false)}>
                  <Text style={styles.modalCancel}>Cancel</Text>
                </Pressable>
                <Text style={styles.modalTitle}>Wake Time</Text>
                <Pressable onPress={confirmWakeTime}>
                  <Text style={styles.modalDone}>Done</Text>
                </Pressable>
              </View>
              <DateTimePicker
                value={timeStringToDate(tempWakeTime)}
                mode="time"
                is24Hour={false}
                display="spinner"
                onChange={handleWakeChange}
                themeVariant="dark"
                textColor={colors.text.primary}
              />
            </Pressable>
          </Pressable>
        </Modal>
      </SafeAreaView>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  container: {
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
    backgroundColor: "#818CF8",
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
  timeSection: {
    gap: spacing.md,
    marginBottom: spacing.xl,
  },
  timeCard: {
    flexDirection: "row",
    alignItems: "center",
    padding: spacing.base,
  },
  timeIconContainer: {
    width: 44,
    height: 44,
    borderRadius: 12,
    backgroundColor: "rgba(139, 92, 246, 0.15)",
    alignItems: "center",
    justifyContent: "center",
    marginRight: spacing.md,
  },
  wakeIconContainer: {
    backgroundColor: "rgba(245, 158, 11, 0.15)",
  },
  timeInfo: {
    flex: 1,
  },
  timeLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginBottom: 2,
  },
  timeValue: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  summaryCard: {
    padding: spacing.lg,
  },
  summaryRow: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: spacing.base,
  },
  summaryItem: {
    flex: 1,
    alignItems: "center",
  },
  summaryDivider: {
    width: 1,
    height: 40,
    backgroundColor: colors.surface.border,
  },
  summaryValue: {
    fontSize: typography.fontSize["2xl"],
    fontWeight: typography.fontWeight.bold,
    color: colors.text.primary,
  },
  summaryLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginTop: 2,
  },
  weeklyRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: spacing.xs,
    paddingTop: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.surface.border,
  },
  weeklyText: {
    fontSize: typography.fontSize.sm,
    color: colors.primary.blue,
    fontWeight: typography.fontWeight.medium,
  },
  spacer: {
    flex: 1,
  },
  button: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.primary.blue,
    borderRadius: borderRadius.xl,
    paddingVertical: spacing.lg,
    gap: spacing.sm,
    marginBottom: spacing.xl,
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
  modalOverlay: {
    flex: 1,
    justifyContent: "flex-end",
    backgroundColor: "rgba(0, 0, 0, 0.6)",
  },
  modalContent: {
    backgroundColor: colors.background.start,
    borderTopLeftRadius: borderRadius["2xl"],
    borderTopRightRadius: borderRadius["2xl"],
    paddingBottom: spacing["3xl"],
  },
  modalHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    padding: spacing.base,
    borderBottomWidth: 1,
    borderBottomColor: colors.surface.border,
  },
  modalTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  modalCancel: {
    fontSize: typography.fontSize.base,
    color: colors.text.secondary,
    paddingHorizontal: spacing.sm,
  },
  modalDone: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.semibold,
    color: colors.primary.blue,
    paddingHorizontal: spacing.sm,
  },
});
