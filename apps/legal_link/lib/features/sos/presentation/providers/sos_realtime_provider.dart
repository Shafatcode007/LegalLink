import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/sos_realtime_repository.dart';

final sosRealtimeRepositoryProvider = Provider<SosRealtimeRepository>((ref) {
  throw StateError('SosRealtimeRepository must be overridden in app/di.dart');
});
