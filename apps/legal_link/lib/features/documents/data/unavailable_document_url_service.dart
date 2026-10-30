import '../domain/document_url_service.dart';

/// Used when no Supabase backend is configured.
class UnavailableDocumentUrlService implements DocumentUrlService {
  const UnavailableDocumentUrlService();

  @override
  Future<Uri> signedUrl(DocumentBucket bucket, String path) async =>
      throw const DocumentUrlUnavailable();
}
