import { z } from 'zod';

// Public wire shapes. Keep platform UI and provider verdicts outside this module.
export const CONSENT_VERSION = '2026-10-15';
export const DEMO_CONSENT_VERSION = '2026-10-15-free-demo';
const consentSchema = z.enum([CONSENT_VERSION, DEMO_CONSENT_VERSION]);
export const SESSION_DURATION_MS = 600000;
export const JOB_DURATION_MS = 180000;
export const LIMITS = Object.freeze({ maxFrames: 250, maxFrameBytes: 50000, maxTotalBytes: 12500000, maxDimension: 512, framesPerRep: 5 });
export const sessionIDSchema = z.string().regex(/^[a-f0-9]{64}$/);
export const createSchema = z.object({
 requestID: z.uuid(), challenge: z.literal('pushup'), target: z.number().int().min(1).max(50), consentVersion: consentSchema,
}).strict();
export const cancelSchema = z.object({ sessionID: sessionIDSchema }).strict();
export const resultSchema = z.object({ sessionID: sessionIDSchema, evidenceID: z.uuid() }).strict();
export const submissionSchema = z.object({
 sessionID: sessionIDSchema, nonce: z.uuid(), evidenceID: z.uuid(), consentVersion: consentSchema,
 frames: z.array(z.object({ id: z.string().regex(/^[a-zA-Z0-9_-]{1,32}$/), timestampMs: z.number().int().min(0).max(300000), jpegBase64: z.string().min(4).max(66668) }).strict()).min(1).max(LIMITS.maxFrames),
}).strict();
const decisionSchema = z.object({
 status: z.enum(['verified','incomplete','uncertain','unavailable','pending','cancelled','expired']),
 reasonCode: z.string(), decisionID: z.string(), verifiedRepCount: z.number().int().min(0).max(50).optional(),
 cue: z.enum(['none','adjust_camera']).optional(),
}).strict();
export type VerificationResult = z.infer<typeof decisionSchema>;
export const contractSchemas = {
 CreateRequest: createSchema,
 CreateResponse: z.object({
  sessionID: sessionIDSchema, nonce: z.uuid(), expiresAt: z.number().int().nonnegative(),
  limits: z.object({ maxFrames:z.union([z.literal(25),z.literal(100),z.literal(250)]),maxFrameBytes:z.literal(50000),maxTotalBytes:z.union([z.literal(1250000),z.literal(5000000),z.literal(12500000)]),maxDimension:z.literal(512),framesPerRep:z.literal(5) }).strict(),
 }).strict(),
 SubmitRequest: submissionSchema,
 ResultRequest: resultSchema,
 Decision: decisionSchema,
 CancelRequest: cancelSchema,
 CancelResponse: z.object({status:z.literal('cancelled')}).strict(),
};
