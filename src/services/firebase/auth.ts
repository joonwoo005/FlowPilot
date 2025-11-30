import {
  signInAnonymously as firebaseSignInAnonymously,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  User as FirebaseUser,
  GoogleAuthProvider,
  signInWithCredential,
  linkWithCredential,
  AuthErrorCodes,
} from "firebase/auth";
import { auth } from "./config";
import Constants from "expo-constants";

// iOS Client ID from Google Cloud Console (Project: FlowPilot)
const IOS_CLIENT_ID = "163168772644-4g9vrqn2msepnrdggtcp28vtrqcdj582.apps.googleusercontent.com";

// Only import and configure Google Sign-In in development builds (not Expo Go)
let GoogleSignin: any = null;
let statusCodes: any = {};
let isSuccessResponse: any = () => false;
let isErrorWithCode: any = () => false;

const isExpoGo = Constants.appOwnership === "expo";

if (!isExpoGo) {
  try {
    const googleSignIn = require("@react-native-google-signin/google-signin");
    GoogleSignin = googleSignIn.GoogleSignin;
    statusCodes = googleSignIn.statusCodes;
    isSuccessResponse = googleSignIn.isSuccessResponse;
    isErrorWithCode = googleSignIn.isErrorWithCode;

    // Configure Google Sign-In
    GoogleSignin.configure({
      iosClientId: IOS_CLIENT_ID,
      offlineAccess: true,
    });
  } catch (e) {
    console.log("Google Sign-In not available (Expo Go or missing native module)");
  }
}

export const signInAnonymously = async (): Promise<FirebaseUser> => {
  const result = await firebaseSignInAnonymously(auth);
  return result.user;
};

export const signOut = async (): Promise<void> => {
  // Sign out from Google if signed in (only in dev builds)
  if (GoogleSignin) {
    try {
      const isSignedIn = GoogleSignin.getCurrentUser() !== null;
      if (isSignedIn) {
        await GoogleSignin.signOut();
      }
    } catch (error) {
      console.log("Google sign out error (may not be signed in):", error);
    }
  }
  await firebaseSignOut(auth);
};

export const subscribeToAuthState = (
  callback: (user: FirebaseUser | null) => void
): (() => void) => {
  return onAuthStateChanged(auth, callback);
};

/**
 * Check if Google Sign-In is available (only in development builds, not Expo Go)
 */
export const isGoogleSignInAvailable = (): boolean => {
  return GoogleSignin !== null && !isExpoGo;
};

/**
 * Sign in with Google
 * If user is anonymous, links the Google account to preserve data
 * If linking fails because credential is in use, signs in with Google account
 */
export const signInWithGoogle = async (): Promise<FirebaseUser> => {
  if (!GoogleSignin) {
    throw new Error("Google Sign-In is not available in Expo Go. Please use a development build.");
  }

  try {
    // Check if we have play services (not needed on iOS but required for Android)
    await GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });

    // Perform Google Sign-In
    const response = await GoogleSignin.signIn();

    if (!isSuccessResponse(response)) {
      throw new Error("Google Sign-In was cancelled or failed");
    }

    const { data } = response;
    const idToken = data.idToken;

    if (!idToken) {
      throw new Error("No ID token received from Google");
    }

    // Create Firebase credential
    const credential = GoogleAuthProvider.credential(idToken);

    const currentUser = auth.currentUser;

    // If user is anonymous, try to link accounts
    if (currentUser && currentUser.isAnonymous) {
      try {
        const result = await linkWithCredential(currentUser, credential);
        return result.user;
      } catch (linkError: any) {
        // If linking fails because the credential is already in use,
        // sign in with the Google account instead (data will be lost from anonymous account)
        if (linkError.code === AuthErrorCodes.CREDENTIAL_ALREADY_IN_USE ||
            linkError.code === "auth/credential-already-in-use") {
          console.log("Credential already in use, signing in with Google account");
          const result = await signInWithCredential(auth, credential);
          return result.user;
        }
        throw linkError;
      }
    }

    // Fresh sign in (no existing anonymous user)
    const result = await signInWithCredential(auth, credential);
    return result.user;
  } catch (error: any) {
    if (isErrorWithCode(error)) {
      switch (error.code) {
        case statusCodes.SIGN_IN_CANCELLED:
          throw new Error("Sign-in was cancelled");
        case statusCodes.IN_PROGRESS:
          throw new Error("Sign-in is already in progress");
        case statusCodes.PLAY_SERVICES_NOT_AVAILABLE:
          throw new Error("Play Services not available");
        default:
          throw new Error(error.message || "Google Sign-In failed");
      }
    }
    throw error;
  }
};

/**
 * Link existing anonymous account to Google
 * Preserves all existing data
 */
export const linkAnonymousToGoogle = async (): Promise<FirebaseUser> => {
  if (!GoogleSignin) {
    throw new Error("Google Sign-In is not available in Expo Go. Please use a development build.");
  }

  const currentUser = auth.currentUser;

  if (!currentUser) {
    throw new Error("No user is currently signed in");
  }

  if (!currentUser.isAnonymous) {
    throw new Error("Current user is not anonymous");
  }

  try {
    await GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });

    const response = await GoogleSignin.signIn();

    if (!isSuccessResponse(response)) {
      throw new Error("Google Sign-In was cancelled or failed");
    }

    const { data } = response;
    const idToken = data.idToken;

    if (!idToken) {
      throw new Error("No ID token received from Google");
    }

    const credential = GoogleAuthProvider.credential(idToken);

    try {
      const result = await linkWithCredential(currentUser, credential);
      return result.user;
    } catch (linkError: any) {
      if (linkError.code === AuthErrorCodes.CREDENTIAL_ALREADY_IN_USE ||
          linkError.code === "auth/credential-already-in-use") {
        throw new Error(
          "This Google account is already linked to another user. Please sign out and sign in with that Google account instead."
        );
      }
      throw linkError;
    }
  } catch (error: any) {
    if (isErrorWithCode(error)) {
      switch (error.code) {
        case statusCodes.SIGN_IN_CANCELLED:
          throw new Error("Linking was cancelled");
        case statusCodes.IN_PROGRESS:
          throw new Error("Sign-in is already in progress");
        default:
          throw new Error(error.message || "Google Sign-In failed");
      }
    }
    throw error;
  }
};

/**
 * Get current Google user info if signed in with Google
 */
export const getGoogleUserInfo = () => {
  if (!GoogleSignin) return null;
  return GoogleSignin.getCurrentUser();
};

export type { FirebaseUser };
