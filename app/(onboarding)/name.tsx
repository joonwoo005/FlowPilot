import { useState, useEffect, useRef } from "react";
import {
  View,
  Text,
  TextInput,
  Pressable,
  KeyboardAvoidingView,
  StyleSheet,
  Platform,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { useAuthStore, useUserStore } from "@/stores";
import { userRepository } from "@/services/repositories";
import { GradientBackground, KeyboardDoneBar } from "@/components/ui";
import { colors, typography, spacing, borderRadius } from "@/theme";

const INPUT_ACCESSORY_ID = "nameInput";

export default function NameScreen() {
  const [name, setName] = useState("");
  const [isFocused, setIsFocused] = useState(false);
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
    <GradientBackground>
      <SafeAreaView style={styles.container} edges={["top", "bottom"]}>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          style={styles.flex}
        >
          {/* Step Indicator */}
          <View style={styles.stepIndicator}>
            <View style={styles.stepDots}>
              <View style={[styles.dot, styles.dotActive]} />
              <View style={styles.dot} />
              <View style={styles.dot} />
              <View style={styles.dot} />
            </View>
            <Text style={styles.stepText}>Step 1 of 4</Text>
          </View>

          <View style={styles.content}>
            {/* Icon Header */}
            <View style={styles.iconContainer}>
              <View style={styles.iconGlow} />
              <View style={styles.iconCircle}>
                <Ionicons name="person" size={32} color={colors.primary.blue} />
              </View>
            </View>

            <Text style={styles.title}>Welcome!</Text>
            <Text style={styles.subtitle}>
              Let's personalize your experience.{"\n"}What should we call you?
            </Text>

            <View style={styles.inputSection}>
              <Text style={styles.label}>YOUR NAME</Text>
              <View style={[
                styles.inputContainer,
                isFocused && styles.inputContainerFocused
              ]}>
                <TextInput
                  style={styles.input}
                  placeholder="Enter your name"
                  placeholderTextColor={colors.text.muted}
                  value={name}
                  onChangeText={handleNameChange}
                  onSubmitEditing={handleContinue}
                  onFocus={() => setIsFocused(true)}
                  onBlur={() => setIsFocused(false)}
                  autoFocus
                  autoCapitalize="words"
                  returnKeyType="done"
                  inputAccessoryViewID={INPUT_ACCESSORY_ID}
                />
                {name.trim() && (
                  <View style={styles.checkIcon}>
                    <Ionicons name="checkmark-circle" size={20} color={colors.status.success} />
                  </View>
                )}
              </View>
            </View>

            <View style={styles.spacer} />

            <Pressable
              style={({ pressed }) => [
                styles.button,
                !name.trim() && styles.buttonDisabled,
                pressed && name.trim() && styles.buttonPressed,
              ]}
              onPress={handleContinue}
              disabled={!name.trim()}
            >
              <Text style={[styles.buttonText, !name.trim() && styles.buttonTextDisabled]}>
                Continue
              </Text>
              <Ionicons
                name="arrow-forward"
                size={20}
                color={name.trim() ? "#fff" : colors.text.muted}
              />
            </Pressable>
          </View>
        </KeyboardAvoidingView>
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
  stepIndicator: {
    alignItems: "center",
    paddingTop: spacing.lg,
    paddingBottom: spacing.md,
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
  stepText: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginTop: spacing.xs,
  },
  content: {
    flex: 1,
    paddingHorizontal: spacing.xl,
    paddingTop: spacing["2xl"],
  },
  iconContainer: {
    alignItems: "center",
    marginBottom: spacing["2xl"],
  },
  iconGlow: {
    position: "absolute",
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: colors.primary.blue,
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
    marginBottom: spacing["3xl"],
  },
  inputSection: {
    marginBottom: spacing.xl,
  },
  label: {
    fontSize: typography.fontSize.xs,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.muted,
    letterSpacing: 1,
    marginBottom: spacing.sm,
    marginLeft: spacing.xs,
  },
  inputContainer: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: colors.surface.secondary,
    borderRadius: borderRadius.xl,
    borderWidth: 1,
    borderColor: colors.surface.border,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.base,
  },
  inputContainerFocused: {
    borderColor: colors.primary.blue,
    backgroundColor: colors.surface.elevated,
  },
  input: {
    flex: 1,
    fontSize: typography.fontSize.lg,
    color: colors.text.primary,
    padding: 0,
  },
  checkIcon: {
    marginLeft: spacing.sm,
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
  buttonDisabled: {
    backgroundColor: colors.surface.secondary,
    borderWidth: 1,
    borderColor: colors.surface.border,
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
  buttonTextDisabled: {
    color: colors.text.muted,
  },
});
