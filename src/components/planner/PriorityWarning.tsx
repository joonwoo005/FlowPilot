import { View, Text, ScrollView, StyleSheet } from "react-native";
import { PriorityWithStats } from "@/types";
import { formatHoursAndMinutes } from "@/utils";

interface PriorityWarningProps {
  priorities: PriorityWithStats[];
}

export function PriorityWarning({ priorities }: PriorityWarningProps) {
  const underAllocated = priorities.filter((p) => p.isUnderAllocated);

  if (underAllocated.length === 0) return null;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Hours remaining to schedule:</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        <View style={styles.chipContainer}>
          {underAllocated.map((priority) => (
            <View key={priority.id} style={styles.chip}>
              <View
                style={[styles.dot, { backgroundColor: priority.color }]}
              />
              <Text style={styles.chipText}>
                {priority.name}: {formatHoursAndMinutes(priority.hoursRemaining)}
              </Text>
            </View>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: "#fef9c3",
    borderWidth: 1,
    borderColor: "#fde047",
    borderRadius: 12,
    padding: 12,
    marginBottom: 16,
  },
  title: {
    color: "#854d0e",
    fontWeight: "500",
    marginBottom: 8,
  },
  chipContainer: {
    flexDirection: "row",
    gap: 8,
  },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#fef08a",
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 4,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 8,
  },
  chipText: {
    color: "#854d0e",
    fontSize: 14,
  },
});
