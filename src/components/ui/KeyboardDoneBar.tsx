import React from "react";
import {
  InputAccessoryView,
  Keyboard,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";

interface KeyboardDoneBarProps {
  inputAccessoryViewID: string;
}

export function KeyboardDoneBar({ inputAccessoryViewID }: KeyboardDoneBarProps) {
  return (
    <InputAccessoryView nativeID={inputAccessoryViewID}>
      <View style={styles.accessory}>
        <View style={styles.spacer} />
        <TouchableOpacity onPress={Keyboard.dismiss} style={styles.doneButton}>
          <Text style={styles.doneText}>Done</Text>
        </TouchableOpacity>
      </View>
    </InputAccessoryView>
  );
}

const styles = StyleSheet.create({
  accessory: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "flex-end",
    backgroundColor: "#f1f1f1",
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "#ccc",
  },
  spacer: {
    flex: 1,
  },
  doneButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  doneText: {
    color: "#007AFF",
    fontSize: 17,
    fontWeight: "600",
  },
});
