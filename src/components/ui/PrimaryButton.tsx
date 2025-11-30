import React from "react";
import {
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  ViewStyle,
} from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { colors, typography, borderRadius, spacing } from "@/theme";

interface PrimaryButtonProps {
  title: string;
  onPress: () => void;
  disabled?: boolean;
  loading?: boolean;
  variant?: "gradient" | "outline" | "ghost";
  size?: "sm" | "md" | "lg";
  style?: ViewStyle;
}

export function PrimaryButton({
  title,
  onPress,
  disabled,
  loading,
  variant = "gradient",
  size = "md",
  style,
}: PrimaryButtonProps) {
  const buttonHeight = size === "sm" ? 40 : size === "lg" ? 56 : 50;
  const fontSize =
    size === "sm"
      ? typography.fontSize.sm
      : size === "lg"
        ? typography.fontSize.lg
        : typography.fontSize.md;

  if (variant === "gradient") {
    return (
      <TouchableOpacity
        onPress={onPress}
        disabled={disabled || loading}
        activeOpacity={0.8}
        style={[styles.button, { height: buttonHeight }, disabled && styles.disabled, style]}
        accessibilityRole="button"
        accessibilityLabel={title}
      >
        <LinearGradient
          colors={[colors.primary.blue, colors.primary.purple]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 0 }}
          style={styles.gradient}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={[styles.text, { fontSize }]}>{title}</Text>
          )}
        </LinearGradient>
      </TouchableOpacity>
    );
  }

  if (variant === "outline") {
    return (
      <TouchableOpacity
        onPress={onPress}
        disabled={disabled || loading}
        style={[
          styles.button,
          styles.outline,
          { height: buttonHeight },
          disabled && styles.disabled,
          style,
        ]}
        accessibilityRole="button"
        accessibilityLabel={title}
      >
        {loading ? (
          <ActivityIndicator color={colors.primary.blue} />
        ) : (
          <Text style={[styles.outlineText, { fontSize }]}>{title}</Text>
        )}
      </TouchableOpacity>
    );
  }

  // Ghost variant
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled || loading}
      style={[
        styles.button,
        styles.ghost,
        { height: buttonHeight },
        disabled && styles.disabled,
        style,
      ]}
      accessibilityRole="button"
      accessibilityLabel={title}
    >
      {loading ? (
        <ActivityIndicator color={colors.text.secondary} />
      ) : (
        <Text style={[styles.ghostText, { fontSize }]}>{title}</Text>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    borderRadius: borderRadius.lg,
    overflow: "hidden",
  },
  gradient: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: spacing.xl,
  },
  text: {
    color: "#FFFFFF",
    fontWeight: typography.fontWeight.semibold,
  },
  disabled: {
    opacity: 0.5,
  },
  outline: {
    borderWidth: 1,
    borderColor: colors.primary.blue,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: spacing.xl,
  },
  outlineText: {
    color: colors.primary.blue,
    fontWeight: typography.fontWeight.semibold,
  },
  ghost: {
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: spacing.xl,
  },
  ghostText: {
    color: colors.text.secondary,
    fontWeight: typography.fontWeight.medium,
  },
});
