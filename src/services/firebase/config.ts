import { initializeApp } from "firebase/app";
import { initializeAuth, getReactNativePersistence } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import AsyncStorage from "@react-native-async-storage/async-storage";

const firebaseConfig = {
  apiKey: "AIzaSyCEWWsrPtDVSb1MWnes0HttwU9q9GZQlPQ",
  authDomain: "plannerapp-eaa11.firebaseapp.com",
  projectId: "plannerapp-eaa11",
  storageBucket: "plannerapp-eaa11.firebasestorage.app",
  messagingSenderId: "258718008090",
  appId: "1:258718008090:web:0b5d656a58928c3b7822a3",
};

const app = initializeApp(firebaseConfig);

export const auth = initializeAuth(app, {
  persistence: getReactNativePersistence(AsyncStorage),
});
export const db = getFirestore(app);
export default app;
