import React, { useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
  Image,
} from "react-native";
import { colors, typography, spacing, borderRadius } from "@/theme";

interface GoogleSignInButtonProps {
  onPress: () => Promise<void>;
  label?: string;
  variant?: "primary" | "secondary";
  disabled?: boolean;
}

export function GoogleSignInButton({
  onPress,
  label = "Continue with Google",
  variant = "primary",
  disabled = false,
}: GoogleSignInButtonProps) {
  const [isLoading, setIsLoading] = useState(false);

  const handlePress = async () => {
    if (isLoading || disabled) return;

    setIsLoading(true);
    try {
      await onPress();
    } finally {
      setIsLoading(false);
    }
  };

  const isPrimary = variant === "primary";

  return (
    <Pressable
      onPress={handlePress}
      disabled={isLoading || disabled}
      style={({ pressed }) => [
        styles.button,
        isPrimary ? styles.buttonPrimary : styles.buttonSecondary,
        pressed && styles.buttonPressed,
        (isLoading || disabled) && styles.buttonDisabled,
      ]}
    >
      {isLoading ? (
        <ActivityIndicator
          size="small"
          color={isPrimary ? colors.text.primary : colors.primary.blue}
        />
      ) : (
        <>
          {/* Google "G" Logo */}
          <View style={styles.logoContainer}>
            <View style={styles.googleLogo}>
              <Text style={styles.googleG}>G</Text>
            </View>
          </View>
          <Text
            style={[
              styles.label,
              isPrimary ? styles.labelPrimary : styles.labelSecondary,
            ]}
          >
            {label}
          </Text>
        </>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    borderRadius: borderRadius.lg,
    gap: spacing.md,
    minHeight: 48,
  },
  buttonPrimary: {
    backgroundColor: "#FFFFFF",
  },
  buttonSecondary: {
    backgroundColor: colors.surface.elevated,
    borderWidth: 1,
    borderColor: colors.surface.border,
  },
  buttonPressed: {
    opacity: 0.8,
    transform: [{ scale: 0.98 }],
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  logoContainer: {
    width: 24,
    height: 24,
    alignItems: "center",
    justifyContent: "center",
  },
  googleLogo: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: "#4285F4",
    alignItems: "center",
    justifyContent: "center",
  },
  googleG: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "700",
  },
  label: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.semibold,
  },
  labelPrimary: {
    color: "#1F2937", // Dark gray for white background
  },
  labelSecondary: {
    color: colors.text.primary,
  },
});
