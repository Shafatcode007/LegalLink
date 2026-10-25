import { beforeAll, describe, expect, it } from 'vitest';
import { exportJWK, generateKeyPair, SignJWT, type JWK } from 'jose';
import app from '../src/index';
import { checkAndConsume, LIMITS } from '../src/services/rate_limiter';

const SUPABASE_URL = 'https://test-project.supabase.co';
const ISSUER = `${SUPABASE_URL}/auth/v1`;
const HOUR = 60 * 60 * 1000;

class MemoryKV {
  readonly store = new Map<string, string>();
  async get(key: string) {
    return this.store.get(key) ?? null;
  }
  async put(key: string, value: string) {
    this.store.set(key, value);
  }
}

class BrokenKV {
  async get(): Promise<string | null> {
    throw new Error('kv down');
  }
  async put(): Promise<void> {
    throw new Error('kv down');
  }
}

let signingKey: CryptoKey;
let otherKey: CryptoKey;
let jwks: string;

beforeAll(async () => {
  const pair = await generateKeyPair('ES256');
  signingKey = pair.privateKey;
  otherKey = (await generateKeyPair('ES256')).privateKey;
  const publicJwk: JWK = { ...(await exportJWK(pair.publicKey)), kid: 'test-key', alg: 'ES256' };
  jwks = JSON.stringify({ keys: [publicJwk] });
});

function token(
  sub: string,
  opts: { key?: CryptoKey; exp?: string | number; aud?: string; iss?: string } = {},
) {
  return new SignJWT({ role: 'authenticated' })
    .setProtectedHeader({ alg: 'ES256', kid: 'test-key' })
    .setSubject(sub)
    .setAudience(opts.aud ?? 'authenticated')
    .setIssuer(opts.iss ?? ISSUER)
    .setIssuedAt()
    .setExpirationTime(opts.exp ?? '15m')
    .sign(opts.key ?? signingKey);
}

function env(kv: unknown = new MemoryKV(), extra: Record<string, unknown> = {}) {
  return { SUPABASE_URL, SUPABASE_JWKS: jwks, RATE_LIMIT: kv, ...extra };
}

async function check(action: string, jwt: string | null, bindings = env()) {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (jwt) headers.authorization = `Bearer ${jwt}`;
  const res = await app.request(
    '/v1/rate/check',
    { method: 'POST', headers, body: JSON.stringify({ action }) },
    bindings,
  );
  return { status: res.status, body: (await res.json()) as Record<string, any> };
}

describe('POST /v1/rate/check — authentication (TRD §6.4)', () => {
  it('rejects a request without a bearer token', async () => {
    const { status, body } = await check('sos', null);
    expect(status).toBe(401);
    expect(body.error.code).toBe('unauthenticated');
    expect(body.error.message_bn).toBeTruthy();
  });

  it('rejects an expired token', async () => {
    const { status } = await check('sos', await token('user-a', { exp: Math.floor(Date.now() / 1000) - 60 }));
    expect(status).toBe(401);
  });

  it('rejects a token signed by an unknown key', async () => {
    const { status } = await check('sos', await token('user-a', { key: otherKey }));
    expect(status).toBe(401);
  });

  it('rejects a token for another audience or issuer', async () => {
    expect((await check('sos', await token('user-a', { aud: 'anon' }))).status).toBe(401);
    expect((await check('sos', await token('user-a', { iss: 'https://evil.example/auth/v1' }))).status).toBe(401);
  });

  it('rejects a signed token that has no expiry', async () => {
    const noExp = await new SignJWT({ role: 'authenticated' })
      .setProtectedHeader({ alg: 'ES256', kid: 'test-key' })
      .setSubject('user-a')
      .setAudience('authenticated')
      .setIssuer(ISSUER)
      .sign(signingKey);
    expect((await check('sos', noExp)).status).toBe(401);
  });

  it('returns 503, not 401, when the Supabase key set cannot be fetched', async () => {
    const realFetch = globalThis.fetch;
    globalThis.fetch = async () => {
      throw new TypeError('network down');
    };
    try {
      const bindings = { SUPABASE_URL: 'https://unreachable-project.supabase.co', RATE_LIMIT: new MemoryKV() };
      const jwt = await token('user-a', { iss: 'https://unreachable-project.supabase.co/auth/v1' });
      const { status, body } = await check('sos', jwt, bindings as any);
      expect(status).toBe(503);
      expect(body.error).toMatchObject({ code: 'auth_unavailable', retryable: true });
    } finally {
      globalThis.fetch = realFetch;
    }
  });

  it('returns 503 when SUPABASE_JWKS is malformed', async () => {
    const { status, body } = await check('sos', await token('user-a'), env(new MemoryKV(), { SUPABASE_JWKS: 'not json' }));
    expect(status).toBe(503);
    expect(body.error.code).toBe('auth_unavailable');
  });

  it('returns 503 when Supabase auth is not configured', async () => {
    const { status, body } = await check('sos', await token('user-a'), { RATE_LIMIT: new MemoryKV() } as any);
    expect(status).toBe(503);
    expect(body.error.code).toBe('auth_unavailable');
  });
});

describe('POST /v1/rate/check — limits (TRD §6.8)', () => {
  it('allows 3 SOS per 24 h, then blocks the 4th with reset_at', async () => {
    const bindings = env();
    const jwt = await token('client-a');
    const before = Date.now();

    const remaining = [];
    for (let i = 0; i < 3; i++) {
      const { status, body } = await check('sos', jwt, bindings);
      expect(status).toBe(200);
      expect(body.allowed).toBe(true);
      remaining.push(body.remaining);
    }
    expect(remaining).toEqual([2, 1, 0]);

    const { status, body } = await check('sos', jwt, bindings);
    expect(status).toBe(200);
    expect(body).toMatchObject({ allowed: false, remaining: 0 });
    const resetAt = Date.parse(body.reset_at);
    expect(resetAt).toBeGreaterThanOrEqual(before + 24 * HOUR);
    expect(resetAt).toBeLessThanOrEqual(Date.now() + 24 * HOUR);
  });

  it('counts each user separately', async () => {
    const bindings = env();
    const a = await token('client-a');
    for (let i = 0; i < 3; i++) await check('sos', a, bindings);
    expect((await check('sos', a, bindings)).body.allowed).toBe(false);
    expect((await check('sos', await token('client-b'), bindings)).body).toMatchObject({
      allowed: true,
      remaining: 2,
    });
  });

  it('rejects an unknown action with the TRD §6.7 envelope', async () => {
    const { status, body } = await check('bogus', await token('client-a'));
    expect(status).toBe(400);
    expect(body.error).toMatchObject({ code: 'invalid_action', retryable: false });
    expect(body.error.message_bn).toBeTruthy();
  });

  it('fails open when KV is unavailable (TRD P5: never block the core flow)', async () => {
    const { status, body } = await check('sos', await token('client-a'), env(new BrokenKV()));
    expect(status).toBe(200);
    expect(body.allowed).toBe(true);
  });

  it('fails open when the KV binding is missing', async () => {
    const { status, body } = await check('sos', await token('client-a'), env(undefined));
    expect(status).toBe(200);
    expect(body.allowed).toBe(true);
  });
});

describe('checkAndConsume — sliding window', () => {
  const t0 = Date.parse('2026-10-24T00:00:00Z');

  it('frees a slot once the oldest request leaves the 24 h window', async () => {
    const kv = new MemoryKV();
    await checkAndConsume(kv as any, 'u', 'sos', t0);
    await checkAndConsume(kv as any, 'u', 'sos', t0 + HOUR);
    await checkAndConsume(kv as any, 'u', 'sos', t0 + 2 * HOUR);

    const blocked = await checkAndConsume(kv as any, 'u', 'sos', t0 + 23 * HOUR);
    expect(blocked).toEqual({ allowed: false, remaining: 0, reset_at: new Date(t0 + 24 * HOUR).toISOString() });

    const freed = await checkAndConsume(kv as any, 'u', 'sos', t0 + 24 * HOUR + 1);
    expect(freed).toMatchObject({ allowed: true, remaining: 0 });
    expect(freed.reset_at).toBe(new Date(t0 + HOUR + 24 * HOUR).toISOString());
  });

  it('applies the per-action limits from TRD §6.8', async () => {
    expect(LIMITS).toEqual({
      sos: { limit: 3, windowMs: 24 * HOUR },
      triage: { limit: 10, windowMs: 24 * HOUR },
      pin: { limit: 5, windowMs: 30 * 60 * 1000 },
    });

    const kv = new MemoryKV();
    for (let i = 0; i < 5; i++) {
      expect((await checkAndConsume(kv as any, 'adv', 'pin', t0 + i)).allowed).toBe(true);
    }
    expect((await checkAndConsume(kv as any, 'adv', 'pin', t0 + 10)).allowed).toBe(false);
    expect((await checkAndConsume(kv as any, 'adv', 'pin', t0 + 30 * 60 * 1000 + 1)).allowed).toBe(true);
  });

  it('keeps actions independent for the same user', async () => {
    const kv = new MemoryKV();
    for (let i = 0; i < 3; i++) await checkAndConsume(kv as any, 'u', 'sos', t0);
    expect((await checkAndConsume(kv as any, 'u', 'triage', t0)).remaining).toBe(9);
  });
});
