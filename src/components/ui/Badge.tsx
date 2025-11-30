import React from "react";
import { View, Text, StyleSheet, ViewStyle } from "react-native";
import { colors, typography, borderRadius } from "@/theme";

interface BadgeProps {
  count: number;
  variant?: "default" | "success" | "warning" | "error" | "primary";
  size?: "sm" | "md";
  style?: ViewStyle;
}

export function Badge({
  count,
  variant = "default",
  size = "sm",
  style,
}: BadgeProps) {
  const backgroundColor = {
    default: colors.surface.secondary,
    success: colors.status.success,
    warning: colors.status.warning,
    error: colors.status.error,
    primary: colors.primary.blue,
  }[variant];

  const textColor = variant === "default" ? colors.text.secondary : "#FFFFFF";

  const badgeSize = size === "md" ? 24 : 20;
  const fontSize = size === "md" ? typography.fontSize.sm : typography.fontSize.xs;

  return (
    <View
      style={[
        styles.badge,
        {
          backgroundColor,
          height: badgeSize,
          minWidth: badgeSize,
          borderRadius: badgeSize / 2,
        },
        style,
      ]}
    >
      <Text style={[styles.text, { color: textColor, fontSize }]}>{count}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: 8,
    alignItems: "center",
    justifyContent: "center",
  },
  text: {
    fontWeight: typography.fontWeight.semibold,
  },
});
