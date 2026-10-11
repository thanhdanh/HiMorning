import { z } from 'zod';
export type ErrorCode = 'invalid-argument' | 'unauthenticated' | 'permission-denied' | 'not-found' | 'already-exists' | 'resource-exhausted';
export class Failure extends Error {
 constructor(public readonly code: ErrorCode, message: string) { super(message); }
}
export function parse<T>(schema: z.ZodType<T>, data: unknown): T {
 const result = schema.safeParse(data);
 if (!result.success) throw new Failure('invalid-argument', 'Invalid verification request');
 return result.data;
}
