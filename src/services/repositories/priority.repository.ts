import { orderBy, writeBatch, doc } from "firebase/firestore";
import { db } from "../firebase/config";
import { BaseRepository } from "./base.repository";
import { Priority, PriorityCreateInput } from "@/types";

class PriorityRepository extends BaseRepository<Priority> {
  protected collectionPath = "priorities";

  subscribeAll(userId: string, callback: (data: Priority[]) => void) {
    return super.subscribeAll(userId, callback, orderBy("order", "asc"));
  }

  async createWithOrder(
    userId: string,
    input: PriorityCreateInput,
    existingCount: number
  ): Promise<string> {
    return super.create(userId, {
      ...input,
      weeklyHoursTarget: 0,
      order: input.order ?? existingCount,
    } as Omit<Priority, "id" | "createdAt" | "updatedAt">);
  }

  async updateWeeklyHours(
    userId: string,
    priorityId: string,
    weeklyHoursTarget: number
  ): Promise<void> {
    await this.update(userId, priorityId, { weeklyHoursTarget });
  }

  async reorder(userId: string, priorityIds: string[]): Promise<void> {
    const batch = writeBatch(db);

    priorityIds.forEach((id, index) => {
      const ref = doc(db, "users", userId, this.collectionPath, id);
      batch.update(ref, { order: index });
    });

    await batch.commit();
  }
}

export const priorityRepository = new PriorityRepository();
