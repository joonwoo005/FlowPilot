import { useState, useEffect, useRef } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  StyleSheet,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { useAuthStore, useUserStore } from "@/stores";
import { userRepository } from "@/services/repositories";
import { KeyboardDoneBar } from "@/components/ui";

const INPUT_ACCESSORY_ID = "nameInput";

export default function NameScreen() {
  const [name, setName] = useState("");
  const { user } = useAuthStore();
  const { profile } = useUserStore();
  const saveTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Load existing name if user comes back
  useEffect(() => {
    if (profile?.name) {
      setName(profile.name);
    }
  }, [profile?.name]);

  // Auto-save name in background (debounced)
  const handleNameChange = (text: string) => {
    setName(text);

    if (saveTimeoutRef.current) {
      clearTimeout(saveTimeoutRef.current);
    }

    if (text.trim() && user?.uid) {
      saveTimeoutRef.current = setTimeout(async () => {
        try {
          if (profile) {
            await userRepository.updateName(user.uid, text.trim());
          } else {
            await userRepository.create(user.uid, text.trim());
          }
        } catch (error) {
          console.error("Failed to save name:", error);
        }
      }, 500);
    }
  };

  const handleContinue = () => {
    if (!name.trim()) return;
    router.push("/(onboarding)/priorities");
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior="padding"
        style={styles.flex}
      >
        <View style={styles.content}>
          <Text style={styles.title}>Welcome!</Text>
          <Text style={styles.subtitle}>Let's start by getting your name</Text>

          <Text style={styles.label}>Your Name</Text>
          <TextInput
            style={styles.input}
            placeholder="Enter your name"
            value={name}
            onChangeText={handleNameChange}
            onSubmitEditing={handleContinue}
            autoFocus
            autoCapitalize="words"
            returnKeyType="done"
            inputAccessoryViewID={INPUT_ACCESSORY_ID}
          />

          <TouchableOpacity
            style={[
              styles.button,
              !name.trim() && styles.buttonDisabled,
            ]}
            onPress={handleContinue}
            disabled={!name.trim()}
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
    marginBottom: 32,
  },
  label: {
    fontSize: 14,
    fontWeight: "500",
    color: "#374151",
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 18,
    marginBottom: 32,
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
});
