import { View, Text, TouchableOpacity, StyleSheet } from "react-native";
import { TimeBlockWithPriority } from "@/types";
import { calculateEndTime, formatMinutesToHours } from "@/utils";

interface TimeBlockItemProps {
  block: TimeBlockWithPriority;
  onDelete?: (id: string) => void;
}

export function TimeBlockItem({ block, onDelete }: TimeBlockItemProps) {
  const endTime = calculateEndTime(block.startTime, block.durationMinutes);

  return (
    <View style={styles.container}>
      <View
        style={[styles.colorBar, { backgroundColor: block.priority?.color || "#ccc" }]}
      />
      <View style={styles.content}>
        <Text style={styles.name}>{block.priorityName}</Text>
        <Text style={styles.time}>
          {block.startTime} - {endTime} ({formatMinutesToHours(block.durationMinutes)})
        </Text>
      </View>
      {onDelete && (
        <TouchableOpacity onPress={() => onDelete(block.id)} style={styles.deleteButton}>
          <Text style={styles.deleteText}>×</Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#fff",
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  colorBar: {
    width: 4,
    height: "100%",
    borderRadius: 2,
    marginRight: 12,
    minHeight: 40,
  },
  content: {
    flex: 1,
  },
  name: {
    fontWeight: "500",
    color: "#111827",
  },
  time: {
    fontSize: 14,
    color: "#6b7280",
    marginTop: 2,
  },
  deleteButton: {
    padding: 8,
  },
  deleteText: {
    color: "#ef4444",
    fontSize: 20,
  },
});
