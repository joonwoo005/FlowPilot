import React from "react";
import { View, Text, TouchableOpacity, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { colors, typography, spacing, borderRadius } from "@/theme";
import { Badge } from "./Badge";

interface SectionHeaderProps {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle?: string;
  count?: number;
  isExpanded?: boolean;
  onToggle?: () => void;
  iconColor?: string;
  showChevron?: boolean;
}

export function SectionHeader({
  icon,
  title,
  subtitle,
  count,
  isExpanded = true,
  onToggle,
  iconColor = colors.text.secondary,
  showChevron = true,
}: SectionHeaderProps) {
  const content = (
    <>
      <View style={[styles.iconContainer, { backgroundColor: iconColor + "20" }]}>
        <Ionicons name={icon} size={16} color={iconColor} />
      </View>
      <View style={styles.textContainer}>
        <Text style={styles.title}>{title}</Text>
        {subtitle && <Text style={styles.subtitle}>{subtitle}</Text>}
      </View>
      {count !== undefined && <Badge count={count} />}
      {showChevron && onToggle && (
        <View style={[styles.chevron, isExpanded && styles.chevronExpanded]}>
          <Ionicons name="chevron-forward" size={16} color={colors.text.muted} />
        </View>
      )}
    </>
  );

  if (onToggle) {
    return (
      <TouchableOpacity
        style={styles.container}
        onPress={onToggle}
        activeOpacity={0.7}
        accessibilityRole="button"
        accessibilityLabel={`${title} section, ${count ?? 0} items, ${isExpanded ? "expanded" : "collapsed"}`}
        accessibilityHint="Double tap to toggle"
      >
        {content}
      </TouchableOpacity>
    );
  }

  return <View style={styles.container}>{content}</View>;
}

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.base,
    gap: spacing.md,
  },
  iconContainer: {
    width: 28,
    height: 28,
    borderRadius: borderRadius.md,
    alignItems: "center",
    justifyContent: "center",
  },
  textContainer: {
    flex: 1,
  },
  title: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  subtitle: {
    fontSize: typography.fontSize.sm,
    color: colors.text.secondary,
    marginTop: 2,
  },
  chevron: {
    transform: [{ rotate: "0deg" }],
  },
  chevronExpanded: {
    transform: [{ rotate: "90deg" }],
  },
});
