import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:legal_link/features/onboarding/data/supabase_credential_upload_repository.dart';
import 'package:legal_link/features/onboarding/domain/credential_upload.dart';

import 'support/supabase_fixture.dart';

CredentialFile largePhoto() {
  final bytes = Uint8List(6 * 1024 * 1024 + 11);
  bytes.setRange(0, 3, [255, 216, 255]);
  return CredentialFile(name: 'photo.jpg', bytes: bytes);
}

void main() {
  resumeTest();
  untrustedLocationTest();
}

void resumeTest() => test(
  'retry resumes from server offset and reports acknowledged bytes',
  () async {
    final fixture = SupabaseFixture((request) async => {});
    addTearDown(fixture.client.dispose);
    await fixture.signIn();
    var received = 0, creates = 0;
    var interrupted = false;
    final offsets = <int>[];
    final transport = MockClient((request) async {
      expect(request.headers['authorization'], startsWith('Bearer '));
      if (request.method == 'POST') {
        creates++;
        expect(request.headers['x-upsert'], isNot('true'));
        return http.Response(
          '',
          201,
          headers: {'location': '/storage/v1/upload/resumable/session'},
        );
      }
      if (request.method == 'PATCH') {
        offsets.add(int.parse(request.headers['upload-offset']!));
        if (received > 0 && !interrupted) {
          interrupted = true;
          throw http.ClientException('offline');
        }
        received += request.bodyBytes.length;
      }
      return http.Response('', 204, headers: {'upload-offset': '$received'});
    });
    final repo = SupabaseCredentialUploadRepository(
      fixture.client,
      endpoint: Uri.parse(
        'https://example.supabase.co/storage/v1/upload/resumable',
      ),
      transport: transport,
    );
    final file = largePhoto();
    final progress = <double>[];
    Future<String> upload() => repo.upload(
      userId: 'user-id',
      kind: CredentialKind.sanad,
      file: file,
      onProgress: progress.add,
    );
    await expectLater(upload(), throwsA(UploadFailure.unavailable));
    expect(progress.last, lessThan(1));
    final path = await upload();
    expect(path, startsWith('user-id/sanad-'));
    expect(creates, 1);
    expect(offsets, [0, 6 * 1024 * 1024, 6 * 1024 * 1024]);
    expect(progress.last, 1);
  },
);

void untrustedLocationTest() =>
    test('resumable URLs cannot forward credentials to another host', () async {
      final fixture = SupabaseFixture((request) async => {});
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      var calls = 0;
      final transport = MockClient((request) async {
        calls++;
        return http.Response(
          '',
          201,
          headers: {'location': 'https://untrusted.example/upload'},
        );
      });
      final repo = SupabaseCredentialUploadRepository(
        fixture.client,
        endpoint: Uri.parse(
          'https://example.supabase.co/storage/v1/upload/resumable',
        ),
        transport: transport,
      );
      await expectLater(
        repo.upload(
          userId: 'user-id',
          kind: CredentialKind.nid,
          file: largePhoto(),
          onProgress: (_) {},
        ),
        throwsA(UploadFailure.unavailable),
      );
      expect(calls, 1);
    });
