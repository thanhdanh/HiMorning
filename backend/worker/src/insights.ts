import { z } from 'zod';
import { MODEL } from './config.js';
import { boundedJSON } from './gemini.js';

export const challengeKindEnum = z.enum([
  'none',
  'push_ups',
  'squats',
  'read_and_choose',
  'guided_rhythm',
  'read_aloud',
  'wave_hand',
  'neck_rotation',
  'riddle',
  'jumping_jacks',
  'stretching',
  'morning_light',
]);

export const morningFocusEnum = z.enum([
  'clear_start',
  'gentle_movement',
  'find_your_voice',
  'energize',
]);

/**
 * Strictly accepts ONLY anonymized numeric/enum summary metrics.
 * `.strict()` rejects any unexpected keys (PII, names, emails, images, audio, raw timestamps).
 */
export const weeklyInsightRequestSchema = z.object({
  completedDays: z.number().int().min(0).max(7),
  totalAttempts: z.number().int().min(0).max(100),
  avgCompletionSec: z.number().min(0).max(3600).nullable().optional(),
  goToChallenge: challengeKindEnum,
  selfConfirmedCount: z.number().int().min(0).max(100),
  locale: z.enum(['vi', 'en']),
}).strict();

export type WeeklyInsightRequest = z.infer<typeof weeklyInsightRequestSchema>;

const modelInsightSchema = z.object({
  summaryText: z.string().min(8).max(280),
  suggestedFocus: morningFocusEnum,
  freshPrompts: z.array(z.string().min(6).max(140)).length(3),
});

export const weeklyInsightResponseSchema = modelInsightSchema.extend({
  source: z.enum(['gemini', 'fallback']),
});

export type WeeklyInsightResponse = z.infer<typeof weeklyInsightResponseSchema>;

export function buildOfflineWeeklyInsight(input: WeeklyInsightRequest): WeeklyInsightResponse {
  const highFriction = input.selfConfirmedCount >= 2 || (input.totalAttempts > 0 && input.completedDays <= 2);
  const strongMomentum = input.completedDays >= 5;

  const suggestedFocus: WeeklyInsightResponse['suggestedFocus'] = highFriction
    ? 'gentle_movement'
    : strongMomentum
      ? 'energize'
      : input.goToChallenge === 'read_aloud'
        ? 'find_your_voice'
        : 'clear_start';

  if (input.locale === 'vi') {
    const summaryText = highFriction
      ? `Tuần này bạn hoàn thành ${input.completedDays}/7 buổi sáng. Hãy hạ nhịp nhẹ hơn với Squat buổi sáng hoặc chống đẩy nghiêng để giữ đà đều đặn.`
      : strongMomentum
        ? `Rất ổn định: ${input.completedDays}/7 buổi sáng hoàn thành thử thách${input.avgCompletionSec ? ` với trung bình ${Math.round(input.avgCompletionSec)} giây` : ''}. Bạn có thể tăng nhẹ 2 lần tập.`
        : `Bạn đã hoàn thành ${input.completedDays}/7 buổi sáng trong tuần. Giữ khung giờ cố định và bắt đầu ngay khi chuông reo để tạo nhịp quen.`;

    return {
      summaryText,
      suggestedFocus,
      freshPrompts: [
        'Mở rèm đón sáng 20 giây ngay sau khi tắt báo thức.',
        'Nếu chống đẩy hơi nặng vào sáng sớm, đổi sang 10 lần squat chậm.',
        'Đặt điện thoại cách giường hai bước chân trước khi ngủ.',
      ],
      source: 'fallback',
    };
  }

  const summaryText = highFriction
    ? `You completed ${input.completedDays}/7 mornings this week. Switching to Morning Squats or Incline Push-ups can make waking up smoother.`
    : strongMomentum
      ? `Steady week: ${input.completedDays}/7 completed mornings${input.avgCompletionSec ? ` averaging ${Math.round(input.avgCompletionSec)}s` : ''}. You are ready for a gentle +2 rep step up.`
      : `You finished ${input.completedDays}/7 mornings this week. Keeping one consistent alarm time will lock in your wake routine.`;

  return {
    summaryText,
    suggestedFocus,
    freshPrompts: [
      'Open your curtains for 20 seconds right after clearing the alarm.',
      'Swap floor push-ups for 10 calm morning squats on heavier mornings.',
      'Place your phone two steps from bed before turning off the light.',
    ],
    source: 'fallback',
  };
}

export async function generateWeeklyInsight(
  input: WeeklyInsightRequest,
  apiKey: string,
  requestImpl: typeof fetch = fetch.bind(globalThis),
): Promise<WeeklyInsightResponse> {
  if (!apiKey.trim()) {
    return buildOfflineWeeklyInsight(input);
  }

  try {
    const { $schema, ...schema } = z.toJSONSchema(modelInsightSchema);
    void $schema;
    const langInstruction = input.locale === 'vi'
      ? 'Respond in concise, natural Vietnamese. No hype, no emojis, no filler.'
      : 'Respond in concise, calm English. No hype, no emojis, no filler.';
    const response = await requestImpl(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: 'POST',
        redirect: 'manual',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
        signal: AbortSignal.timeout(8000),
        body: JSON.stringify({
          systemInstruction: {
            parts: [{
              text: `You are HiMorning's calm morning-habit coach. Given anonymized 7-day wake-up stats, write a 1-2 sentence reflection (summaryText), choose the best morning focus (suggestedFocus), and give 3 practical one-line morning prompts (freshPrompts). ${langInstruction}`,
            }],
          },
          contents: [{
            role: 'user',
            parts: [{ text: JSON.stringify(input) }],
          }],
          generationConfig: {
            maxOutputTokens: 350,
            responseMimeType: 'application/json',
            responseJsonSchema: schema,
          },
        }),
      },
    );

    if (!response.ok) {
      return buildOfflineWeeklyInsight(input);
    }

    const output = await boundedJSON(response, 32768);
    const parsedOutput = z.object({
      candidates: z.array(z.object({
        finishReason: z.literal('STOP'),
        content: z.object({
          parts: z.array(z.object({
            text: z.string(),
            thought: z.boolean().optional(),
          })),
        }),
      })).length(1),
      promptFeedback: z.object({ blockReason: z.string().optional() }).optional(),
    }).parse(output);

    if (parsedOutput.promptFeedback?.blockReason) {
      return buildOfflineWeeklyInsight(input);
    }
    const textParts = parsedOutput.candidates[0].content.parts.filter(part => !part.thought);
    if (textParts.length !== 1) {
      return buildOfflineWeeklyInsight(input);
    }
    const insight = modelInsightSchema.parse(JSON.parse(textParts[0].text));
    return { ...insight, source: 'gemini' };
  } catch {
    return buildOfflineWeeklyInsight(input);
  }
}
