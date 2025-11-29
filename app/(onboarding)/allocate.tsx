import { useState, useEffect } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  FlatList,
  TextInput,
  StyleSheet,
  KeyboardAvoidingView,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { useAuthStore, useUserStore } from "@/stores";
import { priorityRepository, userRepository } from "@/services/repositories";
import { Priority } from "@/types";
import { KeyboardDoneBar } from "@/components/ui";

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

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView behavior="padding" style={styles.flex}>
        <View style={styles.content}>
        <Text style={styles.title}>Allocate Hours</Text>
        <Text style={styles.subtitle}>
          How many hours per week for each priority?
        </Text>

        <View style={styles.summaryBox}>
          <View style={styles.summaryRow}>
            <Text style={styles.summaryLabel}>Total weekly hours:</Text>
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

        <FlatList
          data={priorities}
          keyExtractor={(item) => item.id}
          style={styles.list}
          renderItem={({ item }) => (
            <View style={styles.priorityItem}>
              <View
                style={[styles.colorDot, { backgroundColor: item.color }]}
              />
              <Text style={styles.priorityName}>{item.name}</Text>
              <View style={styles.hoursInput}>
                <TextInput
                  style={styles.input}
                  keyboardType="number-pad"
                  value={item.allocatedHours.toString()}
                  onChangeText={(text) => handleHoursChange(item.id, text)}
                  inputAccessoryViewID={INPUT_ACCESSORY_ID}
                  placeholder="0"
                  placeholderTextColor="#9ca3af"
                />
                <Text style={styles.hoursLabel}>h/week</Text>
              </View>
            </View>
          )}
        />

        {remainingHours < 0 && (
          <View style={styles.warningBox}>
            <Text style={styles.warningText}>
              You've allocated more hours than available!
            </Text>
          </View>
        )}

        <TouchableOpacity
          style={[
            styles.button,
            (remainingHours < 0 || isLoading) && styles.buttonDisabled,
          ]}
          onPress={handleComplete}
          disabled={remainingHours < 0 || isLoading}
        >
          <Text style={styles.buttonText}>
            {isLoading ? "Setting up..." : "Complete Setup"}
          </Text>
        </TouchableOpacity>
      </View>
      </KeyboardAvoidingView>
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
    marginBottom: 24,
  },
  summaryBox: {
    backgroundColor: "#f3f4f6",
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
  },
  summaryRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 8,
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
  list: {
    flex: 1,
    marginBottom: 24,
  },
  priorityItem: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#f9fafb",
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
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
  hoursInput: {
    flexDirection: "row",
    alignItems: "center",
  },
  input: {
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    width: 64,
    textAlign: "center",
    fontSize: 18,
  },
  hoursLabel: {
    marginLeft: 8,
    color: "#6b7280",
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
  button: {
    backgroundColor: "#2563eb",
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: "center",
    marginBottom: 16,
  },
  buttonDisabled: {
    backgroundColor: "#d1d5db",
  },
  buttonText: {
    color: "#fff",
    fontWeight: "600",
    fontSize: 18,
  },
});
