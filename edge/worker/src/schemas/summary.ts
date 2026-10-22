import { z } from 'zod';
import { CASE_TYPES } from './triage';

export const DISCLAIMER_SUMMARY = 'এটি আপনার আইনজীবীর অনুমোদন সাপেক্ষ।';

export const SummaryRequestSchema = z.object({
  raw_notes: z.string().min(1),
  case_type: z.enum(CASE_TYPES),
  language: z.enum(['bn', 'en']).default('bn'),
});

export type SummaryRequest = z.infer<typeof SummaryRequestSchema>;

export const SummaryResponseSchema = z.object({
  draft_bn: z.string().min(1),
  model: z.string().min(1),
  prompt_version: z.string().min(1),
  tokens: z.number().int().nonnegative(),
  fallback_used: z.boolean(),
  disclaimer_bn: z.string().min(1),
});

export type SummaryResponseBody = z.infer<typeof SummaryResponseSchema>;
