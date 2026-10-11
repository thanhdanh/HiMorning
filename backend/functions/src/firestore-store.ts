import type { Firestore } from 'firebase-admin/firestore';
import type { Store, Transaction } from './store.js';
export class FirestoreStore implements Store {
 constructor(private readonly db: Firestore) {}
 transaction<T>(operation: (tx: Transaction) => Promise<T>): Promise<T> {
  return this.db.runTransaction(async native => operation({
   get: async <V>(path: string) => { const snapshot = await native.get(this.db.doc(path)); return snapshot.exists ? snapshot.data() as V : undefined; },
   set: (path, value) => { native.set(this.db.doc(path), value); },
  }));
 }
}
