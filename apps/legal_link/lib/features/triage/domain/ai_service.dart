import 'entities/summary.dart';
import 'entities/triage.dart';

/// Single AI entry point (TRD §7.1). The Worker switches providers via
/// `AI_PROVIDER`; the app only swaps implementations here.
abstract interface class AIService {
  Future<TriageResult> triage(TriageInput input);

  Future<SummaryDraft> summarize(SummaryInput input);
}
