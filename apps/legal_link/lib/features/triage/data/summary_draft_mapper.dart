import '../domain/entities/summary.dart';

/// Maps the snake_case `/v1/ai/summarize` response to [SummaryDraft].
SummaryDraft summaryDraftFromJson(Map<String, dynamic> json) {
  final disclaimer = (json['disclaimer_bn'] as String?)?.trim();

  return SummaryDraft(
    draftBn: json['draft_bn'] as String,
    disclaimerBn: (disclaimer == null || disclaimer.isEmpty)
        ? canonicalSummaryDisclaimerBn
        : disclaimer,
    model: json['model'] as String? ?? 'unknown',
    promptVersion: json['prompt_version'] as String? ?? 'unknown',
    tokens: json['tokens'] as int? ?? 0,
    fallbackUsed: json['fallback_used'] as bool? ?? false,
  );
}
