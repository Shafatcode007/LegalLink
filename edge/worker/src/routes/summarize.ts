import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import type { Bindings } from '../env';
import { SummaryRequestSchema } from '../schemas/summary';
import { AiService } from '../services/ai_service';

export const summarizeRoutes = new Hono<{ Bindings: Bindings }>();

summarizeRoutes.post(
  '/v1/ai/summarize',
  zValidator('json', SummaryRequestSchema),
  async (c) => {
    const input = c.req.valid('json');
    const service = new AiService(c.env);
    const result = await service.summarize({
      raw_notes: input.raw_notes,
      case_type: input.case_type,
      language: input.language,
    });
    return c.json(result);
  },
);
