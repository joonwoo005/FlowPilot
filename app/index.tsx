import { useEffect, useRef } from "react";
import { View, Text, StyleSheet, Animated, Easing } from "react-native";
import { Redirect } from "expo-router";
import { LinearGradient } from "expo-linear-gradient";
import { Ionicons } from "@expo/vector-icons";
import { useAuthStore, useUserStore } from "@/stores";
import { signInAnonymously } from "@/services/firebase";
import { userRepository } from "@/services/repositories";
import { colors, typography, spacing } from "@/theme";

function LoadingScreen({ message = "Loading..." }: { message?: string }) {
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const glowAnim = useRef(new Animated.Value(0.15)).current;
  const rotateAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Pulse animation for the icon
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.08,
          duration: 1200,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 1200,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
      ])
    ).start();

    // Glow animation
    Animated.loop(
      Animated.sequence([
        Animated.timing(glowAnim, {
          toValue: 0.25,
          duration: 1500,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.timing(glowAnim, {
          toValue: 0.15,
          duration: 1500,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
      ])
    ).start();

    // Subtle rotation for the loading indicator
    Animated.loop(
      Animated.timing(rotateAnim, {
        toValue: 1,
        duration: 3000,
        easing: Easing.linear,
        useNativeDriver: true,
      })
    ).start();
  }, []);

  const spin = rotateAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ["0deg", "360deg"],
  });

  return (
    <LinearGradient
      colors={[colors.background.start, colors.background.end]}
      style={styles.container}
    >
      {/* Ambient glow effects */}
      <View style={styles.glowContainer}>
        <Animated.View style={[styles.glowOrb, styles.glowBlue, { opacity: glowAnim }]} />
        <Animated.View style={[styles.glowOrb, styles.glowPurple, { opacity: glowAnim }]} />
      </View>

      {/* Main content */}
      <View style={styles.content}>
        {/* Animated icon */}
        <Animated.View style={[styles.iconWrapper, { transform: [{ scale: pulseAnim }] }]}>
          <View style={styles.iconGlow} />
          <View style={styles.iconCircle}>
            <Ionicons name="calendar" size={36} color={colors.primary.blue} />
          </View>
        </Animated.View>

        {/* App name */}
        <Text style={styles.appName}>Planner</Text>

        {/* Loading indicator */}
        <View style={styles.loadingContainer}>
          <Animated.View style={[styles.spinner, { transform: [{ rotate: spin }] }]}>
            <View style={styles.spinnerDot} />
          </Animated.View>
          <Text style={styles.loadingText}>{message}</Text>
        </View>
      </View>

      {/* Bottom decorative element */}
      <View style={styles.bottomDecor}>
        <View style={styles.decorLine} />
      </View>
    </LinearGradient>
  );
}

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
    return <LoadingScreen message="Loading..." />;
  }

  if (!isAuthenticated) {
    return <LoadingScreen message="Setting up..." />;
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
  },
  glowContainer: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  glowOrb: {
    position: "absolute",
    width: 300,
    height: 300,
    borderRadius: 150,
  },
  glowBlue: {
    top: "20%",
    left: -50,
    backgroundColor: colors.primary.blue,
  },
  glowPurple: {
    bottom: "25%",
    right: -80,
    backgroundColor: colors.primary.purple,
  },
  content: {
    alignItems: "center",
  },
  iconWrapper: {
    alignItems: "center",
    marginBottom: spacing["2xl"],
  },
  iconGlow: {
    position: "absolute",
    width: 140,
    height: 140,
    borderRadius: 70,
    backgroundColor: colors.primary.blue,
    opacity: 0.12,
  },
  iconCircle: {
    width: 88,
    height: 88,
    borderRadius: 44,
    backgroundColor: colors.surface.elevated,
    borderWidth: 1,
    borderColor: colors.surface.border,
    alignItems: "center",
    justifyContent: "center",
  },
  appName: {
    fontSize: typography.fontSize["3xl"],
    fontWeight: typography.fontWeight.bold,
    color: colors.text.primary,
    letterSpacing: -0.5,
    marginBottom: spacing["3xl"],
  },
  loadingContainer: {
    alignItems: "center",
    gap: spacing.md,
  },
  spinner: {
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 2,
    borderColor: colors.surface.border,
    borderTopColor: colors.primary.blue,
    alignItems: "center",
    justifyContent: "flex-start",
    paddingTop: 2,
  },
  spinnerDot: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: colors.primary.blue,
  },
  loadingText: {
    fontSize: typography.fontSize.sm,
    color: colors.text.secondary,
    fontWeight: typography.fontWeight.medium,
    letterSpacing: 0.5,
  },
  bottomDecor: {
    position: "absolute",
    bottom: 60,
    alignItems: "center",
  },
  decorLine: {
    width: 40,
    height: 4,
    borderRadius: 2,
    backgroundColor: colors.surface.border,
  },
});
