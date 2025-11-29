import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  onSnapshot,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "../firebase/config";
import { User } from "@/types";

class UserRepository {
  private getUserDocRef(userId: string) {
    return doc(db, "users", userId);
  }

  async get(userId: string): Promise<User | null> {
    const docSnap = await getDoc(this.getUserDocRef(userId));
    if (!docSnap.exists()) return null;
    return { id: docSnap.id, ...docSnap.data() } as User;
  }

  subscribe(userId: string, callback: (user: User | null) => void) {
    return onSnapshot(this.getUserDocRef(userId), (snapshot) => {
      if (!snapshot.exists()) {
        callback(null);
        return;
      }
      callback({ id: snapshot.id, ...snapshot.data() } as User);
    });
  }

  async create(userId: string, name: string): Promise<void> {
    await setDoc(this.getUserDocRef(userId), {
      name,
      sleepTime: "",
      wakeTime: "",
      awakeHoursPerDay: 0,
      onboardingComplete: false,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  async update(userId: string, data: Partial<Omit<User, "id">>): Promise<void> {
    await updateDoc(this.getUserDocRef(userId), {
      ...data,
      updatedAt: serverTimestamp(),
    });
  }

  async updateName(userId: string, name: string): Promise<void> {
    await this.update(userId, { name });
  }

  async updateSleepSchedule(
    userId: string,
    sleepTime: string,
    wakeTime: string,
    awakeHoursPerDay: number
  ): Promise<void> {
    await this.update(userId, { sleepTime, wakeTime, awakeHoursPerDay });
  }

  async completeOnboarding(userId: string): Promise<void> {
    await this.update(userId, { onboardingComplete: true });
  }
}

export const userRepository = new UserRepository();
