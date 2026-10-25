// Supabase JWT verification via JWKS (TRD §6.4 step [1], §6.9).
import { createMiddleware } from 'hono/factory';
import {
  createLocalJWKSet,
  createRemoteJWKSet,
  errors,
  jwtVerify,
  type JWTVerifyGetKey,
} from 'jose';
import type { Bindings } from '../env';
import { ApiError } from '../errors';

export type AuthVariables = { uid: string };

// Supabase asymmetric signing keys are ES256 (default) or RS256.
const ALGORITHMS = ['ES256', 'RS256'];

// One remote key set per project URL; jose caches the fetched keys itself.
const remoteKeySets = new Map<string, JWTVerifyGetKey>();

const unauthenticated = () =>
  new ApiError(401, 'unauthenticated', 'A valid sign-in is required', 'অনুগ্রহ করে আবার সাইন ইন করুন।');

const authUnavailable = () =>
  new ApiError(503, 'auth_unavailable', 'Authentication is not available', 'প্রমাণীকরণ এখন উপলব্ধ নয়।', true);

function keySet(env: Bindings, projectUrl: string): JWTVerifyGetKey {
  if (env.SUPABASE_JWKS) {
    try {
      return createLocalJWKSet(JSON.parse(env.SUPABASE_JWKS));
    } catch {
      throw authUnavailable();
    }
  }

  let keys = remoteKeySets.get(projectUrl);
  if (!keys) {
    keys = createRemoteJWKSet(new URL(`${projectUrl}/auth/v1/.well-known/jwks.json`));
    remoteKeySets.set(projectUrl, keys);
  }
  return keys;
}

/** Token problems are the caller's (401); key-set outages are ours (503). */
function isKeySetOutage(err: unknown): boolean {
  return !(err instanceof errors.JOSEError) || err instanceof errors.JWKSTimeout;
}

export const requireAuth = createMiddleware<{ Bindings: Bindings; Variables: AuthVariables }>(
  async (c, next) => {
    const projectUrl = c.env.SUPABASE_URL?.replace(/\/+$/, '');
    if (!projectUrl) throw authUnavailable();

    const bearer = /^Bearer\s+(\S+)$/i.exec(c.req.header('authorization') ?? '');
    if (!bearer) throw unauthenticated();

    const keys = keySet(c.env, projectUrl);
    let uid: string | undefined;
    try {
      const { payload } = await jwtVerify(bearer[1], keys, {
        issuer: `${projectUrl}/auth/v1`,
        audience: 'authenticated',
        algorithms: ALGORITHMS,
        requiredClaims: ['exp', 'sub'],
      });
      uid = payload.sub;
    } catch (err) {
      throw isKeySetOutage(err) ? authUnavailable() : unauthenticated();
    }
    if (!uid) throw unauthenticated();

    c.set('uid', uid);
    await next();
  },
);
