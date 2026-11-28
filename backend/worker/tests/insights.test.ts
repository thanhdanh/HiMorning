import { describe, it, expect, vi } from 'vitest';
import movementRules from '../../../shared/contracts/v1/movement-rules.json';
import {
  weeklyInsightRequestSchema,
  weeklyInsightResponseSchema,
  buildOfflineWeeklyInsight,
  generateWeeklyInsight,
} from '../src/insights.js';

describe('shared movement rules single source of truth', () => {
  it('defines aligned lighting, tilt, push-up variants, and squat thresholds', () => {
    expect(movementRules.schemaVersion).toBe(1);
    expect(movementRules.lighting.lowLightMeanLuma).toBe(0.2);
    expect(movementRules.tilt.maxCompensatedRollDeg).toBe(35);
    expect(movementRules.exercises.push_ups.variants.standard).toMatchObject({
      elbowDownMaxDeg: 98,
      elbowUpMinDeg: 150,
      bodyAngleMinDeg: 150,
      inclineMaxDeg: 42,
      allowKneeFallback: false,
    });
    expect(movementRules.exercises.push_ups.variants.inclineOrKnee).toMatchObject({
      elbowDownMaxDeg: 108,
      elbowUpMinDeg: 146,
      bodyAngleMinDeg: 138,
      inclineMaxDeg: 68,
      allowKneeFallback: true,
    });
    expect(movementRules.exercises.squats).toMatchObject({
      defaultTarget: 10,
      standingKneeMinDeg: 155,
      bottomKneeMaxDeg: 115,
      filterMinCutoff: 2.2,
      filterBeta: 0.18,
    });
  });
});

describe('weekly insight endpoint contract and privacy boundary', () => {
  const validPayload = {
    completedDays: 5,
    totalAttempts: 6,
    avgCompletionSec: 21,
    goToChallenge: 'squats' as const,
    selfConfirmedCount: 0,
    locale: 'vi' as const,
  };

  it('strictly rejects any PII, raw image, or audio keys', () => {
    expect(weeklyInsightRequestSchema.safeParse(validPayload).success).toBe(true);
    for (const extra of [
      { displayName: 'An' },
      { email: 'user@example.com' },
      { image: 'data:image/jpeg;base64,AAA' },
      { jpegBase64: 'AAA' },
      { audioBase64: 'BBB' },
    ]) {
      expect(weeklyInsightRequestSchema.safeParse({ ...validPayload, ...extra }).success).toBe(false);
    }
  });

  it('produces calm bilingual offline fallbacks based on friction and momentum', () => {
    const frictionVi = buildOfflineWeeklyInsight({
      ...validPayload,
      completedDays: 2,
      selfConfirmedCount: 3,
      goToChallenge: 'push_ups',
      locale: 'vi',
    });
    expect(weeklyInsightResponseSchema.parse(frictionVi)).toMatchObject({
      suggestedFocus: 'gentle_movement',
      source: 'fallback',
    });
    expect(frictionVi.freshPrompts).toHaveLength(3);

    const momentumEn = buildOfflineWeeklyInsight({
      ...validPayload,
      completedDays: 6,
      selfConfirmedCount: 0,
      locale: 'en',
    });
    expect(weeklyInsightResponseSchema.parse(momentumEn)).toMatchObject({
      suggestedFocus: 'energize',
      source: 'fallback',
    });
  });

  it('calls Gemini structured JSON output and falls back cleanly on upstream failure', async () => {
    const modelReply = {
      candidates: [{
        finishReason: 'STOP',
        content: {
          parts: [{
            text: JSON.stringify({
              summaryText: 'Bạn duy trì 5/7 buổi sáng ổn định với nhịp squat đều đặn.',
              suggestedFocus: 'energize',
              freshPrompts: [
                'Mở rèm đón sáng ngay khi đứng dậy.',
                'Giữ nhịp thở đều trong 10 lần squat.',
                'Đặt điện thoại cách giường hai bước.',
              ],
            }),
          }],
        },
      }],
    };
    const okFetch = vi.fn<typeof fetch>().mockResolvedValue(Response.json(modelReply));
    const result = await generateWeeklyInsight(validPayload, 'test-key', okFetch);
    expect(result.source).toBe('gemini');
    expect(result.suggestedFocus).toBe('energize');
    expect(okFetch).toHaveBeenCalledOnce();
    const [url, init] = okFetch.mock.calls[0];
    expect(String(url)).toContain('/models/gemini-3.5-flash-lite:generateContent');
    expect(init?.redirect).toBe('manual');

    const failFetch = vi.fn<typeof fetch>().mockResolvedValue(new Response('rate limited secret', { status: 429 }));
    const fallback = await generateWeeklyInsight(validPayload, 'test-key', failFetch);
    expect(fallback.source).toBe('fallback');
    expect(JSON.stringify(fallback)).not.toContain('secret');
  });
});
