import { Stack } from "expo-router";

export default function CalendarLayout() {
  return (
    <Stack
      screenOptions={{
        headerShown: false,
      }}
    >
      <Stack.Screen name="index" />
      <Stack.Screen
        name="add-block"
        options={{
          presentation: "modal",
        }}
      />
      <Stack.Screen
        name="edit-priorities"
        options={{
          presentation: "modal",
        }}
      />
    </Stack>
  );
}
