import '../domain/entities/triage.dart';

/// Maps the snake_case `/v1/ai/triage` response (TRD §7.2) to [TriageResult].
TriageResult triageResultFromJson(Map<String, dynamic> json) {
  final disclaimer = (json['disclaimer_bn'] as String?)?.trim();

  return TriageResult(
    caseType: json['case_type'] as String,
    urgency: json['urgency'] as String? ?? 'medium',
    overviewBn: json['overview_bn'] as String? ?? '',
    actionsBn: _strings(json['actions_bn']),
    checklist: [
      for (final item in json['checklist'] as List? ?? const [])
        _checklistItem(item as Map<String, dynamic>),
    ],
    questionsToAskLawyerBn: _strings(json['questions_to_ask_lawyer_bn']),
    disclaimerBn: (disclaimer == null || disclaimer.isEmpty)
        ? canonicalDisclaimerBn
        : disclaimer,
    model: json['model'] as String? ?? 'unknown',
    promptVersion: json['prompt_version'] as String? ?? 'unknown',
    cached: json['cached'] as bool? ?? false,
    fallbackUsed: json['fallback_used'] as bool? ?? false,
  );
}

ChecklistSuggestion _checklistItem(Map<String, dynamic> json) {
  final raw = json['importance'];
  final importance = Importance.values.where((v) => v.name == raw).firstOrNull;
  if (importance == null) {
    throw FormatException('importance must be high|medium|low', raw);
  }

  return ChecklistSuggestion(
    templateId: json['template_id'] as String?,
    itemNameBn: json['item_name_bn'] as String,
    importance: importance,
    reasonBn: json['reason_bn'] as String?,
    aiExtra: json['ai_extra'] as bool? ?? false,
  );
}

List<String> _strings(Object? value) => [
  for (final v in value as List? ?? const []) v as String,
];
