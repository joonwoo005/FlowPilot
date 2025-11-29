import { useEffect } from "react";
import { View, Text, ActivityIndicator, StyleSheet } from "react-native";
import { Redirect } from "expo-router";
import { useAuthStore, useUserStore } from "@/stores";
import { signInAnonymously } from "@/services/firebase";
import { userRepository } from "@/services/repositories";

export default function Index() {
  const { user, isLoading: authLoading, isAuthenticated } = useAuthStore();
  const { profile, isLoading: userLoading, setProfile, setLoading } = useUserStore();

  useEffect(() => {
    const initAuth = async () => {
      if (!authLoading && !isAuthenticated) {
        try {
          await signInAnonymously();
        } catch (error) {
          console.error("Failed to sign in anonymously:", error);
        }
      }
    };

    initAuth();
  }, [authLoading, isAuthenticated]);

  useEffect(() => {
    if (!user?.uid) {
      setProfile(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    const unsubscribe = userRepository.subscribe(user.uid, (userData) => {
      setProfile(userData);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [user?.uid, setProfile, setLoading]);

  if (authLoading || (isAuthenticated && userLoading)) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" color="#3b82f6" />
        <Text style={styles.loadingText}>Loading...</Text>
      </View>
    );
  }

  if (!isAuthenticated) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" color="#3b82f6" />
        <Text style={styles.loadingText}>Setting up...</Text>
      </View>
    );
  }

  if (profile?.onboardingComplete) {
    return <Redirect href="/(main)" />;
  }

  return <Redirect href="/(onboarding)/name" />;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#fff",
  },
  loadingText: {
    marginTop: 16,
    color: "#6b7280",
  },
});
