/// Private-file access goes only through short-lived signed URLs (ADR-011,
/// TRD §5.8). Who may sign is decided by storage RLS on the server.
library;

import 'package:riverpod/riverpod.dart';

/// Fixed by ADR-011; callers cannot choose a longer life.
const signedUrlTtl = Duration(minutes: 15);

/// Private buckets only; `avatars` is public and never signed.
enum DocumentBucket { sanad, documents }

class DocumentUrlUnavailable implements Exception {
  const DocumentUrlUnavailable();

  @override
  String toString() => 'DocumentUrlUnavailable: no storage backend configured';
}

abstract interface class DocumentUrlService {
  /// A URL that expires after [signedUrlTtl].
  Future<Uri> signedUrl(DocumentBucket bucket, String path);
}

/// Object paths are `{owner_or_case_id}/.../{file}` (TRD §5.8). Rejects
/// anything that could escape that folder or is not a relative path.
void checkObjectPath(String path) {
  final unsafe =
      path.isEmpty ||
      path.startsWith('/') ||
      path.contains(r'\') ||
      path.split('/').any((segment) => segment.isEmpty || segment == '..');
  if (unsafe) {
    throw ArgumentError.value(path, 'path', 'not a safe storage object path');
  }
}

/// Abstract provider token declared in domain layer (TRD §8.1).
///
/// Concrete bindings are provided ONLY in `lib/app/di.dart`.
final documentUrlServiceProvider = Provider<DocumentUrlService>((ref) {
  throw UnimplementedError(
    'documentUrlServiceProvider must be overridden in lib/app/di.dart',
  );
});
