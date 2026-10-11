import { z } from 'zod';
export interface Config { enabled: boolean; model: string; userDailyLimit: number; globalDailyLimit: number }
export function readConfig(env: Record<string, string | undefined>): Config {
 const enabled = z.enum(['true', 'false']).parse(env.AI_VERIFICATION_ENABLED ?? 'false') === 'true';
 const cap = (value: string | undefined, fallback: number, max: number) => z.coerce.number().int().min(1).max(max).parse(value ?? fallback);
 return { enabled, model: z.string().min(1).max(100).parse(env.OPENAI_MODEL ?? 'gpt-5.6-terra'), userDailyLimit: cap(env.AI_USER_DAILY_LIMIT, 3, 20), globalDailyLimit: cap(env.AI_GLOBAL_DAILY_LIMIT, 100, 10000) };
}
