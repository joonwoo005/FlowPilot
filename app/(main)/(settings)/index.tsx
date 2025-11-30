import React, { useCallback, useMemo, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Alert,
  RefreshControl,
  Switch,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { router } from "expo-router";
import { GradientBackground, GlassCard } from "@/components/ui";
import { GoogleSignInButton } from "@/components/auth";
import { useAuthStore, useUserStore } from "@/stores";
import { useActivity } from "@/hooks";
import { signOut, linkAnonymousToGoogle } from "@/services/firebase";
import { userRepository } from "@/services/repositories";
import { requestCalendarPermissions } from "@/services/calendar.service";
import { colors, typography, spacing, borderRadius } from "@/theme";
import { format } from "date-fns";

export default function SettingsScreen() {
  const { user } = useAuthStore();
  const { profile, setProfile } = useUserStore();
  const { activityGroups, isLoading, getActionInfo, todayCount } = useActivity();
  const [isLinking, setIsLinking] = useState(false);
  const [isTogglingSync, setIsTogglingSync] = useState(false);

  const calendarSyncEnabled = profile?.calendarSyncEnabled ?? false;

  const handleToggleCalendarSync = useCallback(async (enabled: boolean) => {
    if (!user?.uid || isTogglingSync) return;

    setIsTogglingSync(true);
    try {
      if (enabled) {
        // Request calendar permissions first
        const hasPermission = await requestCalendarPermissions();
        if (!hasPermission) {
          Alert.alert(
            "Calendar Permission Required",
            "Please enable calendar access in Settings to sync time blocks to your calendar."
          );
          setIsTogglingSync(false);
          return;
        }
      }

      await userRepository.updateCalendarSyncEnabled(user.uid, enabled);

      if (enabled) {
        Alert.alert(
          "Calendar Sync Enabled",
          "Your time blocks will automatically sync to Apple Calendar when you finish allocating all hours for the week."
        );
      }
    } catch (error) {
      console.error("Failed to toggle calendar sync:", error);
      Alert.alert("Error", "Failed to update calendar sync setting.");
    } finally {
      setIsTogglingSync(false);
    }
  }, [user?.uid, isTogglingSync]);

  const handleLinkGoogle = useCallback(async () => {
    if (isLinking) return;

    setIsLinking(true);
    try {
      await linkAnonymousToGoogle();
      Alert.alert(
        "Account Linked",
        "Your account has been successfully linked to Google. Your data is now synced and secure."
      );
    } catch (error: any) {
      Alert.alert(
        "Link Failed",
        error.message || "Failed to link Google account. Please try again."
      );
    } finally {
      setIsLinking(false);
    }
  }, [isLinking]);

  const handleSignOut = useCallback(() => {
    const isAnonymous = user?.isAnonymous ?? true;

    const title = isAnonymous ? "Sign Out of Guest Account" : "Sign Out";
    const message = isAnonymous
      ? "Warning: Signing out will permanently delete all your data since guest accounts cannot be recovered. Consider linking to a Google account first to preserve your data."
      : "Are you sure you want to sign out? Your data will be preserved and you can sign back in later.";

    Alert.alert(
      title,
      message,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: isAnonymous ? "Delete & Sign Out" : "Sign Out",
          style: "destructive",
          onPress: async () => {
            try {
              // Clear user profile first
              setProfile(null);
              await signOut();
              // Navigate to onboarding/setup screen
              router.replace("/(onboarding)/name");
            } catch (error) {
              console.error("Failed to sign out:", error);
              Alert.alert("Error", "Failed to sign out. Please try again.");
            }
          },
        },
      ]
    );
  }, [user?.isAnonymous, setProfile]);

  // Get display name for anonymous user
  const displayName = useMemo(() => {
    if (user?.isAnonymous) {
      return "Anonymous User";
    }
    return user?.displayName || user?.email || "User";
  }, [user]);

  const userId = useMemo(() => {
    return user?.uid ? `${user.uid.slice(0, 8)}...` : "";
  }, [user?.uid]);

  return (
    <GradientBackground>
      <SafeAreaView style={styles.container} edges={["top"]}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Settings</Text>
          <Text style={styles.subtitle}>Account & Activity</Text>
        </View>

        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl refreshing={isLoading} tintColor={colors.text.secondary} />
          }
        >
          {/* Account Section */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>ACCOUNT</Text>
            <GlassCard style={styles.accountCard}>
              <View style={styles.accountRow}>
                <View style={[styles.avatarContainer, user?.isAnonymous && styles.avatarWarning]}>
                  <Ionicons
                    name={user?.isAnonymous ? "warning" : "person"}
                    size={24}
                    color={user?.isAnonymous ? colors.status.warning : colors.text.secondary}
                  />
                </View>
                <View style={styles.accountInfo}>
                  <Text style={styles.accountName}>{displayName}</Text>
                  <Text style={styles.accountId}>ID: {userId}</Text>
                  {user?.isAnonymous && (
                    <Text style={styles.guestWarning}>
                      Guest account - data will be lost on sign out
                    </Text>
                  )}
                  {!user?.isAnonymous && user?.email && (
                    <Text style={styles.accountEmail}>{user.email}</Text>
                  )}
                </View>
                {!user?.isAnonymous && (
                  <View style={styles.syncedBadge}>
                    <Ionicons name="checkmark-circle" size={16} color={colors.status.success} />
                    <Text style={styles.syncedText}>Synced</Text>
                  </View>
                )}
              </View>
            </GlassCard>

            {/* Link Google Account Button - only for anonymous users */}
            {user?.isAnonymous && (
              <View style={styles.linkSection}>
                <GoogleSignInButton
                  onPress={handleLinkGoogle}
                  label="Link Google Account"
                  variant="secondary"
                  disabled={isLinking}
                />
                <Text style={styles.linkHelper}>
                  Link your Google account to sync data across devices and prevent data loss.
                </Text>
              </View>
            )}
          </View>

          {/* Calendar Sync Section */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>CALENDAR</Text>
            <GlassCard style={styles.syncCard}>
              <View style={styles.syncRow}>
                <View style={styles.syncIcon}>
                  <Ionicons name="calendar" size={20} color={colors.primary.blue} />
                </View>
                <View style={styles.syncInfo}>
                  <Text style={styles.syncLabel}>Sync with Apple Calendar</Text>
                  <Text style={styles.syncDescription}>
                    Auto-sync when all hours are allocated
                  </Text>
                </View>
                <Switch
                  value={calendarSyncEnabled}
                  onValueChange={handleToggleCalendarSync}
                  disabled={isTogglingSync}
                  trackColor={{ false: colors.surface.border, true: colors.primary.blue }}
                  thumbColor={colors.text.primary}
                  ios_backgroundColor={colors.surface.border}
                />
              </View>
            </GlassCard>
            <Text style={styles.syncHelper}>
              Creates "FlowPilot - {"{Priority}"}" calendars that sync with macOS.
            </Text>
          </View>

          {/* Activity Log Section */}
          <View style={styles.section}>
            <View style={styles.sectionHeaderRow}>
              <Text style={styles.sectionTitle}>ACTIVITY LOG</Text>
              <Text style={styles.sectionBadge}>{todayCount} today</Text>
            </View>

            {activityGroups.length === 0 ? (
              <GlassCard style={styles.emptyCard}>
                <Ionicons name="time-outline" size={32} color={colors.text.muted} />
                <Text style={styles.emptyText}>No activity yet</Text>
                <Text style={styles.emptySubtext}>
                  Your task activity will appear here
                </Text>
              </GlassCard>
            ) : (
              activityGroups.map((group) => (
                <View key={group.date.toISOString()} style={styles.activityGroup}>
                  <Text style={styles.activityDateLabel}>{group.dateLabel}</Text>
                  <GlassCard style={styles.activityCard}>
                    {group.activities.map((activity, index) => {
                      const actionInfo = getActionInfo(activity.action);
                      const isLast = index === group.activities.length - 1;

                      return (
                        <View
                          key={activity.id}
                          style={[styles.activityRow, !isLast && styles.activityRowBorder]}
                        >
                          <View
                            style={[
                              styles.activityIcon,
                              { backgroundColor: actionInfo.color + "20" },
                            ]}
                          >
                            <Ionicons
                              name={actionInfo.icon as keyof typeof Ionicons.glyphMap}
                              size={14}
                              color={actionInfo.color}
                            />
                          </View>
                          <View style={styles.activityContent}>
                            <Text style={styles.activityTitle} numberOfLines={1}>
                              {activity.taskTitle}
                            </Text>
                            <Text style={styles.activityMeta}>
                              {actionInfo.label} at{" "}
                              {format(activity.timestamp.toDate(), "h:mm a")}
                            </Text>
                          </View>
                        </View>
                      );
                    })}
                  </GlassCard>
                </View>
              ))
            )}
          </View>

          {/* Sign Out Section */}
          <View style={styles.section}>
            <Pressable onPress={handleSignOut} style={styles.signOutButton}>
              <Ionicons name="log-out-outline" size={20} color={colors.status.error} />
              <Text style={styles.signOutText}>Sign Out</Text>
            </Pressable>
            <Text style={styles.signOutHelper}>
              Your data will be saved and you can sign back in anytime.
            </Text>
          </View>

          {/* App Info */}
          <View style={styles.footer}>
            <Text style={styles.version}>PlannerApp v1.0.0</Text>
          </View>
        </ScrollView>
      </SafeAreaView>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.base,
  },
  title: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.bold,
    color: colors.text.primary,
  },
  subtitle: {
    fontSize: typography.fontSize.sm,
    color: colors.text.secondary,
    marginTop: spacing.xs,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: spacing.xl,
    paddingTop: spacing.sm,
    gap: spacing.xl,
  },
  section: {
    gap: spacing.md,
  },
  sectionHeaderRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  sectionTitle: {
    fontSize: typography.fontSize.xs,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.muted,
    letterSpacing: 1,
    marginLeft: spacing.xs,
  },
  sectionBadge: {
    fontSize: typography.fontSize.xs,
    color: colors.text.tertiary,
    marginRight: spacing.xs,
  },
  accountCard: {
    padding: spacing.base,
  },
  accountRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.md,
  },
  avatarContainer: {
    width: 48,
    height: 48,
    borderRadius: borderRadius.full,
    backgroundColor: colors.surface.elevated,
    alignItems: "center",
    justifyContent: "center",
  },
  avatarWarning: {
    backgroundColor: "rgba(245, 158, 11, 0.15)",
    borderWidth: 1,
    borderColor: "rgba(245, 158, 11, 0.3)",
  },
  accountInfo: {
    flex: 1,
  },
  accountName: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.medium,
    color: colors.text.primary,
  },
  accountId: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginTop: 2,
  },
  guestWarning: {
    fontSize: typography.fontSize.xs,
    color: colors.status.warning,
    marginTop: spacing.xs,
    fontWeight: typography.fontWeight.medium,
  },
  accountEmail: {
    fontSize: typography.fontSize.sm,
    color: colors.text.secondary,
    marginTop: 2,
  },
  syncedBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    backgroundColor: "rgba(34, 197, 94, 0.15)",
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.full,
  },
  syncedText: {
    fontSize: typography.fontSize.xs,
    color: colors.status.success,
    fontWeight: typography.fontWeight.medium,
  },
  linkSection: {
    marginTop: spacing.md,
    gap: spacing.sm,
  },
  linkHelper: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginLeft: spacing.xs,
  },
  syncCard: {
    padding: spacing.base,
  },
  syncRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.md,
  },
  syncIcon: {
    width: 40,
    height: 40,
    borderRadius: borderRadius.md,
    backgroundColor: colors.primary.blue + "20",
    alignItems: "center",
    justifyContent: "center",
  },
  syncInfo: {
    flex: 1,
  },
  syncLabel: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.medium,
    color: colors.text.primary,
  },
  syncDescription: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginTop: 2,
  },
  syncHelper: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginLeft: spacing.xs,
    marginTop: spacing.sm,
  },
  emptyCard: {
    padding: spacing.xl,
    alignItems: "center",
    gap: spacing.sm,
  },
  emptyText: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.medium,
    color: colors.text.secondary,
  },
  emptySubtext: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
  },
  activityGroup: {
    gap: spacing.sm,
  },
  activityDateLabel: {
    fontSize: typography.fontSize.sm,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.secondary,
    marginLeft: spacing.xs,
  },
  activityCard: {
    padding: 0,
    overflow: "hidden",
  },
  activityRow: {
    flexDirection: "row",
    alignItems: "center",
    padding: spacing.md,
    gap: spacing.md,
  },
  activityRowBorder: {
    borderBottomWidth: 1,
    borderBottomColor: colors.surface.border,
  },
  activityIcon: {
    width: 28,
    height: 28,
    borderRadius: borderRadius.md,
    alignItems: "center",
    justifyContent: "center",
  },
  activityContent: {
    flex: 1,
  },
  activityTitle: {
    fontSize: typography.fontSize.base,
    color: colors.text.primary,
    fontWeight: typography.fontWeight.medium,
  },
  activityMeta: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginTop: 2,
  },
  signOutButton: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(239, 68, 68, 0.1)",
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: "rgba(239, 68, 68, 0.2)",
    padding: spacing.base,
    gap: spacing.sm,
  },
  signOutText: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.medium,
    color: colors.status.error,
  },
  signOutHelper: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginLeft: spacing.xs,
  },
  footer: {
    paddingVertical: spacing.lg,
    alignItems: "center",
  },
  version: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
  },
});
