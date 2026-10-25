import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/document_url_service.dart';

final documentUrlServiceProvider = Provider<DocumentUrlService>((ref) {
  throw StateError('DocumentUrlService must be overridden in app/di.dart');
});
