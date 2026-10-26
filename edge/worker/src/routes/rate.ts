import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Bindings } from '../env';
import { ApiError } from '../errors';
import { requireAuth, type AuthVariables } from '../middleware/auth';
import { checkAndConsume, failOpen, RATE_ACTIONS } from '../services/rate_limiter';

const RateRequestSchema = z.object({ action: z.enum(RATE_ACTIONS) });

export const rateRoutes = new Hono<{ Bindings: Bindings; Variables: AuthVariables }>();

rateRoutes.post(
  '/v1/rate/check',
  requireAuth,
  zValidator('json', RateRequestSchema, (result) => {
    if (!result.success) {
      throw new ApiError(400, 'invalid_action', `action must be one of ${RATE_ACTIONS.join(', ')}`, 'অনুরোধটি সঠিক নয়।');
    }
  }),
  async (c) => {
    const { action } = c.req.valid('json');
    const now = Date.now();

    if (!c.env.RATE_LIMIT) {
      console.warn('rate_limit_degraded', { action, reason: 'kv_binding_missing' });
      return c.json(failOpen(action, now));
    }
    try {
      return c.json(await checkAndConsume(c.env.RATE_LIMIT, c.get('uid'), action, now));
    } catch (err) {
      console.warn('rate_limit_degraded', { action, reason: String(err) });
      return c.json(failOpen(action, now));
    }
  },
);
