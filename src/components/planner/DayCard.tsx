import { View, Text, Pressable, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { DaySchedule } from "@/types";
import { TimeBlockItem } from "./TimeBlockItem";
import { formatDateShort, formatHoursAndMinutes } from "@/utils";
import { colors, typography, spacing, borderRadius } from "@/theme";

interface DayCardProps {
  day: DaySchedule;
  onAddBlock: (dayOfWeek: number) => void;
  onDeleteBlock?: (id: string) => void;
  showAddButton?: boolean;
}

export function DayCard({ day, onAddBlock, onDeleteBlock, showAddButton = true }: DayCardProps) {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.dayName}>{formatDateShort(day.date)} - {day.dayName}</Text>
        </View>
        {showAddButton && (
          <Pressable
            onPress={() => onAddBlock(day.dayOfWeek)}
            style={styles.addButton}
          >
            <Ionicons name="add-circle" size={28} color={colors.primary.blue} />
          </Pressable>
        )}
      </View>

      {day.timeBlocks.length > 0 ? (
        day.timeBlocks.map((block) => (
          <TimeBlockItem
            key={block.id}
            block={block}
            onDelete={onDeleteBlock}
          />
        ))
      ) : (
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>No blocks scheduled</Text>
        </View>
      )}

      {day.totalHours > 0 && (
        <View style={styles.footer}>
          <Text style={styles.totalText}>
            Total: {formatHoursAndMinutes(day.totalHours)}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.surface.primary,
    borderRadius: borderRadius.xl,
    borderWidth: 1,
    borderColor: colors.surface.border,
    padding: spacing.base,
    marginBottom: spacing.md,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: spacing.md,
  },
  dayName: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  addButton: {
    padding: spacing.xs,
  },
  emptyState: {
    paddingVertical: spacing.base,
    alignItems: "center",
  },
  emptyText: {
    color: colors.text.muted,
    fontSize: typography.fontSize.sm,
  },
  footer: {
    marginTop: spacing.sm,
    paddingTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.surface.border,
  },
  totalText: {
    fontSize: typography.fontSize.sm,
    color: colors.text.secondary,
    textAlign: "right",
  },
});
