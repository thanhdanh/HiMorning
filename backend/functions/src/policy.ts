import { createHash } from 'node:crypto';
import { z } from 'zod';
export { CONSENT_VERSION, LIMITS, sessionIDSchema, submissionSchema } from './contracts.js';
export const POLICY_VERSION = 'pilot-v1';
export interface Evidence { frames: { id: string; timestampMs: number; dataURL: string }[]; payloadHash: string; sufficient: boolean }
export interface DecisionEvidence { frames: { id: string }[]; sufficient: boolean }
export const hash = (value: string) => createHash('sha256').update(value).digest('hex');
export const verdictSchema = z.object({ status: z.enum(['complete','incomplete','uncertain']), reps: z.array(z.object({ frameIDs: z.array(z.string()).length(5) }).strict()).max(5), cue: z.enum(['none','adjust_camera']) }).strict();
export type Verdict = z.infer<typeof verdictSchema>;
export type Decision = { status: 'verified' | 'incomplete' | 'uncertain'; reasonCode: string; verifiedRepCount: number; cue: 'none' | 'adjust_camera' };
export function decide(raw: unknown, evidence: DecisionEvidence, target: number): Decision {
 const uncertain: Decision = { status: 'uncertain', reasonCode: 'unclear_evidence', verifiedRepCount: 0, cue: 'none' };
 const parsed = verdictSchema.safeParse(raw);
 if (!parsed.success) return uncertain;
 const value = parsed.data;
 if (value.status === 'uncertain') return { ...uncertain, cue: value.cue };
 if (value.reps.length > target) return uncertain;
 let previousEnd = -1;
 for (const rep of value.reps) {
  const indices = rep.frameIDs.map(id => evidence.frames.findIndex(frame => frame.id === id));
  if (indices.some((index,i) => index < 0 || (i > 0 && index <= indices[i-1])) || indices[0] <= previousEnd) return uncertain;
  previousEnd = indices[4];
 }
 const verified = value.status === 'complete' && value.reps.length === target && evidence.sufficient;
 return { status: verified ? 'verified' : 'incomplete', reasonCode: verified ? 'observed_cycles' : 'incomplete_cycles', verifiedRepCount: verified ? target : 0, cue: value.cue };
}
