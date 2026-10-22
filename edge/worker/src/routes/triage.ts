import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import type { Bindings } from '../env';
import { TriageRequestSchema } from '../schemas/triage';
import { AiService } from '../services/ai_service';

export const triageRoutes = new Hono<{ Bindings: Bindings }>();

triageRoutes.post('/v1/ai/triage', zValidator('json', TriageRequestSchema), async (c) => {
  const input = c.req.valid('json');
  const service = new AiService(c.env);
  const result = await service.triage({
    case_type: input.case_type,
    answers: input.answers ?? {},
  });
  return c.json(result);
});
