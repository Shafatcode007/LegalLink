import 'package:riverpod/riverpod.dart';

import 'sos_draft.dart';

final sosRepositoryProvider = Provider<SosRepository>((ref) {
  throw StateError('SosRepository must be bound in app/di.dart');
});
