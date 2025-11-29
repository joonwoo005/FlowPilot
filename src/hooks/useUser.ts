import { useEffect } from "react";
import { useAuthStore, useUserStore } from "@/stores";
import { userRepository } from "@/services/repositories";

export function useUser() {
  const { user } = useAuthStore();
  const { profile, isLoading, setProfile, setLoading } = useUserStore();

  useEffect(() => {
    if (!user?.uid) {
      setProfile(null);
      return;
    }

    setLoading(true);
    const unsubscribe = userRepository.subscribe(user.uid, (userData) => {
      setProfile(userData);
    });

    return () => unsubscribe();
  }, [user?.uid, setProfile, setLoading]);

  const totalWeeklyAwakeHours = profile ? profile.awakeHoursPerDay * 7 : 0;

  return {
    profile,
    isLoading,
    totalWeeklyAwakeHours,
    isOnboardingComplete: profile?.onboardingComplete ?? false,
  };
}
