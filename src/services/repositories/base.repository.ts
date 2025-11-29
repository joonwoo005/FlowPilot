import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  onSnapshot,
  query,
  QueryConstraint,
  DocumentData,
  FirestoreDataConverter,
  Timestamp,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "../firebase/config";

export interface BaseEntity {
  id: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export function createConverter<T extends BaseEntity>(): FirestoreDataConverter<T> {
  return {
    toFirestore: (data: T): DocumentData => {
      const { id, ...rest } = data;
      return rest;
    },
    fromFirestore: (snapshot, options): T => {
      const data = snapshot.data(options);
      return {
        id: snapshot.id,
        ...data,
      } as T;
    },
  };
}

export abstract class BaseRepository<T extends BaseEntity> {
  protected abstract collectionPath: string;
  protected converter: FirestoreDataConverter<T>;

  constructor() {
    this.converter = createConverter<T>();
  }

  protected getCollectionRef(userId: string) {
    return collection(db, "users", userId, this.collectionPath).withConverter(
      this.converter
    );
  }

  protected getDocRef(userId: string, docId: string) {
    return doc(db, "users", userId, this.collectionPath, docId).withConverter(
      this.converter
    );
  }

  async getById(userId: string, docId: string): Promise<T | null> {
    const docSnap = await getDoc(this.getDocRef(userId, docId));
    return docSnap.exists() ? docSnap.data() : null;
  }

  async getAll(userId: string, ...constraints: QueryConstraint[]): Promise<T[]> {
    const q = query(this.getCollectionRef(userId), ...constraints);
    const snapshot = await getDocs(q);
    return snapshot.docs.map((doc) => doc.data());
  }

  subscribe(userId: string, docId: string, callback: (data: T | null) => void) {
    return onSnapshot(this.getDocRef(userId, docId), (snapshot) => {
      callback(snapshot.exists() ? snapshot.data() : null);
    });
  }

  subscribeAll(
    userId: string,
    callback: (data: T[]) => void,
    ...constraints: QueryConstraint[]
  ) {
    const q = query(this.getCollectionRef(userId), ...constraints);
    return onSnapshot(q, (snapshot) => {
      callback(snapshot.docs.map((doc) => doc.data()));
    });
  }

  async create(
    userId: string,
    data: Omit<T, "id" | "createdAt" | "updatedAt">
  ): Promise<string> {
    const docRef = doc(this.getCollectionRef(userId));
    await setDoc(docRef, {
      ...data,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    return docRef.id;
  }

  async update(userId: string, docId: string, data: Partial<T>): Promise<void> {
    const { id, createdAt, ...updateData } = data as any;
    await updateDoc(this.getDocRef(userId, docId), {
      ...updateData,
      updatedAt: serverTimestamp(),
    });
  }

  async delete(userId: string, docId: string): Promise<void> {
    await deleteDoc(this.getDocRef(userId, docId));
  }
}
