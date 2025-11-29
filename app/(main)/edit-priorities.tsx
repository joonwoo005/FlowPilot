import { useState, useEffect } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  FlatList,
  KeyboardAvoidingView,
  StyleSheet,
  Alert,
  Modal,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import DateTimePicker from "@react-native-community/datetimepicker";
import { useAuthStore, useUserStore } from "@/stores";
import { priorityRepository, userRepository } from "@/services/repositories";
import { Priority } from "@/types";
import { KeyboardDoneBar } from "@/components/ui";

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

  // If sleep time is before wake time, it means sleeping after midnight
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

  // Sleep timing state
  const [wakeTime, setWakeTime] = useState(profile?.wakeTime || "07:00");
  const [sleepTime, setSleepTime] = useState(profile?.sleepTime || "23:00");
  const [showWakePicker, setShowWakePicker] = useState(false);
  const [showSleepPicker, setShowSleepPicker] = useState(false);
  const [tempTime, setTempTime] = useState("07:00");

  // Update local state when profile loads
  useEffect(() => {
    if (profile?.wakeTime) setWakeTime(profile.wakeTime);
    if (profile?.sleepTime) setSleepTime(profile.sleepTime);
  }, [profile?.wakeTime, profile?.sleepTime]);

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

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView behavior="padding" style={styles.flex}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => router.back()}>
            <Ionicons name="close" size={28} color="#111827" />
          </TouchableOpacity>
          <Text style={styles.title}>Edit Priorities</Text>
          <TouchableOpacity onPress={() => router.back()}>
            <Ionicons name="checkmark" size={28} color="#2563eb" />
          </TouchableOpacity>
        </View>

        <View style={styles.content}>
          <View style={styles.sleepBox}>
            <Text style={styles.sleepTitle}>Sleep Schedule</Text>
            <View style={styles.sleepRow}>
              <View style={styles.sleepItem}>
                <Text style={styles.sleepLabel}>Wake up</Text>
                <TouchableOpacity style={styles.timeButton} onPress={openWakePicker}>
                  <Text style={styles.timeButtonText}>{wakeTime}</Text>
                </TouchableOpacity>
              </View>
              <View style={styles.sleepItem}>
                <Text style={styles.sleepLabel}>Sleep</Text>
                <TouchableOpacity style={styles.timeButton} onPress={openSleepPicker}>
                  <Text style={styles.timeButtonText}>{sleepTime}</Text>
                </TouchableOpacity>
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

          <View style={styles.inputRow}>
            <TextInput
              style={styles.input}
              placeholder="Add new priority..."
              value={input}
              onChangeText={setInput}
              onSubmitEditing={handleAddPriority}
              blurOnSubmit={false}
              returnKeyType="done"
              inputAccessoryViewID={INPUT_ACCESSORY_ID}
            />
            <TouchableOpacity
              style={[styles.addButton, !input.trim() && styles.buttonDisabled]}
              onPress={handleAddPriority}
              disabled={!input.trim()}
            >
              <Text style={styles.addButtonText}>+</Text>
            </TouchableOpacity>
          </View>

          <FlatList
            data={priorities}
            keyExtractor={(item) => item.id}
            style={styles.list}
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
                    />
                    <TouchableOpacity onPress={() => handleSaveName(item.id)}>
                      <Ionicons name="checkmark" size={24} color="#10b981" />
                    </TouchableOpacity>
                    <TouchableOpacity onPress={() => handleCancelEditing(item.id)}>
                      <Ionicons name="close" size={24} color="#6b7280" />
                    </TouchableOpacity>
                  </View>
                ) : (
                  <TouchableOpacity
                    style={styles.nameContainer}
                    onPress={() => handleStartEditing(item.id)}
                  >
                    <Text style={styles.priorityName}>{item.name}</Text>
                    <Ionicons name="pencil" size={16} color="#9ca3af" />
                  </TouchableOpacity>
                )}

                <View style={styles.hoursInput}>
                  <TextInput
                    style={styles.hoursInputField}
                    keyboardType="number-pad"
                    value={item.allocatedHours === 0 ? "" : item.allocatedHours.toString()}
                    onChangeText={(text) => handleHoursChange(item.id, text)}
                    placeholder="0"
                    inputAccessoryViewID={INPUT_ACCESSORY_ID}
                  />
                  <Text style={styles.hoursLabel}>h</Text>
                </View>

                <TouchableOpacity
                  onPress={() => handleDeletePriority(item.id, item.name)}
                  style={styles.deleteButton}
                >
                  <Ionicons name="trash-outline" size={20} color="#ef4444" />
                </TouchableOpacity>
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
              <TouchableOpacity onPress={() => setShowWakePicker(false)}>
                <Text style={styles.modalCancel}>Cancel</Text>
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Wake Time</Text>
              <TouchableOpacity onPress={confirmWakeTime}>
                <Text style={styles.modalDone}>Done</Text>
              </TouchableOpacity>
            </View>
            <DateTimePicker
              value={timeStringToDate(tempTime)}
              mode="time"
              is24Hour={true}
              display="spinner"
              onChange={handleTimeChange}
              themeVariant="light"
            />
          </View>
        </View>
      </Modal>

      <Modal visible={showSleepPicker} transparent animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowSleepPicker(false)}>
                <Text style={styles.modalCancel}>Cancel</Text>
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Sleep Time</Text>
              <TouchableOpacity onPress={confirmSleepTime}>
                <Text style={styles.modalDone}>Done</Text>
              </TouchableOpacity>
            </View>
            <DateTimePicker
              value={timeStringToDate(tempTime)}
              mode="time"
              is24Hour={true}
              display="spinner"
              onChange={handleTimeChange}
              themeVariant="light"
            />
          </View>
        </View>
      </Modal>

      <KeyboardDoneBar inputAccessoryViewID={INPUT_ACCESSORY_ID} />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#fff",
  },
  flex: {
    flex: 1,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 24,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#e5e7eb",
  },
  title: {
    fontSize: 18,
    fontWeight: "600",
    color: "#111827",
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 16,
  },
  sleepBox: {
    backgroundColor: "#f0f9ff",
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
  },
  sleepTitle: {
    fontSize: 14,
    fontWeight: "600",
    color: "#0369a1",
    marginBottom: 12,
  },
  sleepRow: {
    flexDirection: "row",
    gap: 16,
  },
  sleepItem: {
    flex: 1,
  },
  sleepLabel: {
    fontSize: 12,
    color: "#6b7280",
    marginBottom: 4,
  },
  timeButton: {
    backgroundColor: "#fff",
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 16,
    alignItems: "center",
  },
  timeButtonText: {
    fontSize: 18,
    fontWeight: "500",
    color: "#111827",
  },
  hoursRow: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    marginTop: 12,
    gap: 8,
  },
  hoursText: {
    fontSize: 14,
    color: "#0369a1",
  },
  hoursValue: {
    fontWeight: "600",
  },
  hoursDivider: {
    color: "#7dd3fc",
    fontSize: 14,
  },
  summaryBox: {
    backgroundColor: "#f3f4f6",
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
  },
  summaryRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 4,
  },
  summaryLabel: {
    color: "#4b5563",
  },
  summaryValue: {
    fontWeight: "600",
    color: "#111827",
  },
  textRed: {
    color: "#ef4444",
  },
  textGreen: {
    color: "#10b981",
  },
  inputRow: {
    flexDirection: "row",
    marginBottom: 16,
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    marginRight: 12,
  },
  addButton: {
    backgroundColor: "#2563eb",
    borderRadius: 12,
    paddingHorizontal: 20,
    justifyContent: "center",
  },
  addButtonText: {
    color: "#fff",
    fontWeight: "600",
    fontSize: 24,
  },
  buttonDisabled: {
    backgroundColor: "#d1d5db",
  },
  list: {
    flex: 1,
  },
  priorityItem: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#f9fafb",
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
  },
  colorDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 12,
  },
  nameContainer: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  editNameContainer: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  editNameInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: "#2563eb",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
    fontSize: 16,
  },
  priorityName: {
    fontSize: 16,
    color: "#111827",
  },
  hoursInput: {
    flexDirection: "row",
    alignItems: "center",
    marginLeft: 8,
  },
  hoursInputField: {
    width: 50,
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 6,
    fontSize: 16,
    textAlign: "center",
  },
  hoursLabel: {
    marginLeft: 4,
    color: "#6b7280",
    fontSize: 14,
  },
  deleteButton: {
    padding: 8,
    marginLeft: 4,
  },
  emptyState: {
    alignItems: "center",
    paddingVertical: 32,
  },
  emptyText: {
    color: "#9ca3af",
  },
  warningBox: {
    backgroundColor: "#fef2f2",
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
  },
  warningText: {
    color: "#dc2626",
    textAlign: "center",
  },
  modalOverlay: {
    flex: 1,
    justifyContent: "flex-end",
    backgroundColor: "rgba(0, 0, 0, 0.4)",
  },
  modalContent: {
    backgroundColor: "#fff",
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingBottom: 40,
    alignItems: "center",
  },
  modalHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#e5e7eb",
    width: "100%",
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#111827",
  },
  modalCancel: {
    fontSize: 16,
    color: "#6b7280",
  },
  modalDone: {
    fontSize: 16,
    fontWeight: "600",
    color: "#2563eb",
  },
});
