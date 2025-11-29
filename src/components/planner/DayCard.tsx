import { View, Text, TouchableOpacity, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { DaySchedule } from "@/types";
import { TimeBlockItem } from "./TimeBlockItem";
import { formatDateShort, formatHoursAndMinutes } from "@/utils";

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
          <TouchableOpacity
            onPress={() => onAddBlock(day.dayOfWeek)}
            style={styles.addButton}
          >
            <Ionicons name="add-circle-outline" size={28} color="#2563eb" />
          </TouchableOpacity>
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
    backgroundColor: "#f9fafb",
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 12,
  },
  dayName: {
    fontSize: 18,
    fontWeight: "600",
    color: "#111827",
  },
  addButton: {
    padding: 4,
  },
  emptyState: {
    paddingVertical: 16,
    alignItems: "center",
  },
  emptyText: {
    color: "#9ca3af",
    fontSize: 14,
  },
  footer: {
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: "#e5e7eb",
  },
  totalText: {
    fontSize: 14,
    color: "#6b7280",
    textAlign: "right",
  },
});
