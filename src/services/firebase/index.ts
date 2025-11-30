export { auth, db } from "./config";
export {
  signInAnonymously,
  signOut,
  subscribeToAuthState,
  signInWithGoogle,
  linkAnonymousToGoogle,
  getGoogleUserInfo,
  isGoogleSignInAvailable,
  type FirebaseUser,
} from "./auth";
