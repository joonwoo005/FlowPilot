import { Stack } from "expo-router";

export default function OnboardingLayout() {
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        animation: "slide_from_right",
      }}
    >
      <Stack.Screen name="name" />
      <Stack.Screen name="priorities" />
      <Stack.Screen name="sleep" />
      <Stack.Screen name="allocate" />
    </Stack>
  );
}
