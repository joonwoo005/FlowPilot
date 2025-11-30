import { useState, useEffect } from "react";
import {
  View,
  Text,
  TextInput,
  Pressable,
  FlatList,
  KeyboardAvoidingView,
  StyleSheet,
  Alert,
  Modal,
  Switch,
  Platform,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import DateTimePicker from "@react-native-community/datetimepicker";
import { useAuthStore, useUserStore } from "@/stores";
import { priorityRepository, userRepository } from "@/services/repositories";
import { Priority } from "@/types";
import { GradientBackground, KeyboardDoneBar } from "@/components/ui";
import { useTimeBlocks } from "@/hooks";
import { exportWeekToCalendar } from "@/services/calendar.service";
import { colors, typography, spacing, borderRadius } from "@/theme";

const INPUT_ACCESSORY_ID = "editPrioritiesInput";

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

interface EditablePriority extends Priority {
  allocatedHours: number;
  isEditing: boolean;
  editName: string;
}

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

const calculateAwakeHours = (wake: string, sleep: string): number => {
  const [wakeH, wakeM] = wake.split(":").map(Number);
  const [sleepH, sleepM] = sleep.split(":").map(Number);

  let wakeMinutes = wakeH * 60 + wakeM;
  let sleepMinutes = sleepH * 60 + sleepM;

  if (sleepMinutes <= wakeMinutes) {
    sleepMinutes += 24 * 60;
  }

  return (sleepMinutes - wakeMinutes) / 60;
};

export default function EditPrioritiesScreen() {
  const [input, setInput] = useState("");
  const [priorities, setPriorities] = useState<EditablePriority[]>([]);
  const { user } = useAuthStore();
  const { profile } = useUserStore();

  const [wakeTime, setWakeTime] = useState(profile?.wakeTime || "07:00");
  const [sleepTime, setSleepTime] = useState(profile?.sleepTime || "23:00");
  const [showWakePicker, setShowWakePicker] = useState(false);
  const [showSleepPicker, setShowSleepPicker] = useState(false);
  const [tempTime, setTempTime] = useState("07:00");

  const [calendarSyncEnabled, setCalendarSyncEnabled] = useState(
    profile?.calendarSyncEnabled ?? false
  );
  const [isSyncing, setIsSyncing] = useState(false);
  const { weekSchedule, weekOffset } = useTimeBlocks();

  useEffect(() => {
    if (profile?.wakeTime) setWakeTime(profile.wakeTime);
    if (profile?.sleepTime) setSleepTime(profile.sleepTime);
  }, [profile?.wakeTime, profile?.sleepTime]);

  useEffect(() => {
    if (profile?.calendarSyncEnabled !== undefined) {
      setCalendarSyncEnabled(profile.calendarSyncEnabled);
    }
  }, [profile?.calendarSyncEnabled]);

  const awakeHoursPerDay = calculateAwakeHours(wakeTime, sleepTime);
  const weeklyAwakeHours = Math.round(awakeHoursPerDay * 7);

  useEffect(() => {
    if (!user?.uid) return;

    const unsubscribe = priorityRepository.subscribeAll(user.uid, (data) => {
      setPriorities(
        data.map((p) => ({
          ...p,
          allocatedHours: p.weeklyHoursTarget,
          isEditing: false,
          editName: p.name,
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

  const handleAddPriority = async () => {
    if (!input.trim() || !user?.uid) return;

    const priorityName = input.trim();
    setInput("");

    try {
      const color = PRIORITY_COLORS[priorities.length % PRIORITY_COLORS.length];
      await priorityRepository.createWithOrder(
        user.uid,
        { name: priorityName, color },
        priorities.length
      );
    } catch (error) {
      console.error("Failed to add priority:", error);
    }
  };

  const handleDeletePriority = (id: string, name: string) => {
    Alert.alert(
      "Delete Priority",
      `Are you sure you want to delete "${name}"? This will also delete all associated time blocks.`,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: async () => {
            if (!user?.uid) return;
            try {
              await priorityRepository.delete(user.uid, id);
            } catch (error) {
              console.error("Failed to delete priority:", error);
            }
          },
        },
      ]
    );
  };

  const handleStartEditing = (id: string) => {
    setPriorities((prev) =>
      prev.map((p) =>
        p.id === id ? { ...p, isEditing: true, editName: p.name } : p
      )
    );
  };

  const handleCancelEditing = (id: string) => {
    setPriorities((prev) =>
      prev.map((p) =>
        p.id === id ? { ...p, isEditing: false, editName: p.name } : p
      )
    );
  };

  const handleSaveName = async (id: string) => {
    const priority = priorities.find((p) => p.id === id);
    if (!priority || !user?.uid || !priority.editName.trim()) return;

    setPriorities((prev) =>
      prev.map((p) =>
        p.id === id ? { ...p, isEditing: false, name: p.editName.trim() } : p
      )
    );

    try {
      await priorityRepository.update(user.uid, id, { name: priority.editName.trim() });
    } catch (error) {
      console.error("Failed to update priority name:", error);
    }
  };

  const handleNameChange = (id: string, name: string) => {
    setPriorities((prev) =>
      prev.map((p) => (p.id === id ? { ...p, editName: name } : p))
    );
  };

  const handleHoursChange = async (id: string, hours: string) => {
    const numHours = Math.max(0, parseInt(hours) || 0);
    setPriorities((prev) =>
      prev.map((p) => (p.id === id ? { ...p, allocatedHours: numHours } : p))
    );

    if (user?.uid) {
      try {
        await priorityRepository.updateWeeklyHours(user.uid, id, numHours);
      } catch (error) {
        console.error("Failed to save hours:", error);
      }
    }
  };

  const handleTimeChange = (_: any, selectedDate?: Date) => {
    if (selectedDate) {
      setTempTime(dateToTimeString(selectedDate));
    }
  };

  const openWakePicker = () => {
    setTempTime(wakeTime);
    setShowWakePicker(true);
  };

  const openSleepPicker = () => {
    setTempTime(sleepTime);
    setShowSleepPicker(true);
  };

  const confirmWakeTime = async () => {
    setWakeTime(tempTime);
    setShowWakePicker(false);
    await saveSleepSchedule(tempTime, sleepTime);
  };

  const confirmSleepTime = async () => {
    setSleepTime(tempTime);
    setShowSleepPicker(false);
    await saveSleepSchedule(wakeTime, tempTime);
  };

  const saveSleepSchedule = async (wake: string, sleep: string) => {
    if (!user?.uid) return;
    const awakeHours = calculateAwakeHours(wake, sleep);
    try {
      await userRepository.updateSleepSchedule(user.uid, sleep, wake, awakeHours);
    } catch (error) {
      console.error("Failed to save sleep schedule:", error);
    }
  };

  const handleCalendarSyncToggle = async (enabled: boolean) => {
    if (!user?.uid) return;

    setCalendarSyncEnabled(enabled);

    try {
      await userRepository.updateCalendarSyncEnabled(user.uid, enabled);

      if (enabled && weekOffset === 0) {
        setIsSyncing(true);
        const result = await exportWeekToCalendar(weekSchedule);
        setIsSyncing(false);

        if (!result.success) {
          if (result.error === "Calendar permission denied") {
            Alert.alert(
              "Permission Required",
              "Calendar access is required. Please enable it in Settings.",
              [{ text: "OK" }]
            );
            setCalendarSyncEnabled(false);
            await userRepository.updateCalendarSyncEnabled(user.uid, false);
          } else {
            Alert.alert("Sync Failed", result.error || "Unknown error occurred");
          }
        }
      }
    } catch (error) {
      console.error("Failed to update calendar sync setting:", error);
      setCalendarSyncEnabled(!enabled);
    }
  };

  return (
    <GradientBackground>
      <SafeAreaView style={styles.container} edges={["top"]}>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          style={styles.flex}
        >
          <View style={styles.header}>
            <Pressable onPress={() => router.back()}>
              <Ionicons name="close" size={28} color={colors.text.secondary} />
            </Pressable>
            <Text style={styles.title}>Edit Priorities</Text>
            <Pressable onPress={() => router.back()}>
              <Ionicons name="checkmark" size={28} color={colors.primary.blue} />
            </Pressable>
          </View>

          <View style={styles.content}>
            <View style={styles.sleepBox}>
              <Text style={styles.sleepTitle}>Sleep Schedule</Text>
              <View style={styles.sleepRow}>
                <View style={styles.sleepItem}>
                  <Text style={styles.sleepLabel}>Wake up</Text>
                  <Pressable style={styles.timeButton} onPress={openWakePicker}>
                    <Text style={styles.timeButtonText}>{wakeTime}</Text>
                  </Pressable>
                </View>
                <View style={styles.sleepItem}>
                  <Text style={styles.sleepLabel}>Sleep</Text>
                  <Pressable style={styles.timeButton} onPress={openSleepPicker}>
                    <Text style={styles.timeButtonText}>{sleepTime}</Text>
                  </Pressable>
                </View>
              </View>
              <View style={styles.hoursRow}>
                <Text style={styles.hoursText}>
                  <Text style={styles.hoursValue}>{awakeHoursPerDay.toFixed(1)}</Text> awake
                </Text>
                <Text style={styles.hoursDivider}>•</Text>
                <Text style={styles.hoursText}>
                  <Text style={styles.hoursValue}>{(24 - awakeHoursPerDay).toFixed(1)}</Text> sleep
                </Text>
              </View>
            </View>

            <View style={styles.summaryBox}>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Weekly hours:</Text>
                <Text style={styles.summaryValue}>{weeklyAwakeHours}h</Text>
              </View>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Allocated:</Text>
                <Text style={styles.summaryValue}>{totalAllocated}h</Text>
              </View>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Remaining:</Text>
                <Text
                  style={[
                    styles.summaryValue,
                    remainingHours < 0 ? styles.textRed : styles.textGreen,
                  ]}
                >
                  {remainingHours}h
                </Text>
              </View>
            </View>

            <View style={styles.calendarSyncBox}>
              <View style={styles.calendarSyncHeader}>
                <Ionicons name="calendar-outline" size={18} color={colors.primary.purple} />
                <Text style={styles.calendarSyncTitle}>Calendar Sync</Text>
              </View>
              <View style={styles.calendarSyncRow}>
                <View style={styles.calendarSyncTextContainer}>
                  <Text style={styles.calendarSyncLabel}>Sync to Apple Calendar</Text>
                  <Text style={styles.calendarSyncHelper}>
                    Auto-syncs when all hours are allocated
                  </Text>
                </View>
                <Switch
                  value={calendarSyncEnabled}
                  onValueChange={handleCalendarSyncToggle}
                  trackColor={{ false: colors.surface.border, true: colors.primary.purple + "80" }}
                  thumbColor={calendarSyncEnabled ? colors.primary.purple : colors.text.muted}
                  disabled={isSyncing}
                />
              </View>
              {isSyncing && (
                <Text style={styles.syncingText}>Syncing to calendar...</Text>
              )}
            </View>

            <View style={styles.inputRow}>
              <TextInput
                style={styles.input}
                placeholder="Add new priority..."
                placeholderTextColor={colors.text.muted}
                value={input}
                onChangeText={setInput}
                onSubmitEditing={handleAddPriority}
                blurOnSubmit={false}
                returnKeyType="done"
                inputAccessoryViewID={INPUT_ACCESSORY_ID}
              />
              <Pressable
                style={[styles.addButton, !input.trim() && styles.buttonDisabled]}
                onPress={handleAddPriority}
                disabled={!input.trim()}
              >
                <Ionicons name="add" size={24} color={colors.text.primary} />
              </Pressable>
            </View>

            <FlatList
              data={priorities}
              keyExtractor={(item) => item.id}
              style={styles.list}
              showsVerticalScrollIndicator={false}
              renderItem={({ item }) => (
                <View style={styles.priorityItem}>
                  <View style={[styles.colorDot, { backgroundColor: item.color }]} />

                  {item.isEditing ? (
                    <View style={styles.editNameContainer}>
                      <TextInput
                        style={styles.editNameInput}
                        value={item.editName}
                        onChangeText={(text) => handleNameChange(item.id, text)}
                        autoFocus
                        onSubmitEditing={() => handleSaveName(item.id)}
                        inputAccessoryViewID={INPUT_ACCESSORY_ID}
                        placeholderTextColor={colors.text.muted}
                      />
                      <Pressable onPress={() => handleSaveName(item.id)}>
                        <Ionicons name="checkmark" size={24} color={colors.status.success} />
                      </Pressable>
                      <Pressable onPress={() => handleCancelEditing(item.id)}>
                        <Ionicons name="close" size={24} color={colors.text.secondary} />
                      </Pressable>
                    </View>
                  ) : (
                    <Pressable
                      style={styles.nameContainer}
                      onPress={() => handleStartEditing(item.id)}
                    >
                      <Text style={styles.priorityName}>{item.name}</Text>
                      <Ionicons name="pencil" size={16} color={colors.text.muted} />
                    </Pressable>
                  )}

                  <View style={styles.hoursInput}>
                    <TextInput
                      style={styles.hoursInputField}
                      keyboardType="number-pad"
                      value={item.allocatedHours === 0 ? "" : item.allocatedHours.toString()}
                      onChangeText={(text) => handleHoursChange(item.id, text)}
                      placeholder="0"
                      placeholderTextColor={colors.text.muted}
                      inputAccessoryViewID={INPUT_ACCESSORY_ID}
                    />
                    <Text style={styles.hoursLabel}>h</Text>
                  </View>

                  <Pressable
                    onPress={() => handleDeletePriority(item.id, item.name)}
                    style={styles.deleteButton}
                  >
                    <Ionicons name="trash-outline" size={20} color={colors.status.error} />
                  </Pressable>
                </View>
              )}
              ListEmptyComponent={
                <View style={styles.emptyState}>
                  <Text style={styles.emptyText}>No priorities yet</Text>
                </View>
              }
            />

            {remainingHours < 0 && (
              <View style={styles.warningBox}>
                <Text style={styles.warningText}>
                  You've allocated more hours than available!
                </Text>
              </View>
            )}
          </View>
        </KeyboardAvoidingView>

        <Modal visible={showWakePicker} transparent animationType="slide">
          <View style={styles.modalOverlay}>
            <View style={styles.modalContent}>
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
                value={timeStringToDate(tempTime)}
                mode="time"
                is24Hour={true}
                display="spinner"
                onChange={handleTimeChange}
                themeVariant="dark"
              />
            </View>
          </View>
        </Modal>

        <Modal visible={showSleepPicker} transparent animationType="slide">
          <View style={styles.modalOverlay}>
            <View style={styles.modalContent}>
              <View style={styles.modalHeader}>
                <Pressable onPress={() => setShowSleepPicker(false)}>
                  <Text style={styles.modalCancel}>Cancel</Text>
                </Pressable>
                <Text style={styles.modalTitle}>Sleep Time</Text>
                <Pressable onPress={confirmSleepTime}>
                  <Text style={styles.modalDone}>Done</Text>
                </Pressable>
              </View>
              <DateTimePicker
                value={timeStringToDate(tempTime)}
                mode="time"
                is24Hour={true}
                display="spinner"
                onChange={handleTimeChange}
                themeVariant="dark"
              />
            </View>
          </View>
        </Modal>

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
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.base,
    borderBottomWidth: 1,
    borderBottomColor: colors.surface.border,
  },
  title: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  content: {
    flex: 1,
    paddingHorizontal: spacing.xl,
    paddingTop: spacing.base,
  },
  sleepBox: {
    backgroundColor: colors.primary.blue + "15",
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: colors.primary.blue + "30",
    padding: spacing.base,
    marginBottom: spacing.base,
  },
  sleepTitle: {
    fontSize: typography.fontSize.sm,
    fontWeight: typography.fontWeight.semibold,
    color: colors.primary.blue,
    marginBottom: spacing.md,
  },
  sleepRow: {
    flexDirection: "row",
    gap: spacing.base,
  },
  sleepItem: {
    flex: 1,
  },
  sleepLabel: {
    fontSize: typography.fontSize.xs,
    color: colors.text.secondary,
    marginBottom: spacing.xs,
  },
  timeButton: {
    backgroundColor: colors.surface.elevated,
    borderWidth: 1,
    borderColor: colors.surface.border,
    borderRadius: borderRadius.md,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.base,
    alignItems: "center",
  },
  timeButtonText: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.medium,
    color: colors.text.primary,
  },
  hoursRow: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    marginTop: spacing.md,
    gap: spacing.sm,
  },
  hoursText: {
    fontSize: typography.fontSize.sm,
    color: colors.primary.blue,
  },
  hoursValue: {
    fontWeight: typography.fontWeight.semibold,
  },
  hoursDivider: {
    color: colors.primary.blue + "60",
    fontSize: typography.fontSize.sm,
  },
  summaryBox: {
    backgroundColor: colors.surface.primary,
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: colors.surface.border,
    padding: spacing.base,
    marginBottom: spacing.base,
  },
  calendarSyncBox: {
    backgroundColor: colors.primary.purple + "15",
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: colors.primary.purple + "30",
    padding: spacing.base,
    marginBottom: spacing.base,
  },
  calendarSyncHeader: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
    marginBottom: spacing.md,
  },
  calendarSyncTitle: {
    fontSize: typography.fontSize.sm,
    fontWeight: typography.fontWeight.semibold,
    color: colors.primary.purple,
  },
  calendarSyncRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  calendarSyncTextContainer: {
    flex: 1,
    marginRight: spacing.md,
  },
  calendarSyncLabel: {
    fontSize: typography.fontSize.base,
    color: colors.text.primary,
    fontWeight: typography.fontWeight.medium,
  },
  calendarSyncHelper: {
    fontSize: typography.fontSize.xs,
    color: colors.text.secondary,
    marginTop: 2,
  },
  syncingText: {
    fontSize: typography.fontSize.xs,
    color: colors.primary.purple,
    marginTop: spacing.sm,
    fontStyle: "italic",
  },
  summaryRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: spacing.xs,
  },
  summaryLabel: {
    color: colors.text.secondary,
    fontSize: typography.fontSize.sm,
  },
  summaryValue: {
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
    fontSize: typography.fontSize.sm,
  },
  textRed: {
    color: colors.status.error,
  },
  textGreen: {
    color: colors.status.success,
  },
  inputRow: {
    flexDirection: "row",
    marginBottom: spacing.base,
    gap: spacing.sm,
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.surface.border,
    backgroundColor: colors.surface.primary,
    borderRadius: borderRadius.lg,
    paddingHorizontal: spacing.base,
    paddingVertical: spacing.md,
    fontSize: typography.fontSize.base,
    color: colors.text.primary,
  },
  addButton: {
    backgroundColor: colors.primary.blue,
    borderRadius: borderRadius.lg,
    paddingHorizontal: spacing.base,
    justifyContent: "center",
  },
  buttonDisabled: {
    backgroundColor: colors.surface.secondary,
  },
  list: {
    flex: 1,
  },
  priorityItem: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: colors.surface.primary,
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: colors.surface.border,
    padding: spacing.md,
    marginBottom: spacing.sm,
  },
  colorDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: spacing.md,
  },
  nameContainer: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
  },
  editNameContainer: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
  },
  editNameInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.primary.blue,
    backgroundColor: colors.surface.elevated,
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    fontSize: typography.fontSize.base,
    color: colors.text.primary,
  },
  priorityName: {
    fontSize: typography.fontSize.base,
    color: colors.text.primary,
  },
  hoursInput: {
    flexDirection: "row",
    alignItems: "center",
    marginLeft: spacing.sm,
  },
  hoursInputField: {
    width: 50,
    borderWidth: 1,
    borderColor: colors.surface.border,
    backgroundColor: colors.surface.elevated,
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    fontSize: typography.fontSize.base,
    textAlign: "center",
    color: colors.text.primary,
  },
  hoursLabel: {
    marginLeft: spacing.xs,
    color: colors.text.secondary,
    fontSize: typography.fontSize.sm,
  },
  deleteButton: {
    padding: spacing.sm,
    marginLeft: spacing.xs,
  },
  emptyState: {
    alignItems: "center",
    paddingVertical: spacing.xl,
  },
  emptyText: {
    color: colors.text.muted,
    fontSize: typography.fontSize.sm,
  },
  warningBox: {
    backgroundColor: "rgba(239, 68, 68, 0.15)",
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: "rgba(239, 68, 68, 0.3)",
    padding: spacing.base,
    marginBottom: spacing.base,
  },
  warningText: {
    color: colors.status.error,
    textAlign: "center",
    fontSize: typography.fontSize.sm,
  },
  modalOverlay: {
    flex: 1,
    justifyContent: "flex-end",
    backgroundColor: "rgba(0, 0, 0, 0.6)",
  },
  modalContent: {
    backgroundColor: colors.surface.elevated,
    borderTopLeftRadius: borderRadius["2xl"],
    borderTopRightRadius: borderRadius["2xl"],
    paddingBottom: 40,
    alignItems: "center",
  },
  modalHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    padding: spacing.base,
    borderBottomWidth: 1,
    borderBottomColor: colors.surface.border,
    width: "100%",
  },
  modalTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  modalCancel: {
    fontSize: typography.fontSize.base,
    color: colors.text.secondary,
  },
  modalDone: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.semibold,
    color: colors.primary.blue,
  },
});
