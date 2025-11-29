import { useEffect } from "react";
import { subscribeToAuthState, signInAnonymously, signOut } from "@/services/firebase";
import { useAuthStore } from "@/stores";

export function useAuth() {
  const { user, isLoading, isAuthenticated, setUser, setLoading } = useAuthStore();

  useEffect(() => {
    const unsubscribe = subscribeToAuthState((firebaseUser) => {
      setUser(firebaseUser);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [setUser, setLoading]);

  return {
    user,
    isLoading,
    isAuthenticated,
    signInAnonymously,
    signOut,
  };
}
