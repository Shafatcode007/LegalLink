import '../domain/ai_service.dart';
import '../domain/entities/summary.dart';
import '../domain/entities/triage.dart';

/// Zero-network, rule-based [AIService] (TRD §7.1). Serves as the Sprint 1-3
/// stub and stays as the fallback once the Worker is live. Items mirror the
/// `checklist_templates` rows in `db/seed.sql`.
class TemplateAIService implements AIService {
  static const _templates = <String, List<ChecklistSuggestion>>{
    'bail': [
      ChecklistSuggestion(
        itemNameBn: 'এফআইআর কপি',
        importance: Importance.high,
        reasonBn: 'মামলার মূল দলিল',
      ),
      ChecklistSuggestion(
        itemNameBn: 'গ্রেপ্তার মেমো',
        importance: Importance.high,
        reasonBn: 'গ্রেপ্তারের আইনি প্রমাণ',
      ),
      ChecklistSuggestion(
        itemNameBn: 'গ্রেপ্তার ব্যক্তির এনআইডি',
        importance: Importance.medium,
        reasonBn: 'পরিচয় যাচাই',
      ),
    ],
    'criminal': [
      ChecklistSuggestion(
        itemNameBn: 'এফআইআর কপি',
        importance: Importance.high,
        reasonBn: 'অভিযোগের ভিত্তি',
      ),
      ChecklistSuggestion(
        itemNameBn: 'সাক্ষীর তালিকা',
        importance: Importance.medium,
        reasonBn: 'সাক্ষ্য প্রস্তুতি',
      ),
    ],
    'family': [
      ChecklistSuggestion(
        itemNameBn: 'বিবাহের কাবিননামা',
        importance: Importance.high,
        reasonBn: 'মামলার ভিত্তি দলিল',
      ),
      ChecklistSuggestion(
        itemNameBn: 'ভরণপোষণের হিসাব',
        importance: Importance.medium,
        reasonBn: 'দাবির পরিমাণ নির্ধারণ',
      ),
    ],
    'property': [
      ChecklistSuggestion(
        itemNameBn: 'দলিল/খতিয়ান',
        importance: Importance.high,
        reasonBn: 'মালিকানার প্রমাণ',
      ),
      ChecklistSuggestion(
        itemNameBn: 'মৌজা ম্যাপ',
        importance: Importance.medium,
        reasonBn: 'সীমানা নির্ধারণ',
      ),
    ],
    'women_child': [
      ChecklistSuggestion(
        itemNameBn: 'মেডিকেল রিপোর্ট',
        importance: Importance.high,
        reasonBn: 'প্রমাণ সংরক্ষণ',
      ),
      ChecklistSuggestion(
        itemNameBn: 'নিরাপত্তা আবেদন খসড়া',
        importance: Importance.high,
        reasonBn: 'জরুরি সুরক্ষা',
      ),
    ],
  };

  @override
  Future<TriageResult> triage(TriageInput input) async {
    final checklist = _templates[input.caseType] ?? const [];

    return TriageResult(
      caseType: input.caseType,
      urgency: input.caseType == 'bail' ? 'high' : 'medium',
      overviewBn: 'আপনার আইনজীবী এই তালিকা পর্যালোচনা করে চূড়ান্ত করবেন।',
      actionsBn: const [],
      checklist: checklist,
      questionsToAskLawyerBn: const [],
      disclaimerBn: canonicalDisclaimerBn,
      model: 'template',
      promptVersion: 'template_v1',
      fallbackUsed: true,
    );
  }

  /// PRD §14: with no AI, the draft is the advocate's own notes, unchanged.
  @override
  Future<SummaryDraft> summarize(SummaryInput input) async {
    return SummaryDraft(
      draftBn: input.rawNotes.trim(),
      disclaimerBn: canonicalSummaryDisclaimerBn,
      model: 'template',
      promptVersion: 'template_v1',
      fallbackUsed: true,
    );
  }
}
