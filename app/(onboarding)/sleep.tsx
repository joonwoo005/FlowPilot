import { useState, useEffect } from "react";
import { View, Text, TouchableOpacity, StyleSheet, Modal } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import DateTimePicker from "@react-native-community/datetimepicker";
import { useAuthStore, useUserStore } from "@/stores";
import { userRepository } from "@/services/repositories";
import { calculateAwakeHours } from "@/utils";

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

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>Sleep Schedule</Text>
        <Text style={styles.subtitle}>
          When do you typically sleep and wake up?
        </Text>

        <View style={styles.section}>
          <Text style={styles.label}>Bedtime</Text>
          <TouchableOpacity
            style={styles.timeButton}
            onPress={openSleepPicker}
          >
            <Text style={styles.timeText}>{sleepTime}</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.label}>Wake Time</Text>
          <TouchableOpacity
            style={styles.timeButton}
            onPress={openWakePicker}
          >
            <Text style={styles.timeText}>{wakeTime}</Text>
          </TouchableOpacity>
        </View>

        <Modal
          visible={showSleepPicker}
          transparent
          animationType="slide"
        >
          <View style={styles.modalOverlay}>
            <View style={styles.modalContent}>
              <View style={styles.modalHeader}>
                <TouchableOpacity onPress={() => setShowSleepPicker(false)}>
                  <Text style={styles.modalCancel}>Cancel</Text>
                </TouchableOpacity>
                <Text style={styles.modalTitle}>Bedtime</Text>
                <TouchableOpacity onPress={confirmSleepTime}>
                  <Text style={styles.modalDone}>Done</Text>
                </TouchableOpacity>
              </View>
              <DateTimePicker
                value={timeStringToDate(tempSleepTime)}
                mode="time"
                is24Hour={true}
                display="spinner"
                onChange={handleSleepChange}
                themeVariant="light"
              />
            </View>
          </View>
        </Modal>

        <Modal
          visible={showWakePicker}
          transparent
          animationType="slide"
        >
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
                value={timeStringToDate(tempWakeTime)}
                mode="time"
                is24Hour={true}
                display="spinner"
                onChange={handleWakeChange}
                themeVariant="light"
              />
            </View>
          </View>
        </Modal>

        <View style={styles.summaryBox}>
          <View style={styles.summaryRow}>
            <View style={styles.summaryItem}>
              <Text style={styles.summaryValue}>{awakeHoursPerDay}</Text>
              <Text style={styles.summaryLabel}>awake hours</Text>
            </View>
            <View style={styles.summaryDivider} />
            <View style={styles.summaryItem}>
              <Text style={styles.summaryValue}>{24 - awakeHoursPerDay}</Text>
              <Text style={styles.summaryLabel}>sleep hours</Text>
            </View>
          </View>
          <Text style={styles.summarySubtext}>
            Weekly awake: {weeklyAwakeHours} hours
          </Text>
        </View>

        <TouchableOpacity
          style={styles.button}
          onPress={handleContinue}
        >
          <Text style={styles.buttonText}>Continue</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#fff",
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 48,
  },
  title: {
    fontSize: 30,
    fontWeight: "bold",
    color: "#111827",
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 18,
    color: "#4b5563",
    marginBottom: 32,
  },
  section: {
    marginBottom: 24,
  },
  label: {
    fontSize: 14,
    fontWeight: "500",
    color: "#374151",
    marginBottom: 8,
  },
  timeButton: {
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  timeText: {
    fontSize: 18,
    color: "#111827",
  },
  summaryBox: {
    backgroundColor: "#eff6ff",
    borderRadius: 12,
    padding: 16,
    marginBottom: 32,
  },
  summaryRow: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
  },
  summaryItem: {
    flex: 1,
    alignItems: "center",
  },
  summaryDivider: {
    width: 1,
    height: 40,
    backgroundColor: "#bfdbfe",
  },
  summaryLabel: {
    fontSize: 14,
    color: "#1e40af",
    marginTop: 4,
  },
  summaryValue: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#1e3a8a",
  },
  summarySubtext: {
    fontSize: 14,
    color: "#2563eb",
    marginTop: 12,
    textAlign: "center",
  },
  button: {
    backgroundColor: "#2563eb",
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: "center",
  },
  buttonDisabled: {
    backgroundColor: "#d1d5db",
  },
  buttonText: {
    color: "#fff",
    fontWeight: "600",
    fontSize: 18,
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
