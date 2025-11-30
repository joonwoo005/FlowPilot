import { useState, useEffect, useMemo } from "react";
import {
  View,
  Text,
  Pressable,
  ScrollView,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { usePlannerStore, useUserStore } from "@/stores";
import { usePriorities, useTimeBlocks } from "@/hooks";
import { GradientBackground } from "@/components/ui";
import { DAY_NAMES, timeToMinutes, formatHoursAndMinutes, formatTime12Hour, calculateEndTime, minutesToTime } from "@/utils";
import { DayOfWeek, PriorityWithStats } from "@/types";
import { TimePicker, TimeValue, timeValueTo24Hour, timeValueFrom24Hour } from "@/components/ui";
import { colors, typography, spacing, borderRadius } from "@/theme";

export default function AddBlockScreen() {
  const { selectedDay, setSelectedDay } = usePlannerStore();
  const { profile } = useUserStore();
  const { prioritiesWithStats } = usePriorities();
  const { addTimeBlock, weekSchedule } = useTimeBlocks();

  // Only show priorities that have remaining hours (at least 1 minute)
  const availablePriorities = prioritiesWithStats.filter((p) => p.hoursRemaining >= 1 / 60);

  // Get sleep schedule from profile
  const sleepTime = profile?.sleepTime || "23:00";
  const wakeTime = profile?.wakeTime || "07:00";

  const [selectedPriority, setSelectedPriority] = useState<PriorityWithStats | null>(null);
  const [dayOfWeek, setDayOfWeek] = useState<DayOfWeek>((selectedDay as DayOfWeek) ?? 0);

  // Calculate smart default start time based on existing blocks
  const getSmartDefaultTime = (day: DayOfWeek): { start: TimeValue; end: TimeValue } => {
    const daySchedule = weekSchedule.find((d) => d.dayOfWeek === day);

    if (!daySchedule || daySchedule.timeBlocks.length === 0) {
      // No blocks - default to 9:00 AM - 10:00 AM
      return {
        start: { hour: 9, minute: 0, isPM: false },
        end: { hour: 10, minute: 0, isPM: false },
      };
    }

    // Find the latest ending block
    let latestEndMinutes = 0;
    for (const block of daySchedule.timeBlocks) {
      const blockStart = timeToMinutes(block.startTime);
      const blockEnd = blockStart + block.durationMinutes;
      if (blockEnd > latestEndMinutes) {
        latestEndMinutes = blockEnd;
      }
    }

    // Cap at 23:00 if past midnight
    if (latestEndMinutes >= 24 * 60) {
      latestEndMinutes = 23 * 60;
    }

    const startTime24 = minutesToTime(latestEndMinutes);
    const endMinutes = Math.min(latestEndMinutes + 60, 24 * 60 - 1); // +1 hour, max 23:59
    const endTime24 = minutesToTime(endMinutes);

    return {
      start: timeValueFrom24Hour(startTime24),
      end: timeValueFrom24Hour(endTime24),
    };
  };

  const defaultTimes = getSmartDefaultTime((selectedDay as DayOfWeek) ?? 0);
  const [startTimeValue, setStartTimeValue] = useState<TimeValue>(defaultTimes.start);
  const [endTimeValue, setEndTimeValue] = useState<TimeValue>(defaultTimes.end);

  useEffect(() => {
    if (selectedDay !== null) {
      setDayOfWeek(selectedDay as DayOfWeek);
      // Update default times when day changes
      const newDefaults = getSmartDefaultTime(selectedDay as DayOfWeek);
      setStartTimeValue(newDefaults.start);
      setEndTimeValue(newDefaults.end);
    }
  }, [selectedDay]);

  // Convert TimeValue to 24-hour format string for internal use
  const startTime = useMemo(() => timeValueTo24Hour(startTimeValue), [startTimeValue]);
  const endTime = useMemo(() => timeValueTo24Hour(endTimeValue), [endTimeValue]);

  // Calculate duration in minutes from start and end times
  const durationMinutes = useMemo(() => {
    const startMinutes = timeToMinutes(startTime);
    const endMinutes = timeToMinutes(endTime);

    // Handle case where end time is after midnight (next day)
    if (endMinutes <= startMinutes) {
      return (24 * 60 - startMinutes) + endMinutes;
    }
    return endMinutes - startMinutes;
  }, [startTime, endTime]);

  // Check if end time is valid (after start time or wraps to next day)
  const isEndTimeValid = durationMinutes > 0 && durationMinutes <= 24 * 60;

  // Check if block crosses midnight
  const crossesMidnight = useMemo(() => {
    const endMins = timeToMinutes(endTime);
    const startMins = timeToMinutes(startTime);
    return endMins <= startMins && durationMinutes > 0;
  }, [startTime, endTime, durationMinutes]);

  // Get blocks for the next day (for midnight-crossing overlap check)
  const nextDayBlocks = useMemo(() => {
    const nextDay = (dayOfWeek + 1) % 7;
    const nextDaySchedule = weekSchedule.find((d) => d.dayOfWeek === nextDay);
    return nextDaySchedule?.timeBlocks || [];
  }, [weekSchedule, dayOfWeek]);

  // Format duration for display
  const durationDisplay = useMemo(() => {
    if (durationMinutes <= 0) return "Invalid";
    const hours = Math.floor(durationMinutes / 60);
    const mins = durationMinutes % 60;
    if (hours === 0) return `${mins}m`;
    if (mins === 0) return `${hours}h`;
    return `${hours}h ${mins}m`;
  }, [durationMinutes]);

  const handleStartTimeChange = (newTime: TimeValue) => {
    setStartTimeValue(newTime);
  };

  const handleEndTimeChange = (newTime: TimeValue) => {
    setEndTimeValue(newTime);
  };

  const handleSave = () => {
    if (!selectedPriority) return;

    // Navigate back immediately
    setSelectedDay(null);
    router.back();

    // Save in background
    addTimeBlock({
      priorityId: selectedPriority.id,
      priorityName: selectedPriority.name,
      dayOfWeek,
      startTime,
      durationMinutes,
    }).catch((error) => {
      console.error("Failed to add time block:", error);
    });
  };

  // Enhanced overlap detection that handles midnight-crossing blocks
  const overlappingBlock = useMemo(() => {
    if (durationMinutes <= 0) return null;

    const daySchedule = weekSchedule.find((d) => d.dayOfWeek === dayOfWeek);
    if (!daySchedule) return null;

    const newStartMinutes = timeToMinutes(startTime);

    if (crossesMidnight) {
      // Check current day portion (startTime to midnight)
      const currentDayEnd = 24 * 60;
      for (const block of daySchedule.timeBlocks) {
        const blockStartMinutes = timeToMinutes(block.startTime);
        const blockEndMinutes = blockStartMinutes + block.durationMinutes;

        if (newStartMinutes < blockEndMinutes && currentDayEnd > blockStartMinutes) {
          const overlapStart = Math.max(newStartMinutes, blockStartMinutes);
          const overlapEnd = Math.min(currentDayEnd, blockEndMinutes);
          if (overlapEnd > overlapStart) {
            return block;
          }
        }
      }

      // Check next day portion (midnight to endTime)
      const nextDayEnd = timeToMinutes(endTime);
      for (const block of nextDayBlocks) {
        const blockStartMinutes = timeToMinutes(block.startTime);
        const blockEndMinutes = blockStartMinutes + block.durationMinutes;

        if (0 < blockEndMinutes && nextDayEnd > blockStartMinutes) {
          const overlapStart = Math.max(0, blockStartMinutes);
          const overlapEnd = Math.min(nextDayEnd, blockEndMinutes);
          if (overlapEnd > overlapStart) {
            return block;
          }
        }
      }
    } else {
      // Normal case: check current day only
      const newEndMinutes = newStartMinutes + durationMinutes;

      for (const block of daySchedule.timeBlocks) {
        const blockStartMinutes = timeToMinutes(block.startTime);
        const blockEndMinutes = blockStartMinutes + block.durationMinutes;

        if (newStartMinutes < blockEndMinutes && newEndMinutes > blockStartMinutes) {
          return block;
        }
      }
    }
    return null;
  }, [weekSchedule, dayOfWeek, startTime, endTime, durationMinutes, crossesMidnight, nextDayBlocks]);

  // Enhanced sleep overlap detection that handles midnight-crossing blocks
  const sleepOverlapMinutes = useMemo(() => {
    if (durationMinutes <= 0) return 0;

    const blockStartMinutes = timeToMinutes(startTime);
    const sleepStartMinutes = timeToMinutes(sleepTime);
    const wakeMinutes = timeToMinutes(wakeTime);

    let overlapMinutes = 0;

    if (crossesMidnight) {
      // Overnight block: check both portions separately
      const endMinutes = timeToMinutes(endTime);

      if (sleepStartMinutes > wakeMinutes) {
        // Sleep spans midnight (e.g., 22:00 to 06:00)
        // Part 1: Current day evening (blockStart to midnight) vs evening sleep (sleepStart to midnight)
        if (blockStartMinutes < 24 * 60 && sleepStartMinutes < 24 * 60) {
          const overlapStart = Math.max(blockStartMinutes, sleepStartMinutes);
          const overlapEnd = 24 * 60;
          if (overlapStart < overlapEnd) {
            overlapMinutes += overlapEnd - overlapStart;
          }
        }

        // Part 2: Next day morning (midnight to endTime) vs morning sleep (midnight to wake)
        if (endMinutes > 0 && wakeMinutes > 0) {
          const overlapEnd = Math.min(endMinutes, wakeMinutes);
          if (overlapEnd > 0) {
            overlapMinutes += overlapEnd;
          }
        }
      }
    } else {
      // Normal same-day block
      const blockEndMinutes = blockStartMinutes + durationMinutes;

      if (sleepStartMinutes > wakeMinutes) {
        // Sleep spans midnight (e.g., 22:00 to 06:00)
        // Check overlap with evening sleep (sleepStart to midnight)
        if (blockEndMinutes > sleepStartMinutes) {
          const overlapStart = Math.max(blockStartMinutes, sleepStartMinutes);
          const overlapEnd = Math.min(blockEndMinutes, 24 * 60);
          overlapMinutes += Math.max(0, overlapEnd - overlapStart);
        }

        // Check overlap with morning sleep (midnight to wake)
        if (blockStartMinutes < wakeMinutes) {
          const overlapStart = Math.max(blockStartMinutes, 0);
          const overlapEnd = Math.min(blockEndMinutes, wakeMinutes);
          overlapMinutes += Math.max(0, overlapEnd - overlapStart);
        }
      } else {
        // Sleep within same day (rare)
        if (blockStartMinutes < wakeMinutes && blockEndMinutes > sleepStartMinutes) {
          const overlapStart = Math.max(blockStartMinutes, sleepStartMinutes);
          const overlapEnd = Math.min(blockEndMinutes, wakeMinutes);
          overlapMinutes = Math.max(0, overlapEnd - overlapStart);
        }
      }
    }

    return overlapMinutes;
  }, [startTime, endTime, durationMinutes, sleepTime, wakeTime, crossesMidnight]);

  const overlapsSleep = sleepOverlapMinutes > 0;

  // Check if block duration exceeds remaining hours for selected priority
  const exceedsRemainingHours = useMemo(() => {
    if (!selectedPriority || durationMinutes <= 0) return false;
    const durationHours = durationMinutes / 60;
    return durationHours > selectedPriority.hoursRemaining;
  }, [selectedPriority, durationMinutes]);

  const canSave = selectedPriority && isEndTimeValid && !overlappingBlock && !overlapsSleep && !exceedsRemainingHours;

  return (
    <GradientBackground>
      <SafeAreaView style={styles.container} edges={["top"]}>
        <KeyboardAvoidingView
          style={styles.keyboardAvoid}
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          keyboardVerticalOffset={100}
        >
          <View style={styles.content}>
            <View style={styles.header}>
              <Pressable onPress={() => router.back()}>
                <Text style={styles.cancelText}>Cancel</Text>
              </Pressable>
              <Text style={styles.title}>Add Time Block</Text>
              <Pressable onPress={handleSave} disabled={!canSave}>
                <Text style={[styles.saveText, !canSave && styles.saveTextDisabled]}>
                  Save
                </Text>
              </Pressable>
            </View>

            <ScrollView
              style={styles.form}
              keyboardShouldPersistTaps="handled"
              contentContainerStyle={styles.formContent}
              showsVerticalScrollIndicator={false}
            >
              <Text style={styles.label}>DAY</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.dayPicker}>
                <View style={styles.dayRow}>
                  {DAY_NAMES.map((name, index) => (
                    <Pressable
                      key={name}
                      onPress={() => setDayOfWeek(index as DayOfWeek)}
                      style={[styles.dayChip, dayOfWeek === index && styles.dayChipActive]}
                    >
                      <Text style={[styles.dayChipText, dayOfWeek === index && styles.dayChipTextActive]}>
                        {name.slice(0, 3)}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </ScrollView>

              <Text style={styles.label}>PRIORITY</Text>
              <View style={styles.priorityList}>
                {availablePriorities.map((priority) => (
                  <Pressable
                    key={priority.id}
                    onPress={() => setSelectedPriority(priority)}
                    style={[
                      styles.priorityItem,
                      selectedPriority?.id === priority.id && styles.priorityItemActive,
                      selectedPriority?.id === priority.id && { borderColor: priority.color },
                    ]}
                  >
                    <View style={[styles.colorDot, { backgroundColor: priority.color }]} />
                    <Text style={styles.priorityName}>{priority.name}</Text>
                    <Text style={styles.priorityHours}>{formatHoursAndMinutes(priority.hoursRemaining)} left</Text>
                  </Pressable>
                ))}
              </View>

              <View style={styles.timePickerContainer}>
                <TimePicker
                  label="Start Time"
                  value={startTimeValue}
                  onChange={handleStartTimeChange}
                  accessibilityLabel="Select start time for time block"
                />
              </View>

              <View style={styles.timePickerContainer}>
                <TimePicker
                  label="End Time"
                  value={endTimeValue}
                  onChange={handleEndTimeChange}
                  accessibilityLabel="Select end time for time block"
                />
              </View>

              <View style={styles.durationDisplay}>
                <Ionicons name="time-outline" size={16} color={colors.text.secondary} />
                <Text style={styles.durationLabel}>Duration:</Text>
                <Text style={[styles.durationValue, !isEndTimeValid && styles.durationValueInvalid]}>
                  {durationDisplay}
                </Text>
              </View>

              {/* Info banner for midnight-crossing blocks */}
              {crossesMidnight && isEndTimeValid && (
                <View style={styles.infoBanner}>
                  <Ionicons name="information-circle" size={16} color={colors.primary.blue} />
                  <Text style={styles.infoBannerText}>
                    This block will be split across two days
                  </Text>
                </View>
              )}

              {overlappingBlock && (
                <View style={styles.overlapWarning}>
                  <Ionicons name="warning" size={16} color={colors.status.warning} />
                  <Text style={styles.overlapWarningText}>
                    Overlaps with {overlappingBlock.priorityName} ({formatTime12Hour(overlappingBlock.startTime)} - {formatTime12Hour(calculateEndTime(overlappingBlock.startTime, overlappingBlock.durationMinutes))})
                  </Text>
                </View>
              )}

              {overlapsSleep && (
                <View style={styles.overlapWarning}>
                  <Ionicons name="warning" size={16} color={colors.status.warning} />
                  <Text style={styles.overlapWarningText}>
                    Overlaps with sleep by {formatHoursAndMinutes(sleepOverlapMinutes / 60)} ({formatTime12Hour(sleepTime)} - {formatTime12Hour(wakeTime)})
                  </Text>
                </View>
              )}

              {exceedsRemainingHours && selectedPriority && (
                <View style={styles.overlapWarning}>
                  <Ionicons name="warning" size={16} color={colors.status.warning} />
                  <Text style={styles.overlapWarningText}>
                    Exceeds remaining time for "{selectedPriority.name}" by {formatHoursAndMinutes(durationMinutes / 60 - selectedPriority.hoursRemaining)}
                  </Text>
                </View>
              )}
            </ScrollView>
          </View>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  keyboardAvoid: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: spacing.xl,
    paddingTop: spacing.xl,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: spacing.xl,
  },
  cancelText: {
    color: colors.text.secondary,
    fontSize: typography.fontSize.md,
  },
  title: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.bold,
    color: colors.text.primary,
  },
  saveText: {
    color: colors.primary.blue,
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
  },
  saveTextDisabled: {
    color: colors.text.muted,
  },
  form: {
    flex: 1,
  },
  formContent: {
    paddingBottom: 150,
  },
  label: {
    fontSize: typography.fontSize.xs,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.muted,
    letterSpacing: 1,
    marginBottom: spacing.sm,
    marginTop: spacing.base,
  },
  dayPicker: {
    marginBottom: spacing.sm,
  },
  dayRow: {
    flexDirection: "row",
    gap: spacing.sm,
  },
  dayChip: {
    paddingHorizontal: spacing.base,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.full,
    backgroundColor: colors.surface.secondary,
    borderWidth: 1,
    borderColor: colors.surface.border,
  },
  dayChipActive: {
    backgroundColor: colors.primary.blue,
    borderColor: colors.primary.blue,
  },
  dayChipText: {
    color: colors.text.secondary,
    fontWeight: typography.fontWeight.medium,
  },
  dayChipTextActive: {
    color: colors.text.primary,
  },
  priorityList: {
    marginBottom: spacing.sm,
  },
  priorityItem: {
    flexDirection: "row",
    alignItems: "center",
    padding: spacing.base,
    borderRadius: borderRadius.lg,
    backgroundColor: colors.surface.primary,
    borderWidth: 1,
    borderColor: colors.surface.border,
    marginBottom: spacing.sm,
  },
  priorityItemActive: {
    backgroundColor: colors.surface.elevated,
    borderWidth: 2,
  },
  colorDot: {
    width: 16,
    height: 16,
    borderRadius: 8,
    marginRight: spacing.md,
  },
  priorityName: {
    flex: 1,
    fontSize: typography.fontSize.md,
    color: colors.text.primary,
    fontWeight: typography.fontWeight.medium,
  },
  priorityHours: {
    color: colors.text.secondary,
    fontSize: typography.fontSize.sm,
  },
  timePickerContainer: {
    marginTop: spacing.base,
    marginBottom: spacing.sm,
  },
  durationDisplay: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.surface.secondary,
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: colors.surface.border,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.base,
    marginTop: spacing.base,
    gap: spacing.sm,
  },
  durationLabel: {
    color: colors.text.secondary,
    fontSize: typography.fontSize.base,
  },
  durationValue: {
    color: colors.text.primary,
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
  },
  durationValueInvalid: {
    color: colors.status.error,
  },
  infoBanner: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(59, 130, 246, 0.15)",
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: "rgba(59, 130, 246, 0.3)",
    padding: spacing.base,
    marginTop: spacing.base,
    gap: spacing.sm,
  },
  infoBannerText: {
    flex: 1,
    color: colors.primary.blue,
    fontSize: typography.fontSize.sm,
  },
  overlapWarning: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(245, 158, 11, 0.15)",
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: "rgba(245, 158, 11, 0.3)",
    padding: spacing.base,
    marginTop: spacing.base,
    gap: spacing.sm,
  },
  overlapWarningText: {
    flex: 1,
    color: colors.status.warning,
    fontSize: typography.fontSize.sm,
  },
});
