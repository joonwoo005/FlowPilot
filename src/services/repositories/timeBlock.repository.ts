import { where, orderBy } from "firebase/firestore";
import { BaseRepository } from "./base.repository";
import { TimeBlock, TimeBlockCreateInput } from "@/types";
import { getWeekInfo } from "@/utils";

class TimeBlockRepository extends BaseRepository<TimeBlock> {
  protected collectionPath = "timeBlocks";

  subscribeByWeek(
    userId: string,
    weekNumber: number,
    year: number,
    callback: (data: TimeBlock[]) => void
  ) {
    return super.subscribeAll(
      userId,
      callback,
      where("weekNumber", "==", weekNumber),
      where("year", "==", year),
      orderBy("dayOfWeek", "asc"),
      orderBy("startTime", "asc")
    );
  }

  subscribeWeekWithOffset(
    userId: string,
    weekOffset: number,
    callback: (data: TimeBlock[]) => void
  ) {
    const { weekNumber, year } = getWeekInfo(weekOffset);
    return this.subscribeByWeek(userId, weekNumber, year, callback);
  }

  async createForWeek(
    userId: string,
    input: TimeBlockCreateInput,
    weekOffset: number = 0
  ): Promise<string> {
    const { weekNumber, year } = getWeekInfo(weekOffset);
    return super.create(userId, {
      ...input,
      weekNumber,
      year,
    } as Omit<TimeBlock, "id" | "createdAt" | "updatedAt">);
  }
}

export const timeBlockRepository = new TimeBlockRepository();
