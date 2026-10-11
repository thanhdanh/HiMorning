import sharp from 'sharp';
export const uuid = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
export const actor = { uid: 'guest-1', appCheck: true };
export const config = { enabled: true, model: 'test-model', userDailyLimit: 3, globalDailyLimit: 100 };
export const createInput = (n = 1, target = 1) => ({ requestID: uuid(n), challenge: 'pushup', target, consentVersion: '2026-10-11' });
export async function frames(count = 5) {
 return Promise.all(Array.from({ length: count }, async (_, i) => ({ id: `f${i}`, timestampMs: i * 300, jpegBase64: (await sharp({ create: { width: 40, height: 40, channels: 3, background: { r: 20 + i * 5, g: 40, b: 80 } } }).jpeg().toBuffer()).toString('base64') })));
}
export const complete = (count = 1) => ({ status: 'complete', reps: Array.from({ length: count }, (_, i) => ({ frameIDs: Array.from({ length: 5 }, (_, j) => `f${i * 5 + j}`) })), cue: 'none' });
// Serial transaction double: no external model calls in this critical section.
export class MemoryStore {
 docs = new Map<string, any>();
 writes = 0;
 private tail: Promise<unknown> = Promise.resolve();
 transaction<T>(operation: (tx: any) => Promise<T>): Promise<T> {
  const run = this.tail.then(async () => {
   const staged = new Map(this.docs);let writes=0;
   const result = await operation({ get: async (path: string) => structuredClone(staged.get(path)), set: (path: string, value: unknown) => {writes++;staged.set(path, structuredClone(value));} });
   this.docs = staged; this.writes+=writes;return result;
  });
  this.tail = run.catch(() => undefined); return run;
 }
}
