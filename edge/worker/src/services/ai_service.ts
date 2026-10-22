import type { Bindings } from '../env';
import {
  DISCLAIMER_TRIAGE,
  TEMPLATE_ITEMS,
  filterChecklist,
  hasBannedPhrase,
  type CaseType,
  type ChecklistItem,
  type TriageResponseBody,
} from '../schemas/triage';
import { DISCLAIMER_SUMMARY, type SummaryResponseBody } from '../schemas/summary';
import { TRIAGE_PROMPT_VERSION, TRIAGE_SYSTEM_PROMPT } from '../../prompts/triage_v1';
import { SUMMARY_PROMPT_VERSION, SUMMARY_SYSTEM_PROMPT } from '../../prompts/summary_v1';

const TIMEOUT_MS = 30_000;

export interface TriageInput {
  case_type: CaseType;
  answers: Record<string, unknown>;
}

export interface SummaryInput {
  raw_notes: string;
  case_type: CaseType;
  language: 'bn' | 'en';
}

type Provider = 'local' | 'huggingface';

function nonEmpty(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim().length > 0 ? value : undefined;
}

function isUrgency(value: unknown): value is 'high' | 'medium' | 'low' {
  return value === 'high' || value === 'medium' || value === 'low';
}

export class TemplateAIService {
  triage(input: TriageInput): TriageResponseBody {
    const checklist: ChecklistItem[] = TEMPLATE_ITEMS[input.case_type]
      .slice(0, 3)
      .map((item_name_bn) => ({
        template_id: null,
        item_name_bn,
        importance: 'high',
        reason_bn: 'মামলার জন্য প্রয়োজনীয় মূল দলিল।',
      }));

    return {
      case_type: input.case_type,
      urgency: 'medium',
      overview_bn:
        'আপনার মামলার জন্য প্রাথমিক তথ্য ও প্রয়োজনীয় কাগজপত্রের তালিকা নিচে দেওয়া হলো।',
      actions_bn: ['সংশ্লিষ্ট কাগজপত্র সংগ্রহ করুন।', 'স্থানীয় আইনজীবীর সাথে যোগাযোগ করুন।'],
      checklist,
      questions_to_ask_lawyer_bn: ['পরবর্তী শুনানির তারিখ কী?'],
      disclaimer_bn: DISCLAIMER_TRIAGE,
      model: 'template',
      prompt_version: TRIAGE_PROMPT_VERSION,
      cached: false,
    };
  }

  summarize(input: SummaryInput): SummaryResponseBody {
    const fallbackUsed = hasBannedPhrase(input.raw_notes);
    const cleaned = input.raw_notes
      .replace(/জামিন পাবেন/g, 'জামিনের আবেদন করা যেতে পারে')
      .replace(/হেরে যাবেন/g, 'ফলাফল অনিশ্চিত')
      .replace(/আপনার করা উচিত/g, 'আইনজীবীর পরামর্শ নেওয়া প্রয়োজন')
      .trim();

    return {
      draft_bn: cleaned.length > 0 ? cleaned : 'মামলার তথ্য সংক্ষেপে লিপিবদ্ধ করা হয়েছে।',
      model: 'template',
      prompt_version: SUMMARY_PROMPT_VERSION,
      tokens: 0,
      fallback_used: fallbackUsed,
      disclaimer_bn: DISCLAIMER_SUMMARY,
    };
  }
}

export class AiService {
  private readonly template = new TemplateAIService();

  constructor(
    private readonly env: Bindings,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async triage(input: TriageInput): Promise<TriageResponseBody> {
    const fallback = this.template.triage(input);
    const provider = this.resolveProvider();
    if (!provider) return fallback;

    try {
      const raw = await this.callProvider(provider, TRIAGE_SYSTEM_PROMPT, JSON.stringify(input));
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const checklist = Array.isArray(parsed.checklist)
        ? (parsed.checklist as ChecklistItem[])
        : fallback.checklist;

      return {
        case_type: input.case_type,
        urgency: isUrgency(parsed.urgency) ? parsed.urgency : fallback.urgency,
        overview_bn: nonEmpty(parsed.overview_bn) ?? fallback.overview_bn,
        actions_bn: Array.isArray(parsed.actions_bn)
          ? parsed.actions_bn.slice(0, 5).map(String)
          : fallback.actions_bn,
        checklist: filterChecklist(input.case_type, checklist),
        questions_to_ask_lawyer_bn: fallback.questions_to_ask_lawyer_bn,
        disclaimer_bn: nonEmpty(parsed.disclaimer_bn) ?? DISCLAIMER_TRIAGE,
        model: this.providerLabel(provider),
        prompt_version: TRIAGE_PROMPT_VERSION,
        cached: false,
      };
    } catch {
      return fallback;
    }
  }

  async summarize(input: SummaryInput): Promise<SummaryResponseBody> {
    const fallback = this.template.summarize(input);
    const provider = this.resolveProvider();
    if (!provider) return fallback;

    try {
      const raw = await this.callProvider(provider, SUMMARY_SYSTEM_PROMPT, JSON.stringify(input));
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const draft = nonEmpty(parsed.draft_bn);

      if (!draft || hasBannedPhrase(draft)) {
        return { ...fallback, fallback_used: true };
      }

      return {
        draft_bn: draft,
        model: this.providerLabel(provider),
        prompt_version: SUMMARY_PROMPT_VERSION,
        tokens: typeof parsed.tokens === 'number' ? parsed.tokens : 0,
        fallback_used: false,
        disclaimer_bn: DISCLAIMER_SUMMARY,
      };
    } catch {
      return { ...fallback, fallback_used: true };
    }
  }

  private resolveProvider(): Provider | null {
    if (this.env.AI_PROVIDER === 'huggingface' && this.env.HF_API_KEY) return 'huggingface';
    if (this.env.AI_PROVIDER === 'local' && this.env.LOCAL_LLM_URL) return 'local';
    return null;
  }

  private providerLabel(provider: Provider): string {
    return provider === 'huggingface' ? 'qwen2.5-7b-instruct' : 'qwen2.5-3b-local';
  }

  private async callProvider(provider: Provider, system: string, user: string): Promise<string> {
    const url =
      provider === 'huggingface'
        ? 'https://router.huggingface.co/v1/chat/completions'
        : (this.env.LOCAL_LLM_URL ?? 'http://localhost:8080/v1/chat/completions');

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

    try {
      const response = await this.fetchImpl(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(provider === 'huggingface' && this.env.HF_API_KEY
            ? { authorization: `Bearer ${this.env.HF_API_KEY}` }
            : {}),
        },
        body: JSON.stringify({
          model: this.providerLabel(provider),
          temperature: 0.2,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user },
          ],
        }),
        signal: controller.signal,
      });

      if (!response.ok) throw new Error(`provider_http_${response.status}`);

      const payload = (await response.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
      };
      const content = payload.choices?.[0]?.message?.content;
      if (!content) throw new Error('provider_empty');
      return content;
    } finally {
      clearTimeout(timer);
    }
  }
}
