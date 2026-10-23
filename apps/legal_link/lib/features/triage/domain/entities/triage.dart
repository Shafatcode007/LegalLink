/// Triage contract entities (TRD §6.4 `/v1/ai/triage`, §7.2 output schema).
library;

const canonicalDisclaimerBn = 'এটি সাধারণ তথ্য, আইনি পরামর্শ নয়।';

enum Importance { high, medium, low }

class TriageInput {
  const TriageInput({required this.caseType, required this.answers});

  final String caseType;
  final Map<String, Object?> answers;
}

class ChecklistSuggestion {
  const ChecklistSuggestion({
    required this.itemNameBn,
    required this.importance,
    this.templateId,
    this.reasonBn,
    this.aiExtra = false,
  });

  final String? templateId;
  final String itemNameBn;
  final Importance importance;
  final String? reasonBn;
  final bool aiExtra;
}

class TriageResult {
  const TriageResult({
    required this.caseType,
    required this.urgency,
    required this.overviewBn,
    required this.actionsBn,
    required this.checklist,
    required this.questionsToAskLawyerBn,
    required this.disclaimerBn,
    required this.model,
    required this.promptVersion,
    this.cached = false,
    this.fallbackUsed = false,
  });

  final String caseType;
  final String urgency;
  final String overviewBn;
  final List<String> actionsBn;
  final List<ChecklistSuggestion> checklist;
  final List<String> questionsToAskLawyerBn;
  final String disclaimerBn;
  final String model;
  final String promptVersion;
  final bool cached;
  final bool fallbackUsed;
}
