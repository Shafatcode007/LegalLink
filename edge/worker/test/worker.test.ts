import { describe, expect, it } from 'vitest';
import app from '../src/index';
import { redactPii } from '../src/middleware/pii_redactor';
import { TEMPLATE_ITEMS, TriageResponseSchema } from '../src/schemas/triage';
import { SummaryResponseSchema } from '../src/schemas/summary';

const jsonHeaders = { 'content-type': 'application/json' };

async function readJson(res: Response): Promise<Record<string, unknown>> {
  return (await res.json()) as Record<string, unknown>;
}

function post(path: string, body: unknown) {
  return app.request(
    path,
    { method: 'POST', headers: jsonHeaders, body: JSON.stringify(body) },
    {},
  );
}

describe('GET /v1/ai/health', () => {
  it('returns the Hono gateway envelope', async () => {
    const res = await app.request('/v1/ai/health', undefined, {});
    expect(res.status).toBe(200);
    const body = await readJson(res);
    expect(body.provider).toBe('local');
    expect(body.framework).toBe('hono');
    expect(typeof body.reachable).toBe('boolean');
  });
});

describe('redactPii', () => {
  it('redacts BD phones and NIDs and restores them', () => {
    const input = 'Call +8801712345678 or 01812345678. NID 1234567890.';
    const result = redactPii(input);
    expect(result.redacted).toContain('[PHONE]');
    expect(result.redacted).toContain('[NID]');
    expect(result.redacted).not.toContain('8801712345678');
    expect(result.redacted).not.toContain('1234567890');
    expect(result.restore(result.redacted)).toBe(input);
  });

  it('redacts caller-supplied names', () => {
    const result = redactPii('Rahim filed the case.', ['Rahim']);
    expect(result.redacted).toContain('[NAME_1]');
    expect(result.restore(result.redacted)).toBe('Rahim filed the case.');
  });
});

describe('POST /v1/ai/triage', () => {
  it('rejects an invalid body with 400', async () => {
    const res = await post('/v1/ai/triage', { case_type: 'nope', answers: {} });
    expect(res.status).toBe(400);
  });

  it('returns a schema-valid, template-filtered draft', async () => {
    const res = await post('/v1/ai/triage', { case_type: 'bail', answers: { arrested: true } });
    expect(res.status).toBe(200);
    const body = await readJson(res);
    expect(() => TriageResponseSchema.parse(body)).not.toThrow();
    expect(body.case_type).toBe('bail');
    expect(['high', 'medium', 'low']).toContain(body.urgency);
    expect(typeof body.overview_bn).toBe('string');
    expect(Array.isArray(body.actions_bn)).toBe(true);
    const checklist = Array.isArray(body.checklist) ? body.checklist : [];
    expect(checklist.length).toBeGreaterThan(0);
    for (const item of checklist) {
      expect(TEMPLATE_ITEMS.bail).toContain(item.item_name_bn);
    }
    expect(body.disclaimer_bn).toBe('এটি সাধারণ তথ্য, আইনি পরামর্শ নয়।');
  });
});

describe('POST /v1/ai/summarize', () => {
  it('strips banned prediction phrases and falls back safely', async () => {
    const res = await post('/v1/ai/summarize', {
      raw_notes: 'আপনি জামিন পাবেন',
      case_type: 'bail',
      language: 'bn',
    });
    expect(res.status).toBe(200);
    const body = await readJson(res);
    expect(() => SummaryResponseSchema.parse(body)).not.toThrow();
    expect(body.draft_bn).not.toContain('জামিন পাবেন');
    expect(body.disclaimer_bn).toBe('এটি আপনার আইনজীবীর অনুমোদন সাপেক্ষ।');
    expect(body.fallback_used).toBe(true);
  });
});
