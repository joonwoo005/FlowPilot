import { useState } from "react";
import { View, Text, ScrollView, TouchableOpacity, StyleSheet, Alert, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { usePlannerStore } from "@/stores";
import { usePriorities, useTimeBlocks, useUser } from "@/hooks";
import { DayCard } from "@/components/planner";
import { DayOfWeek } from "@/types";
import { exportWeekToCalendar } from "@/services/calendar.service";

export default function HomeScreen() {
  const { profile } = useUser();
  const { prioritiesWithStats } = usePriorities();
  const { weekSchedule, deleteTimeBlock, weekLabel, weekOffset } = useTimeBlocks();
  const [isExporting, setIsExporting] = useState(false);

  const hasRemainingHours = prioritiesWithStats.some((p) => p.hoursRemaining > 0);
  const { setSelectedDay, goToPreviousWeek, goToNextWeek, goToCurrentWeek } = usePlannerStore();

  const handleAddBlock = (dayOfWeek: DayOfWeek) => {
    setSelectedDay(dayOfWeek);
    router.push("/(main)/add-block");
  };

  const handleDeleteBlock = async (id: string) => {
    await deleteTimeBlock(id);
  };

  const handleExport = async () => {
    setIsExporting(true);
    try {
      const result = await exportWeekToCalendar(weekSchedule);
      if (result.success) {
        Alert.alert(
          "Export Successful",
          `Exported ${result.eventsCreated} events to Apple Calendar`
        );
      } else {
        if (result.error === "Calendar permission denied") {
          Alert.alert(
            "Permission Required",
            "Calendar access is required to export. Please enable it in Settings.",
            [{ text: "OK" }]
          );
        } else {
          Alert.alert("Export Failed", result.error || "Unknown error occurred");
        }
      }
    } catch (error) {
      Alert.alert("Export Failed", "An unexpected error occurred");
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>Hi, {profile?.name || "there"}!</Text>
          <Text style={styles.subtitle}>Plan your week</Text>
        </View>
        <View style={styles.headerButtons}>
          <TouchableOpacity style={styles.headerButton} onPress={() => router.push("/(main)/edit-priorities")}>
            <Ionicons name="create-outline" size={24} color="#2563eb" />
          </TouchableOpacity>
          <TouchableOpacity style={styles.headerButton} onPress={handleExport} disabled={isExporting}>
            {isExporting ? (
              <ActivityIndicator size="small" color="#2563eb" />
            ) : (
              <Ionicons name="share-outline" size={24} color="#2563eb" />
            )}
          </TouchableOpacity>
        </View>
      </View>

      <View style={styles.weekNav}>
        <TouchableOpacity onPress={goToPreviousWeek} style={styles.navButton}>
          <Text style={styles.navButtonText}>{"<"}</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={goToCurrentWeek}>
          <Text style={[styles.weekLabel, weekOffset === 0 && styles.weekLabelCurrent]}>
            {weekLabel}
          </Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={goToNextWeek} style={styles.navButton}>
          <Text style={styles.navButtonText}>{">"}</Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
        {weekSchedule.map((day) => (
          <DayCard
            key={day.dayOfWeek}
            day={day}
            onAddBlock={handleAddBlock}
            onDeleteBlock={handleDeleteBlock}
            showAddButton={hasRemainingHours}
          />
        ))}
        <View style={styles.bottomPadding} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#fff",
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    paddingHorizontal: 24,
    paddingTop: 16,
    paddingBottom: 8,
  },
  headerButtons: {
    flexDirection: "row",
    gap: 8,
  },
  headerButton: {
    padding: 8,
  },
  greeting: {
    fontSize: 24,
    fontWeight: "bold",
    color: "#111827",
  },
  subtitle: {
    color: "#6b7280",
  },
  weekNav: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 24,
    paddingVertical: 12,
  },
  weekLabel: {
    fontSize: 16,
    fontWeight: "600",
    color: "#374151",
  },
  weekLabelCurrent: {
    color: "#2563eb",
  },
  scrollView: {
    flex: 1,
    paddingHorizontal: 24,
  },
  scrollContent: {
    paddingBottom: 80,
  },
  bottomPadding: {
    height: 80,
  },
  navButton: {
    padding: 8,
  },
  navButtonText: {
    fontSize: 24,
    color: "#2563eb",
  },
});
