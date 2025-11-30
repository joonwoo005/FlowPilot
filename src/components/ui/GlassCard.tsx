import React from "react";
import { View, TouchableOpacity, StyleSheet, ViewStyle } from "react-native";
import { colors, borderRadius, spacing } from "@/theme";

interface GlassCardProps {
  children: React.ReactNode;
  variant?: "default" | "elevated" | "secondary";
  onPress?: () => void;
  style?: ViewStyle;
  disabled?: boolean;
}

export function GlassCard({
  children,
  variant = "default",
  onPress,
  style,
  disabled,
}: GlassCardProps) {
  const cardStyle = [
    styles.card,
    variant === "elevated" && styles.elevated,
    variant === "secondary" && styles.secondary,
    style,
  ];

  if (onPress) {
    return (
      <TouchableOpacity
        style={cardStyle}
        onPress={onPress}
        activeOpacity={0.7}
        disabled={disabled}
        accessibilityRole="button"
      >
        {children}
      </TouchableOpacity>
    );
  }

  return <View style={cardStyle}>{children}</View>;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface.primary,
    borderWidth: 1,
    borderColor: colors.surface.border,
    borderRadius: borderRadius.xl,
    padding: spacing.base,
  },
  elevated: {
    backgroundColor: colors.surface.elevated,
  },
  secondary: {
    backgroundColor: colors.surface.secondary,
  },
});
