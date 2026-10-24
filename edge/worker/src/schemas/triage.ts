import { z } from 'zod';

export const CASE_TYPES = [
  'bail',
  'criminal',
  'family',
  'property',
  'labor',
  'women_child',
] as const;

export type CaseType = (typeof CASE_TYPES)[number];

export const TEMPLATE_ITEMS: Record<CaseType, readonly string[]> = {
  bail: ['এফআইআর কপি', 'জামিন আবেদন', 'পরিচয়পত্র', 'আদালতের আদেশ'],
  criminal: ['এফআইআর কপি', 'চার্জশিট', 'সাক্ষীর তালিকা', 'আদালতের আদেশ'],
  family: ['বিবাহ সনদ', 'জাতীয় পরিচয়পত্র', 'আদালতের নোটিশ'],
  property: ['দলিল', 'খতিয়ান', 'মিউটেশন কপি'],
  labor: ['চাকরির চুক্তিপত্র', 'বেতন স্লিপ', 'ছাড়পত্র'],
  women_child: ['এফআইআর কপি', 'মেডিকেল রিপোর্ট', 'সহায়তা কেন্দ্রের রেফারেল'],
};

export const DISCLAIMER_TRIAGE = 'এটি সাধারণ তথ্য, আইনি পরামর্শ নয়।';

export const BANNED_PHRASES = ['জামিন পাবেন', 'হেরে যাবেন', 'আপনার করা উচিত'] as const;

export function hasBannedPhrase(text: string): boolean {
  return BANNED_PHRASES.some((phrase) => text.includes(phrase));
}

export const ChecklistItemSchema = z.object({
  template_id: z.string().uuid().nullable().default(null),
  item_name_bn: z.string().min(1),
  importance: z.enum(['high', 'medium', 'low']),
  reason_bn: z.string().min(1),
  ai_extra: z.boolean().optional(),
});

export type ChecklistItem = z.infer<typeof ChecklistItemSchema>;

export const TriageRequestSchema = z.object({
  case_type: z.enum(CASE_TYPES),
  answers: z.record(z.string(), z.unknown()).optional().default({}),
});

export type TriageRequest = z.infer<typeof TriageRequestSchema>;

export const TriageResponseSchema = z.object({
  case_type: z.enum(CASE_TYPES),
  urgency: z.enum(['high', 'medium', 'low']),
  overview_bn: z.string().min(1),
  actions_bn: z.array(z.string().min(1)).max(5),
  checklist: z.array(ChecklistItemSchema).max(15),
  questions_to_ask_lawyer_bn: z.array(z.string()).optional(),
  disclaimer_bn: z.string().min(1),
  model: z.string().min(1),
  prompt_version: z.string().min(1),
  cached: z.boolean(),
});

export type TriageResponseBody = z.infer<typeof TriageResponseSchema>;

export function filterChecklist(caseType: CaseType, items: ChecklistItem[]): ChecklistItem[] {
  const allowed = new Set<string>(TEMPLATE_ITEMS[caseType]);
  return items
    .filter((item) => allowed.has(item.item_name_bn) || item.ai_extra === true)
    .slice(0, 15);
}
