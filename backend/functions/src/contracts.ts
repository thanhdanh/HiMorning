import { z } from 'zod';

// Public wire shapes. Keep platform UI and provider verdicts outside this module.
export const CONSENT_VERSION = '2026-10-11';
export const LIMITS = Object.freeze({ maxFrames: 25, maxFrameBytes: 50000, maxTotalBytes: 1250000, maxDimension: 512, framesPerRep: 5 });
export const sessionIDSchema = z.string().regex(/^[a-f0-9]{64}$/);
export const createSchema = z.object({
 requestID: z.uuid(), challenge: z.literal('pushup'), target: z.number().int().min(1).max(5), consentVersion: z.literal(CONSENT_VERSION),
}).strict();
export const cancelSchema = z.object({ sessionID: sessionIDSchema }).strict();
export const submissionSchema = z.object({
 sessionID: sessionIDSchema, nonce: z.uuid(), evidenceID: z.uuid(), consentVersion: z.literal(CONSENT_VERSION),
 frames: z.array(z.object({ id: z.string().regex(/^[a-zA-Z0-9_-]{1,32}$/), timestampMs: z.number().int().min(0).max(120000), jpegBase64: z.string().min(4).max(66668) }).strict()).min(1).max(LIMITS.maxFrames),
}).strict();
const decisionSchema = z.object({
 status: z.enum(['verified','incomplete','uncertain','unavailable','pending','cancelled','expired']),
 reasonCode: z.string(), decisionID: z.string(), verifiedRepCount: z.number().int().min(0).max(5).optional(),
 cue: z.enum(['none','adjust_camera']).optional(),
}).strict();
export type VerificationResult = z.infer<typeof decisionSchema>;
export const contractSchemas = {
 CreateRequest: createSchema,
 CreateResponse: z.object({
  sessionID: sessionIDSchema, nonce: z.uuid(), expiresAt: z.number().int().nonnegative(),
  limits: z.object({ maxFrames:z.literal(25),maxFrameBytes:z.literal(50000),maxTotalBytes:z.literal(1250000),maxDimension:z.literal(512),framesPerRep:z.literal(5) }).strict(),
 }).strict(),
 SubmitRequest: submissionSchema,
 Decision: decisionSchema,
 CancelRequest: cancelSchema,
 CancelResponse: z.object({status:z.literal('cancelled')}).strict(),
};
