import { useEffect, useRef } from "react";
import { View, Text, ScrollView, Pressable, StyleSheet, Alert } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { usePlannerStore } from "@/stores";
import { useTaskStore } from "@/stores";
import { usePriorities, useTimeBlocks, useUser } from "@/hooks";
import { DayCard } from "@/components/planner";
import { GradientBackground } from "@/components/ui";
import { exportWeekToCalendar } from "@/services/calendar.service";
import { colors, typography, spacing, borderRadius } from "@/theme";

export default function CalendarScreen() {
  const { profile } = useUser();
  const { prioritiesWithStats } = usePriorities();
  const { weekSchedule, deleteTimeBlock, weekLabel, weekOffset } = useTimeBlocks();
  const { tasks } = useTaskStore();

  const hasRemainingHours = prioritiesWithStats.some((p) => p.hoursRemaining > 0);
  const { setSelectedDay, goToPreviousWeek, goToNextWeek, goToCurrentWeek } = usePlannerStore();

  // Track previous state for auto-sync trigger
  const prevAllAllocatedRef = useRef<boolean | null>(null);
  const isSyncingRef = useRef(false);

  // Calculate if all hours are allocated
  const totalRemaining = prioritiesWithStats.reduce((sum, p) => sum + p.hoursRemaining, 0);
  const allAllocated = totalRemaining <= 0 && prioritiesWithStats.length > 0;

  // Auto-sync when all hours become allocated (current week only)
  useEffect(() => {
    const shouldSync =
      profile?.calendarSyncEnabled &&
      weekOffset === 0 &&
      allAllocated &&
      prevAllAllocatedRef.current === false &&
      !isSyncingRef.current;

    if (shouldSync) {
      isSyncingRef.current = true;
      exportWeekToCalendar(weekSchedule, { silent: true, tasks })
        .then((result) => {
          if (!result.success && result.error === "Calendar permission denied") {
            Alert.alert(
              "Calendar Access Required",
              "Please enable calendar access in Settings to use auto-sync."
            );
          }
        })
        .finally(() => {
          isSyncingRef.current = false;
        });
    }

    prevAllAllocatedRef.current = allAllocated;
  }, [allAllocated, profile?.calendarSyncEnabled, weekOffset, weekSchedule, tasks]);

  const handleAddBlock = (dayOfWeek: number) => {
    setSelectedDay(dayOfWeek);
    router.push("/(main)/(calendar)/add-block");
  };

  const handleDeleteBlock = async (id: string) => {
    await deleteTimeBlock(id);
  };

  return (
    <GradientBackground>
      <SafeAreaView style={styles.container} edges={["top"]}>
        <View style={styles.header}>
          <View>
            <Text style={styles.greeting}>Hi, {profile?.name || "there"}!</Text>
            <Text style={styles.subtitle}>Plan your week</Text>
          </View>
          <Pressable
            style={styles.headerButton}
            onPress={() => router.push("/(main)/(calendar)/edit-priorities")}
          >
            <Ionicons name="create-outline" size={24} color={colors.primary.blue} />
          </Pressable>
        </View>

        <View style={styles.weekNav}>
          <Pressable onPress={goToPreviousWeek} style={styles.navButton}>
            <Ionicons name="chevron-back" size={24} color={colors.primary.blue} />
          </Pressable>
          <Pressable onPress={goToCurrentWeek}>
            <Text style={[styles.weekLabel, weekOffset === 0 && styles.weekLabelCurrent]}>
              {weekLabel}
            </Text>
          </Pressable>
          <Pressable onPress={goToNextWeek} style={styles.navButton}>
            <Ionicons name="chevron-forward" size={24} color={colors.primary.blue} />
          </Pressable>
        </View>

        <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
          {weekSchedule.map((day) => (
            <DayCard
              key={day.dayOfWeek}
              day={day}
              onAddBlock={handleAddBlock}
              onDeleteBlock={handleDeleteBlock}
              showAddButton={hasRemainingHours}
            />
          ))}
          <View style={styles.bottomPadding} />
        </ScrollView>
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
    justifyContent: "space-between",
    alignItems: "flex-start",
    paddingHorizontal: spacing.xl,
    paddingTop: spacing.base,
    paddingBottom: spacing.sm,
  },
  headerButton: {
    width: 40,
    height: 40,
    borderRadius: borderRadius.full,
    backgroundColor: colors.surface.elevated,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    borderColor: colors.surface.border,
  },
  greeting: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.bold,
    color: colors.text.primary,
  },
  subtitle: {
    fontSize: typography.fontSize.base,
    color: colors.text.secondary,
    marginTop: spacing.xs,
  },
  weekNav: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
  },
  weekLabel: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.secondary,
  },
  weekLabelCurrent: {
    color: colors.primary.blue,
  },
  scrollView: {
    flex: 1,
    paddingHorizontal: spacing.xl,
  },
  scrollContent: {
    paddingBottom: 100,
  },
  bottomPadding: {
    height: 80,
  },
  navButton: {
    width: 40,
    height: 40,
    alignItems: "center",
    justifyContent: "center",
  },
});
