import { useState, useEffect, useMemo } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  KeyboardAvoidingView,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { usePlannerStore, useUserStore } from "@/stores";
import { usePriorities, useTimeBlocks } from "@/hooks";
import { DAY_NAMES, timeToMinutes, formatHoursAndMinutes, formatTime12Hour, calculateEndTime } from "@/utils";
import { DayOfWeek, PriorityWithStats } from "@/types";
import { TimePicker, TimeValue, timeValueTo24Hour } from "@/components/ui";

export default function AddBlockScreen() {
  const { selectedDay, setSelectedDay } = usePlannerStore();
  const { profile } = useUserStore();
  const { prioritiesWithStats } = usePriorities();
  const { addTimeBlock, weekSchedule } = useTimeBlocks();

  // Only show priorities that have remaining hours
  const availablePriorities = prioritiesWithStats.filter((p) => p.hoursRemaining > 0);

  // Get sleep schedule from profile
  const sleepTime = profile?.sleepTime || "23:00";
  const wakeTime = profile?.wakeTime || "07:00";

  const [selectedPriority, setSelectedPriority] = useState<PriorityWithStats | null>(null);
  const [dayOfWeek, setDayOfWeek] = useState<DayOfWeek>((selectedDay as DayOfWeek) ?? 0);
  const [startTimeValue, setStartTimeValue] = useState<TimeValue>({ hour: 9, minute: 0, isPM: false });
  const [endTimeValue, setEndTimeValue] = useState<TimeValue>({ hour: 10, minute: 0, isPM: false });

  useEffect(() => {
    if (selectedDay !== null) {
      setDayOfWeek(selectedDay as DayOfWeek);
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

  const overlappingBlock = useMemo(() => {
    if (durationMinutes <= 0) return null;

    const daySchedule = weekSchedule.find((d) => d.dayOfWeek === dayOfWeek);
    if (!daySchedule) return null;

    const newStartMinutes = timeToMinutes(startTime);
    const newEndMinutes = newStartMinutes + durationMinutes;

    for (const block of daySchedule.timeBlocks) {
      const blockStartMinutes = timeToMinutes(block.startTime);
      const blockEndMinutes = blockStartMinutes + block.durationMinutes;

      // Check if there's an overlap
      if (newStartMinutes < blockEndMinutes && newEndMinutes > blockStartMinutes) {
        return block;
      }
    }
    return null;
  }, [weekSchedule, dayOfWeek, startTime, durationMinutes]);

  // Check if block overlaps with sleep time
  const overlapsSleep = useMemo(() => {
    if (durationMinutes <= 0) return false;

    const blockStartMinutes = timeToMinutes(startTime);
    const blockEndMinutes = blockStartMinutes + durationMinutes;
    const sleepStartMinutes = timeToMinutes(sleepTime);
    const wakeMinutes = timeToMinutes(wakeTime);

    // Most common case: overnight sleep (e.g., 23:00 to 07:00)
    // sleepStartMinutes (23:00=1380) > wakeMinutes (07:00=420)
    if (sleepStartMinutes > wakeMinutes) {
      // User is awake from wakeMinutes to sleepStartMinutes
      // Block is valid only if it fits entirely within awake period
      const isWithinAwakePeriod = blockStartMinutes >= wakeMinutes && blockEndMinutes <= sleepStartMinutes;
      return !isWithinAwakePeriod;
    } else {
      // Unusual: sleep period within same day (e.g., 01:00 to 09:00)
      // Awake periods: 00:00-sleepStart and wake-24:00
      const isInEarlyAwake = blockEndMinutes <= sleepStartMinutes;
      const isInLateAwake = blockStartMinutes >= wakeMinutes && blockEndMinutes <= 24 * 60;
      return !(isInEarlyAwake || isInLateAwake);
    }
  }, [startTime, durationMinutes, sleepTime, wakeTime]);

  // Check if block duration exceeds remaining hours for selected priority
  const exceedsRemainingHours = useMemo(() => {
    if (!selectedPriority || durationMinutes <= 0) return false;
    const durationHours = durationMinutes / 60;
    return durationHours > selectedPriority.hoursRemaining;
  }, [selectedPriority, durationMinutes]);

  const canSave = selectedPriority && isEndTimeValid && !overlappingBlock && !overlapsSleep && !exceedsRemainingHours;

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView style={styles.keyboardAvoid} behavior="padding" keyboardVerticalOffset={100}>
        <View style={styles.content}>
          <View style={styles.header}>
            <TouchableOpacity onPress={() => router.back()}>
              <Text style={styles.cancelText}>Cancel</Text>
            </TouchableOpacity>
            <Text style={styles.title}>Add Time Block</Text>
            <TouchableOpacity onPress={handleSave} disabled={!canSave}>
              <Text style={[styles.saveText, !canSave && styles.saveTextDisabled]}>
                Save
              </Text>
            </TouchableOpacity>
          </View>

          <ScrollView
            style={styles.form}
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={styles.formContent}
          >
          <Text style={styles.label}>Day</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.dayPicker}>
            <View style={styles.dayRow}>
              {DAY_NAMES.map((name, index) => (
                <TouchableOpacity
                  key={name}
                  onPress={() => setDayOfWeek(index as DayOfWeek)}
                  style={[styles.dayChip, dayOfWeek === index && styles.dayChipActive]}
                >
                  <Text style={[styles.dayChipText, dayOfWeek === index && styles.dayChipTextActive]}>
                    {name.slice(0, 3)}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </ScrollView>

          <Text style={styles.label}>Priority</Text>
          <View style={styles.priorityList}>
            {availablePriorities.map((priority) => (
              <TouchableOpacity
                key={priority.id}
                onPress={() => setSelectedPriority(priority)}
                style={[
                  styles.priorityItem,
                  selectedPriority?.id === priority.id && styles.priorityItemActive,
                ]}
              >
                <View style={[styles.colorDot, { backgroundColor: priority.color }]} />
                <Text style={styles.priorityName}>{priority.name}</Text>
                <Text style={styles.priorityHours}>{formatHoursAndMinutes(priority.hoursRemaining)} left</Text>
              </TouchableOpacity>
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
            <Text style={styles.durationLabel}>Duration:</Text>
            <Text style={[styles.durationValue, !isEndTimeValid && styles.durationValueInvalid]}>
              {durationDisplay}
            </Text>
          </View>

          {overlappingBlock && (
            <View style={styles.overlapWarning}>
              <Text style={styles.overlapWarningText}>
                This time overlaps with {overlappingBlock.priorityName} ({formatTime12Hour(overlappingBlock.startTime)} - {formatTime12Hour(calculateEndTime(overlappingBlock.startTime, overlappingBlock.durationMinutes))})
              </Text>
            </View>
          )}

          {overlapsSleep && (
            <View style={styles.overlapWarning}>
              <Text style={styles.overlapWarningText}>
                This time overlaps with your sleep schedule ({formatTime12Hour(sleepTime)} - {formatTime12Hour(wakeTime)})
              </Text>
            </View>
          )}

          {exceedsRemainingHours && selectedPriority && (
            <View style={styles.overlapWarning}>
              <Text style={styles.overlapWarningText}>
                Duration exceeds remaining hours for "{selectedPriority.name}" by {formatHoursAndMinutes(durationMinutes / 60 - selectedPriority.hoursRemaining)} (only {formatHoursAndMinutes(selectedPriority.hoursRemaining)} left)
              </Text>
            </View>
          )}
          </ScrollView>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#fff",
  },
  keyboardAvoid: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 24,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 24,
  },
  cancelText: {
    color: "#2563eb",
    fontSize: 18,
  },
  title: {
    fontSize: 20,
    fontWeight: "bold",
    color: "#111827",
  },
  saveText: {
    color: "#2563eb",
    fontSize: 18,
    fontWeight: "600",
  },
  saveTextDisabled: {
    color: "#d1d5db",
  },
  form: {
    flex: 1,
  },
  formContent: {
    paddingBottom: 150,
  },
  label: {
    fontSize: 14,
    fontWeight: "500",
    color: "#374151",
    marginBottom: 8,
    marginTop: 16,
  },
  dayPicker: {
    marginBottom: 8,
  },
  dayRow: {
    flexDirection: "row",
    gap: 8,
  },
  dayChip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: "#f3f4f6",
  },
  dayChipActive: {
    backgroundColor: "#2563eb",
  },
  dayChipText: {
    color: "#374151",
  },
  dayChipTextActive: {
    color: "#fff",
  },
  priorityList: {
    marginBottom: 8,
  },
  priorityItem: {
    flexDirection: "row",
    alignItems: "center",
    padding: 16,
    borderRadius: 12,
    backgroundColor: "#f9fafb",
    marginBottom: 8,
  },
  priorityItemActive: {
    backgroundColor: "#eff6ff",
    borderWidth: 2,
    borderColor: "#2563eb",
  },
  colorDot: {
    width: 16,
    height: 16,
    borderRadius: 8,
    marginRight: 12,
  },
  priorityName: {
    flex: 1,
    fontSize: 18,
    color: "#111827",
  },
  priorityHours: {
    color: "#6b7280",
  },
  timePickerContainer: {
    marginTop: 16,
    marginBottom: 8,
  },
  durationDisplay: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#f3f4f6",
    borderRadius: 12,
    paddingVertical: 12,
    paddingHorizontal: 16,
    marginTop: 16,
    gap: 8,
  },
  durationLabel: {
    color: "#6b7280",
    fontSize: 16,
  },
  durationValue: {
    color: "#111827",
    fontSize: 18,
    fontWeight: "600",
  },
  durationValueInvalid: {
    color: "#ef4444",
  },
  overlapWarning: {
    backgroundColor: "#fef2f2",
    borderRadius: 12,
    padding: 16,
    marginTop: 16,
  },
  overlapWarningText: {
    color: "#dc2626",
    textAlign: "center",
  },
});
