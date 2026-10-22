import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { Bindings } from './env';
import { ApiError } from './errors';
import { healthRoutes } from './routes/health';
import { triageRoutes } from './routes/triage';
import { summarizeRoutes } from './routes/summarize';
import { rateRoutes } from './routes/rate';

const app = new Hono<{ Bindings: Bindings }>();

app.use(
  '*',
  cors({
    origin: (origin) => {
      if (!origin) return origin;
      if (origin === 'https://legallink.bd') return origin;
      if (/^http:\/\/localhost(:\d+)?$/.test(origin)) return origin;
      return undefined;
    },
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'Authorization'],
  }),
);

app.route('/', healthRoutes);
app.route('/', triageRoutes);
app.route('/', summarizeRoutes);
app.route('/', rateRoutes);

app.onError((err, c) => {
  const requestId = c.req.header('cf-ray') ?? crypto.randomUUID();

  if (err instanceof ApiError) {
    return c.json(
      {
        error: {
          code: err.code,
          message: err.message,
          message_bn: err.messageBn,
          retryable: err.retryable,
          request_id: requestId,
        },
      },
      err.status,
    );
  }

  console.error('unhandled_worker_error', err);
  return c.json(
    {
      error: {
        code: 'internal_error',
        message: 'Unexpected error',
        message_bn: 'অপ্রত্যাশিত ত্রুটি ঘটেছে।',
        retryable: true,
        request_id: requestId,
      },
    },
    500,
  );
});

export default app;
export { app };
