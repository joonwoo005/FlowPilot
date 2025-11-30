import {
  orderBy,
  writeBatch,
  doc,
  where,
  query,
  getDocs,
  Timestamp,
  deleteField,
} from "firebase/firestore";
import { db } from "../firebase/config";
import { BaseRepository } from "./base.repository";
import { Task, TaskCreateInput, TaskUpdateInput } from "@/types";

class TaskRepository extends BaseRepository<Task> {
  protected collectionPath = "tasks";

  /**
   * Subscribe to all tasks ordered by creation date
   */
  subscribeAll(userId: string, callback: (data: Task[]) => void) {
    return super.subscribeAll(userId, callback, orderBy("createdAt", "desc"));
  }

  /**
   * Subscribe to active (non-completed) tasks only
   */
  subscribeActive(userId: string, callback: (data: Task[]) => void) {
    return super.subscribeAll(
      userId,
      callback,
      where("isCompleted", "==", false),
      orderBy("createdAt", "desc")
    );
  }

  /**
   * Create a new task
   */
  async createTask(userId: string, input: TaskCreateInput): Promise<string> {
    const taskData: Omit<Task, "id" | "createdAt" | "updatedAt"> = {
      title: input.title,
      isCompleted: false,
      ...(input.priorityId && { priorityId: input.priorityId }),
      ...(input.priorityName && { priorityName: input.priorityName }),
      ...(input.priorityColor && { priorityColor: input.priorityColor }),
      ...(input.timeBlockId && { timeBlockId: input.timeBlockId }),
      ...(input.timeBlockDate && { timeBlockDate: Timestamp.fromDate(input.timeBlockDate) }),
      ...(input.timeBlockStartTime && { timeBlockStartTime: input.timeBlockStartTime }),
      ...(input.timeBlockDurationMinutes && { timeBlockDurationMinutes: input.timeBlockDurationMinutes }),
    };

    return super.create(userId, taskData);
  }

  /**
   * Complete a task
   */
  async completeTask(userId: string, taskId: string): Promise<void> {
    await this.update(userId, taskId, { isCompleted: true });
  }

  /**
   * Uncomplete a task
   */
  async uncompleteTask(userId: string, taskId: string): Promise<void> {
    await this.update(userId, taskId, { isCompleted: false });
  }

  /**
   * Link task to a time block (copies priority info from block)
   */
  async linkToTimeBlock(
    userId: string,
    taskId: string,
    timeBlockId: string,
    timeBlockDate: Date,
    timeBlockStartTime: string,
    timeBlockDurationMinutes: number,
    priorityId: string,
    priorityName: string,
    priorityColor: string
  ): Promise<void> {
    await this.update(userId, taskId, {
      timeBlockId,
      timeBlockDate: Timestamp.fromDate(timeBlockDate),
      timeBlockStartTime,
      timeBlockDurationMinutes,
      priorityId,
      priorityName,
      priorityColor,
    } as Partial<Task>);
  }

  /**
   * Unlink task from time block
   */
  async unlinkFromTimeBlock(userId: string, taskId: string): Promise<void> {
    const docRef = this.getDocRef(userId, taskId);
    const batch = writeBatch(db);

    batch.update(docRef, {
      timeBlockId: deleteField(),
      timeBlockDate: deleteField(),
      timeBlockStartTime: deleteField(),
      timeBlockDurationMinutes: deleteField(),
    });

    await batch.commit();
  }

  /**
   * Get all tasks linked to a specific time block
   */
  async getTasksLinkedToBlock(userId: string, timeBlockId: string): Promise<Task[]> {
    const q = query(
      this.getCollectionRef(userId),
      where("timeBlockId", "==", timeBlockId)
    );
    const snapshot = await getDocs(q);
    return snapshot.docs.map((doc) => doc.data());
  }

  /**
   * Unlink all tasks from a time block (cascade on block delete)
   */
  async unlinkAllFromTimeBlock(userId: string, timeBlockId: string): Promise<void> {
    const tasks = await this.getTasksLinkedToBlock(userId, timeBlockId);

    if (tasks.length === 0) return;

    const batch = writeBatch(db);

    for (const task of tasks) {
      const docRef = this.getDocRef(userId, task.id);
      batch.update(docRef, {
        timeBlockId: deleteField(),
        timeBlockDate: deleteField(),
        timeBlockStartTime: deleteField(),
        timeBlockDurationMinutes: deleteField(),
      });
    }

    await batch.commit();
  }

  /**
   * Update task with partial data
   */
  async updateTask(userId: string, taskId: string, input: TaskUpdateInput): Promise<void> {
    const updateData: Record<string, unknown> = {};

    // Only include defined values
    if (input.title !== undefined) updateData.title = input.title;
    if (input.isCompleted !== undefined) updateData.isCompleted = input.isCompleted;

    // Handle nullable priority fields
    if (input.priorityId === null) {
      updateData.priorityId = deleteField();
      updateData.priorityName = deleteField();
      updateData.priorityColor = deleteField();
    } else if (input.priorityId !== undefined) {
      updateData.priorityId = input.priorityId;
      if (input.priorityName !== undefined) updateData.priorityName = input.priorityName;
      if (input.priorityColor !== undefined) updateData.priorityColor = input.priorityColor;
    }

    // Handle nullable time block fields
    if (input.timeBlockId === null) {
      updateData.timeBlockId = deleteField();
      updateData.timeBlockDate = deleteField();
      updateData.timeBlockStartTime = deleteField();
      updateData.timeBlockDurationMinutes = deleteField();
    } else if (input.timeBlockId !== undefined) {
      updateData.timeBlockId = input.timeBlockId;
      if (input.timeBlockDate !== undefined && input.timeBlockDate !== null) {
        updateData.timeBlockDate = Timestamp.fromDate(input.timeBlockDate);
      }
      if (input.timeBlockStartTime !== undefined) updateData.timeBlockStartTime = input.timeBlockStartTime;
      if (input.timeBlockDurationMinutes !== undefined) updateData.timeBlockDurationMinutes = input.timeBlockDurationMinutes;
    }

    if (Object.keys(updateData).length > 0) {
      await this.update(userId, taskId, updateData as Partial<Task>);
    }
  }
}

export const taskRepository = new TaskRepository();
