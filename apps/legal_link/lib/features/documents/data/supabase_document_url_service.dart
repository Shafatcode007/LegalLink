import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/document_url_service.dart';

typedef SignObjectUrl = Future<String> Function(
  String bucket,
  String path,
  int expiresInSeconds,
);

/// Signs through Supabase Storage with the caller's session, so storage RLS
/// (sanad_admin_read, docs_read) decides whether a URL is issued.
class SupabaseDocumentUrlService implements DocumentUrlService {
  SupabaseDocumentUrlService(this._sign);

  SupabaseDocumentUrlService.fromClient(SupabaseClient client)
    : _sign = ((bucket, path, expiresIn) =>
          client.storage.from(bucket).createSignedUrl(path, expiresIn));

  final SignObjectUrl _sign;

  @override
  Future<Uri> signedUrl(DocumentBucket bucket, String path) async {
    checkObjectPath(path);
    final url = await _sign(bucket.name, path, signedUrlTtl.inSeconds);
    return Uri.parse(url);
  }
}
