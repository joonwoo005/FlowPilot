import {
  collection,
  doc,
  addDoc,
  deleteDoc,
  onSnapshot,
  query,
  orderBy,
  limit,
  getDocs,
  Timestamp,
  DocumentData,
  FirestoreDataConverter,
} from "firebase/firestore";
import { db } from "../firebase/config";
import { Activity, ActivityCreateInput } from "@/types";

// Custom converter for Activity (no createdAt/updatedAt)
function createActivityConverter(): FirestoreDataConverter<Activity> {
  return {
    toFirestore: (data: Activity): DocumentData => {
      const { id, ...rest } = data;
      return rest;
    },
    fromFirestore: (snapshot, options): Activity => {
      const data = snapshot.data(options);
      return {
        id: snapshot.id,
        ...data,
      } as Activity;
    },
  };
}

const activityConverter = createActivityConverter();

class ActivityRepository {
  private collectionPath = "activityLogs";

  private getCollectionRef(userId: string) {
    return collection(db, "users", userId, this.collectionPath).withConverter(
      activityConverter
    );
  }

  /**
   * Subscribe to all activities ordered by timestamp (newest first)
   */
  subscribeAll(userId: string, callback: (data: Activity[]) => void) {
    const q = query(this.getCollectionRef(userId), orderBy("timestamp", "desc"));

    return onSnapshot(q, (snapshot) => {
      const data = snapshot.docs.map((doc) => doc.data());
      callback(data);
    });
  }

  /**
   * Subscribe to recent activities with a limit
   */
  subscribeRecent(
    userId: string,
    callback: (data: Activity[]) => void,
    count: number = 50
  ) {
    const q = query(
      this.getCollectionRef(userId),
      orderBy("timestamp", "desc"),
      limit(count)
    );

    return onSnapshot(q, (snapshot) => {
      const data = snapshot.docs.map((doc) => doc.data());
      callback(data);
    });
  }

  /**
   * Log a new activity
   */
  async logActivity(userId: string, input: ActivityCreateInput): Promise<string> {
    const activityData = {
      taskId: input.taskId,
      taskTitle: input.taskTitle,
      action: input.action,
      timestamp: Timestamp.now(),
    };

    const colRef = collection(db, "users", userId, this.collectionPath);
    const docRef = await addDoc(colRef, activityData);
    return docRef.id;
  }

  /**
   * Get recent activities
   */
  async getRecent(userId: string, count: number = 50): Promise<Activity[]> {
    const q = query(
      this.getCollectionRef(userId),
      orderBy("timestamp", "desc"),
      limit(count)
    );
    const snapshot = await getDocs(q);
    return snapshot.docs.map((doc) => doc.data());
  }

  /**
   * Delete an activity
   */
  async delete(userId: string, activityId: string): Promise<void> {
    const docRef = doc(db, "users", userId, this.collectionPath, activityId);
    await deleteDoc(docRef);
  }

  /**
   * Delete all activities for a task (when task is permanently deleted)
   */
  async deleteForTask(userId: string, taskId: string): Promise<void> {
    const activities = await this.getRecent(userId, 1000);
    const taskActivities = activities.filter((a) => a.taskId === taskId);

    for (const activity of taskActivities) {
      await this.delete(userId, activity.id);
    }
  }
}

export const activityRepository = new ActivityRepository();
