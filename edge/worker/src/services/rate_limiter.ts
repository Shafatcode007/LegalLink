// Sliding-window limiter over Cloudflare KV (TRD §6.4 step [2], §6.8).
// KV is eventually consistent, so this is the pre-flight UX limit; the
// database triggers stay authoritative.

const MINUTE = 60 * 1000;
const DAY = 24 * 60 * MINUTE;

export const RATE_ACTIONS = ['sos', 'triage', 'pin'] as const;
export type RateAction = (typeof RATE_ACTIONS)[number];

export const LIMITS: Record<RateAction, { limit: number; windowMs: number }> = {
  sos: { limit: 3, windowMs: DAY },
  triage: { limit: 10, windowMs: DAY },
  pin: { limit: 5, windowMs: 30 * MINUTE },
};

export interface RateDecision {
  allowed: boolean;
  remaining: number;
  reset_at: string;
}

type Store = Pick<KVNamespace, 'get' | 'put'>;

const iso = (ms: number) => new Date(ms).toISOString();

function parseHits(raw: string | null): number[] {
  if (!raw) return [];
  try {
    const value: unknown = JSON.parse(raw);
    return Array.isArray(value) ? value.filter((t): t is number => typeof t === 'number') : [];
  } catch {
    return [];
  }
}

/** Records one use when allowed; a blocked call records nothing. */
export async function checkAndConsume(
  kv: Store,
  uid: string,
  action: RateAction,
  now: number,
): Promise<RateDecision> {
  const { limit, windowMs } = LIMITS[action];
  const key = `rate:${uid}:${action}`;
  const hits = parseHits(await kv.get(key)).filter((t) => t > now - windowMs);

  if (hits.length >= limit) {
    return { allowed: false, remaining: 0, reset_at: iso(hits[0] + windowMs) };
  }

  hits.push(now);
  // KV's minimum TTL is 60 s; the window itself is enforced by the filter above.
  await kv.put(key, JSON.stringify(hits), {
    expirationTtl: Math.max(60, Math.ceil(windowMs / 1000)),
  });
  return { allowed: true, remaining: limit - hits.length, reset_at: iso(hits[0] + windowMs) };
}

/** Used when KV is missing or failing: never block the core flow (TRD P5). */
export function failOpen(action: RateAction, now: number): RateDecision {
  const { limit, windowMs } = LIMITS[action];
  return { allowed: true, remaining: limit - 1, reset_at: iso(now + windowMs) };
}
