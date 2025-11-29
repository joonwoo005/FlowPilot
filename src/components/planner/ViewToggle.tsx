import { View, Text, TouchableOpacity, StyleSheet } from "react-native";
import { ViewMode } from "@/types";

interface ViewToggleProps {
  viewMode: ViewMode;
  onChangeMode: (mode: ViewMode) => void;
}

export function ViewToggle({ viewMode, onChangeMode }: ViewToggleProps) {
  return (
    <View style={styles.container}>
      <TouchableOpacity onPress={() => onChangeMode("weekly")}>
        <Text
          style={[
            styles.text,
            viewMode === "weekly" && styles.activeText,
          ]}
        >
          Weekly
        </Text>
      </TouchableOpacity>
      <TouchableOpacity onPress={() => onChangeMode("daily")}>
        <Text
          style={[
            styles.text,
            viewMode === "daily" && styles.activeText,
          ]}
        >
          Daily
        </Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    justifyContent: "center",
    gap: 32,
    paddingVertical: 16,
  },
  text: {
    fontSize: 18,
    color: "#6b7280",
  },
  activeText: {
    fontWeight: "bold",
    color: "#2563eb",
    textDecorationLine: "underline",
  },
});
