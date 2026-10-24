import { Hono } from 'hono';
import type { Bindings } from '../env';

export const healthRoutes = new Hono<{ Bindings: Bindings }>();

healthRoutes.get('/v1/ai/health', (c) => {
  const provider = c.env.AI_PROVIDER ?? 'local';
  const reachable = provider === 'huggingface' ? Boolean(c.env.HF_API_KEY) : true;
  return c.json({ provider, reachable, framework: 'hono' });
});
