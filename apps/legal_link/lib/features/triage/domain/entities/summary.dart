/// HITL summary contract (TRD §6.4 `/v1/ai/summarize`, §7.2). The result is
/// always a draft; only the advocate's PIN publish makes it client-visible.
library;

const canonicalSummaryDisclaimerBn = 'এটি আপনার আইনজীবীর অনুমোদন সাপেক্ষ।';

class SummaryInput {
  const SummaryInput({
    required this.rawNotes,
    required this.caseType,
    this.language = 'bn',
  });

  final String rawNotes;
  final String caseType;
  final String language;
}

class SummaryDraft {
  const SummaryDraft({
    required this.draftBn,
    required this.disclaimerBn,
    required this.model,
    required this.promptVersion,
    this.tokens = 0,
    this.fallbackUsed = false,
  });

  final String draftBn;
  final String disclaimerBn;
  final String model;
  final String promptVersion;
  final int tokens;
  final bool fallbackUsed;
}
