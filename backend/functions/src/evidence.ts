import sharp from 'sharp';
import { Failure, parse } from './errors.js';
import { LIMITS, submissionSchema } from './contracts.js';
import { hash, type Evidence } from './policy.js';
export * from './policy.js';
export async function prepareEvidence(input: unknown, target: number): Promise<Evidence> {
 const data = parse(submissionSchema, input);
 const ids = new Set<string>(), images = new Set<string>(); let total = 0, normalizedTotal = 0, previous = -1;
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
   normalizedTotal += clean.length;
   if(clean.length > LIMITS.maxFrameBytes || normalizedTotal > LIMITS.maxTotalBytes)throw new Error('Normalized image budget exceeded');
   normalized.push({ id: frame.id, timestampMs: frame.timestampMs, dataURL: `data:image/jpeg;base64,${clean.toString('base64')}` });
  } catch { throw new Failure('invalid-argument', 'Invalid JPEG image'); }
 }
 return { frames: normalized, payloadHash: hash(JSON.stringify(data)), sufficient: normalized.length >= target * LIMITS.framesPerRep };
}
