import { useState, useEffect } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  FlatList,
  KeyboardAvoidingView,
  StyleSheet,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { useAuthStore } from "@/stores";
import { priorityRepository } from "@/services/repositories";
import { Priority } from "@/types";
import { KeyboardDoneBar } from "@/components/ui";

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

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior="padding"
        style={styles.flex}
      >
        <View style={styles.content}>
          <Text style={styles.title}>Your Priorities</Text>
          <Text style={styles.subtitle}>
            What do you want to allocate time for?
          </Text>

          <View style={styles.inputRow}>
            <TextInput
              style={styles.input}
              placeholder="e.g., Studying, Exercise"
              value={input}
              onChangeText={setInput}
              onSubmitEditing={handleAddPriority}
              blurOnSubmit={false}
              returnKeyType="done"
              inputAccessoryViewID={INPUT_ACCESSORY_ID}
            />
            <TouchableOpacity
              style={[
                styles.addButton,
                (!input.trim() || isLoading) && styles.buttonDisabled,
              ]}
              onPress={handleAddPriority}
              disabled={!input.trim() || isLoading}
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
                <View
                  style={[styles.colorDot, { backgroundColor: item.color }]}
                />
                <Text style={styles.priorityName}>{item.name}</Text>
                <TouchableOpacity
                  onPress={() => handleDeletePriority(item.id)}
                  style={styles.deleteButton}
                >
                  <Text style={styles.deleteText}>×</Text>
                </TouchableOpacity>
              </View>
            )}
            ListEmptyComponent={
              <View style={styles.emptyState}>
                <Text style={styles.emptyText}>
                  Add at least one priority to continue
                </Text>
              </View>
            }
          />

          <TouchableOpacity
            style={[
              styles.button,
              priorities.length === 0 && styles.buttonDisabled,
            ]}
            onPress={handleContinue}
            disabled={priorities.length === 0}
          >
            <Text style={styles.buttonText}>Continue</Text>
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
  inputRow: {
    flexDirection: "row",
    marginBottom: 24,
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 18,
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
  deleteButton: {
    padding: 8,
  },
  deleteText: {
    color: "#ef4444",
    fontSize: 24,
  },
  emptyState: {
    alignItems: "center",
    paddingVertical: 32,
  },
  emptyText: {
    color: "#9ca3af",
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
