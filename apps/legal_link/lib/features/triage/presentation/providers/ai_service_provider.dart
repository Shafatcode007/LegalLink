import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai_service.dart';

final aiServiceProvider = Provider<AIService>((ref) {
  throw StateError('AIService must be overridden in app/di.dart');
});
