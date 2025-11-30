import { View, Text, Pressable, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { TimeBlockWithPriority } from "@/types";
import { calculateEndTime, formatMinutesToHours } from "@/utils";
import { colors, typography, spacing, borderRadius } from "@/theme";

interface TimeBlockItemProps {
  block: TimeBlockWithPriority;
  onDelete?: (id: string) => void;
}

export function TimeBlockItem({ block, onDelete }: TimeBlockItemProps) {
  const endTime = calculateEndTime(block.startTime, block.durationMinutes);
  const priorityColor = block.priority?.color || colors.text.muted;

  return (
    <View style={styles.container}>
      <View
        style={[styles.colorBar, { backgroundColor: priorityColor }]}
      />
      <View style={styles.content}>
        <Text style={styles.name}>{block.priorityName}</Text>
        <Text style={styles.time}>
          {block.startTime} - {endTime} ({formatMinutesToHours(block.durationMinutes)})
        </Text>
      </View>
      {onDelete && (
        <Pressable onPress={() => onDelete(block.id)} style={styles.deleteButton}>
          <Ionicons name="close-circle" size={22} color={colors.status.error} />
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: colors.surface.elevated,
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: colors.surface.border,
    padding: spacing.md,
    marginBottom: spacing.sm,
  },
  colorBar: {
    width: 4,
    height: "100%",
    borderRadius: 2,
    marginRight: spacing.md,
    minHeight: 40,
  },
  content: {
    flex: 1,
  },
  name: {
    fontWeight: typography.fontWeight.medium,
    color: colors.text.primary,
    fontSize: typography.fontSize.base,
  },
  time: {
    fontSize: typography.fontSize.sm,
    color: colors.text.secondary,
    marginTop: 2,
  },
  deleteButton: {
    padding: spacing.xs,
  },
});
