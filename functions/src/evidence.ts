import { createHash } from 'node:crypto';
import sharp from 'sharp';
import { z } from 'zod';
import { Failure, parse } from './errors.js';
export const CONSENT_VERSION = '2026-10-11';
export const POLICY_VERSION = 'pilot-v1';
export const LIMITS = Object.freeze({ maxFrames: 25, maxFrameBytes: 50000, maxTotalBytes: 1250000, maxDimension: 512, framesPerRep: 5 });
export const sessionIDSchema = z.string().regex(/^[a-f0-9]{64}$/);
export const submissionSchema = z.object({
 sessionID: sessionIDSchema, nonce: z.uuid(), evidenceID: z.uuid(), consentVersion: z.literal(CONSENT_VERSION),
 frames: z.array(z.object({ id: z.string().regex(/^[a-zA-Z0-9_-]{1,32}$/), timestampMs: z.number().int().min(0).max(120000), jpegBase64: z.string().min(4).max(66668) }).strict()).min(1).max(LIMITS.maxFrames),
}).strict();
export interface Evidence { frames: { id: string; timestampMs: number; dataURL: string }[]; payloadHash: string; sufficient: boolean }
export const hash = (value: string) => createHash('sha256').update(value).digest('hex');
export const verdictSchema = z.object({ status: z.enum(['complete','incomplete','uncertain']), reps: z.array(z.object({ frameIDs: z.array(z.string()).length(5) }).strict()).max(5), cue: z.enum(['none','adjust_camera']) }).strict();
export type Verdict = z.infer<typeof verdictSchema>;
export type Decision = { status: 'verified' | 'incomplete' | 'uncertain'; reasonCode: string; verifiedRepCount: number; cue: 'none' | 'adjust_camera' };
export async function prepareEvidence(input: unknown, target: number): Promise<Evidence> {
 const data = parse(submissionSchema, input);
 const ids = new Set<string>(), images = new Set<string>(); let total = 0, previous = -1;
 const normalized: Evidence['frames'] = [];
 for (const frame of data.frames) {
  if (ids.has(frame.id) || frame.timestampMs <= previous) throw new Failure('invalid-argument', 'Frames must be unique and ordered');
  ids.add(frame.id); previous = frame.timestampMs;
  if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(frame.jpegBase64)) throw new Failure('invalid-argument', 'Invalid JPEG encoding');
  const bytes = Buffer.from(frame.jpegBase64, 'base64'); total += bytes.length;
  if (bytes.length > LIMITS.maxFrameBytes || total > LIMITS.maxTotalBytes || bytes.toString('base64') !== frame.jpegBase64) throw new Failure('invalid-argument', 'Image budget exceeded');
  const imageHash = hash(frame.jpegBase64);
  if (images.has(imageHash)) throw new Failure('invalid-argument', 'Repeated image');
  images.add(imageHash);
  try {
   const image = sharp(bytes, { limitInputPixels: LIMITS.maxDimension ** 2 });
   const meta = await image.metadata();
   if (meta.format !== 'jpeg' || !meta.width || !meta.height || Math.max(meta.width, meta.height) > LIMITS.maxDimension) throw new Error('Unsupported image');
   // Force decode and strip EXIF/GPS; malformed/truncated JPEGs do not reach the model.
   const clean = await image.rotate().jpeg({ quality: 60 }).toBuffer();
   normalized.push({ id: frame.id, timestampMs: frame.timestampMs, dataURL: `data:image/jpeg;base64,${clean.toString('base64')}` });
  } catch { throw new Failure('invalid-argument', 'Invalid JPEG image'); }
 }
 return { frames: normalized, payloadHash: hash(JSON.stringify(data)), sufficient: normalized.length >= target * LIMITS.framesPerRep };
}
export function decide(raw: unknown, evidence: Evidence, target: number): Decision {
 const uncertain: Decision = { status: 'uncertain', reasonCode: 'unclear_evidence', verifiedRepCount: 0, cue: 'none' };
 const parsed = verdictSchema.safeParse(raw);
 if (!parsed.success) return uncertain;
 const value = parsed.data;
 if (value.status === 'uncertain') return { ...uncertain, cue: value.cue };
 if (value.reps.length > target) return uncertain;
 let previousEnd = -1;
 for (const rep of value.reps) {
  const indices = rep.frameIDs.map(id => evidence.frames.findIndex(frame => frame.id === id));
  if (indices.some((index,i) => index < 0 || (i > 0 && index <= indices[i-1])) || indices[0] < previousEnd) return uncertain;
  previousEnd = indices[4];
 }
 const verified = value.status === 'complete' && value.reps.length === target && evidence.sufficient;
 return { status: verified ? 'verified' : 'incomplete', reasonCode: verified ? 'observed_cycles' : 'incomplete_cycles', verifiedRepCount: verified ? target : 0, cue: value.cue };
}
