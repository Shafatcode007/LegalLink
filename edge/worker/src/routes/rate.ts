import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { Bindings } from '../env';

const RateRequestSchema = z.object({ action: z.string().min(1) });

export const rateRoutes = new Hono<{ Bindings: Bindings }>();

rateRoutes.post('/v1/rate/check', zValidator('json', RateRequestSchema), (c) => {
  const resetAt = new Date(Date.now() + 60_000).toISOString();
  return c.json({ allowed: true, remaining: 19, reset_at: resetAt });
});
