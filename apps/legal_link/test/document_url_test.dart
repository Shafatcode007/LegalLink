import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/app/di.dart';
import 'package:legal_link/features/documents/data/supabase_document_url_service.dart';
import 'package:legal_link/features/documents/data/unavailable_document_url_service.dart';
import 'package:legal_link/features/documents/domain/document_url_service.dart';

void main() {
  test('signed URLs live exactly 15 minutes (ADR-011)', () {
    expect(signedUrlTtl, const Duration(minutes: 15));
    expect(signedUrlTtl.inSeconds, 900);
  });

  test('only the private buckets are signable (avatars are public)', () {
    expect(DocumentBucket.values.map((b) => b.name), ['sanad', 'documents']);
  });

  group('SupabaseDocumentUrlService', () {
    late List<(String, String, int)> calls;
    late SupabaseDocumentUrlService service;

    setUp(() {
      calls = [];
      service = SupabaseDocumentUrlService((bucket, path, expiresIn) async {
        calls.add((bucket, path, expiresIn));
        return 'https://project.supabase.co/storage/v1/object/sign/$bucket/$path?token=t';
      });
    });

    test('signs with the bucket, path and a 900 s expiry', () async {
      final url = await service.signedUrl(
        DocumentBucket.documents,
        '99999999-9999-9999-9999-999999999991/doc1/fir.jpg',
      );

      expect(calls.single, (
        'documents',
        '99999999-9999-9999-9999-999999999991/doc1/fir.jpg',
        900,
      ));
      expect(url.host, 'project.supabase.co');
      expect(url.queryParameters['token'], 't');
    });

    test('rejects unsafe object paths without calling storage', () async {
      for (final bad in [
        '',
        '/abs/path.jpg',
        '../other/sanad.jpg',
        'a/../b.jpg',
        'a//b.jpg',
        r'a\b.jpg',
      ]) {
        await expectLater(
          service.signedUrl(DocumentBucket.sanad, bad),
          throwsArgumentError,
          reason: 'path "$bad" should be rejected',
        );
      }
      expect(calls, isEmpty);
    });
  });

  test('without a backend the service reports it is unavailable', () async {
    await expectLater(
      const UnavailableDocumentUrlService().signedUrl(
        DocumentBucket.sanad,
        'a/sanad.jpg',
      ),
      throwsA(isA<DocumentUrlUnavailable>()),
    );
  });

  test('without Supabase config, di.dart binds the unavailable service', () {
    final container = ProviderContainer(overrides: createDiOverrides());
    addTearDown(container.dispose);

    expect(
      container.read(documentUrlServiceProvider),
      isA<UnavailableDocumentUrlService>(),
    );
  });
}
