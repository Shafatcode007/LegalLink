import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/app/di.dart';
import 'package:legal_link/features/triage/data/template_ai_service.dart';
import 'package:legal_link/features/triage/data/summary_draft_mapper.dart';
import 'package:legal_link/features/triage/data/triage_result_mapper.dart';
import 'package:legal_link/features/triage/domain/entities/summary.dart';
import 'package:legal_link/features/triage/domain/entities/triage.dart';
import 'package:legal_link/features/triage/presentation/providers/ai_service_provider.dart';

void main() {
  group('TemplateAIService', () {
    final service = TemplateAIService();

    test('bail triage returns the seeded template checklist', () async {
      final result = await service.triage(
        const TriageInput(caseType: 'bail', answers: {}),
      );

      expect(result.caseType, 'bail');
      expect(result.checklist.map((i) => i.itemNameBn), [
        'এফআইআর কপি',
        'গ্রেপ্তার মেমো',
        'গ্রেপ্তার ব্যক্তির এনআইডি',
      ]);
      expect(result.checklist.first.importance, Importance.high);
      expect(result.disclaimerBn, isNotEmpty);
      expect(result.model, 'template');
      expect(result.fallbackUsed, isTrue);
    });

    test(
      'unknown case type still returns a disclaimer, no checklist',
      () async {
        final result = await service.triage(
          const TriageInput(caseType: 'unknown', answers: {}),
        );

        expect(result.checklist, isEmpty);
        expect(result.disclaimerBn, canonicalDisclaimerBn);
      },
    );
  });

  group('triageResultFromJson (TRD §7.2 contract)', () {
    final sample = <String, dynamic>{
      'case_type': 'bail',
      'urgency': 'high',
      'overview_bn': 'গ্রেপ্তারের পর জামিনের জন্য আবেদন করতে হবে',
      'actions_bn': ['থানা থেকে এফআইআর কপি নিন'],
      'checklist': [
        {
          'template_id': null,
          'item_name_bn': 'এফআইআর কপি',
          'importance': 'high',
          'reason_bn': 'মামলার মূল দলিল',
        },
      ],
      'questions_to_ask_lawyer_bn': ['জামিনের শুনানি কবে?'],
      'disclaimer_bn': 'এটি সাধারণ তথ্য, আইনি পরামর্শ নয়।',
      'model': 'qwen2.5-7b-instruct',
      'prompt_version': 'triage_v1',
      'cached': false,
    };

    test('parses the documented payload', () {
      final result = triageResultFromJson(sample);

      expect(result.urgency, 'high');
      expect(result.actionsBn, hasLength(1));
      expect(result.checklist.single.templateId, isNull);
      expect(result.checklist.single.reasonBn, 'মামলার মূল দলিল');
      expect(result.questionsToAskLawyerBn, hasLength(1));
      expect(result.promptVersion, 'triage_v1');
      expect(result.fallbackUsed, isFalse);
    });

    test('injects the canonical disclaimer when missing', () {
      final result = triageResultFromJson({...sample}..remove('disclaimer_bn'));

      expect(result.disclaimerBn, canonicalDisclaimerBn);
    });

    test('rejects an importance outside high|medium|low', () {
      final bad = {
        ...sample,
        'checklist': [
          {'item_name_bn': 'x', 'importance': 'urgent'},
        ],
      };

      expect(() => triageResultFromJson(bad), throwsFormatException);
    });
  });

  group('summarize (TRD §7.1, Worker /v1/ai/summarize contract)', () {
    test('template fallback returns the notes as a draft', () async {
      final draft = await TemplateAIService().summarize(
        const SummaryInput(rawNotes: '  শুনানি মুলতবি  ', caseType: 'bail'),
      );

      expect(draft.draftBn, 'শুনানি মুলতবি');
      expect(draft.disclaimerBn, canonicalSummaryDisclaimerBn);
      expect(draft.model, 'template');
      expect(draft.fallbackUsed, isTrue);
    });

    test('summaryDraftFromJson parses the Worker payload', () {
      final draft = summaryDraftFromJson({
        'draft_bn': 'জামিন আবেদন দাখিল',
        'model': 'qwen2.5-7b-instruct',
        'prompt_version': 'summary_v1',
        'tokens': 42,
        'fallback_used': false,
        'disclaimer_bn': 'এটি আপনার আইনজীবীর অনুমোদন সাপেক্ষ।',
      });

      expect(draft.draftBn, 'জামিন আবেদন দাখিল');
      expect(draft.tokens, 42);
      expect(draft.fallbackUsed, isFalse);
    });

    test('summaryDraftFromJson injects the disclaimer when missing', () {
      final draft = summaryDraftFromJson({'draft_bn': 'x', 'model': 'm'});

      expect(draft.disclaimerBn, canonicalSummaryDisclaimerBn);
    });
  });

  test('di.dart binds AIService to the template stub', () {
    final container = ProviderContainer(overrides: appOverrides);
    addTearDown(container.dispose);

    expect(container.read(aiServiceProvider), isA<TemplateAIService>());
  });
}
