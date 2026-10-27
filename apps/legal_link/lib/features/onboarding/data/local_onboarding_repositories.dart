import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import '../domain/advocate_registration.dart';
import '../domain/credential_upload.dart';

class PlatformCredentialPicker implements CredentialPicker {
  @override
  Future<CredentialFile?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: false,
      withReadStream: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > CredentialFile.maxBytes) throw UploadFailure.tooLarge;
    final stream = file.readStream;
    if (stream == null) throw UploadFailure.unavailable;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > CredentialFile.maxBytes) {
        throw UploadFailure.tooLarge;
      }
      builder.add(chunk);
    }
    final credential = CredentialFile(
      name: file.name,
      bytes: builder.takeBytes(),
    );
    final failure = credential.validate();
    if (failure != null) throw failure;
    try {
      final codec = await ui.instantiateImageCodec(
        credential.bytes,
        targetWidth: 256,
        targetHeight: 256,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw UploadFailure.unsupportedType;
    }
    return credential;
  }
}

/// Demo adapters never store identity numbers or document bytes on disk.
class LocalCredentialUploadRepository implements CredentialUploadRepository {
  @override
  Future<String> upload({
    required String userId,
    required CredentialKind kind,
    required CredentialFile file,
    required void Function(double progress) onProgress,
  }) async {
    final failure = file.validate();
    if (failure != null) throw failure;
    for (var step = 1; step <= 10; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      onProgress(step / 10);
    }
    return 'demo/$userId/${kind.name}';
  }
}

class LocalAdvocateRegistrationRepository
    implements AdvocateRegistrationRepository {
  @override
  Future<void> submit(String userId, AdvocateRegistration registration) async {
    if (!registration.isValid) throw ArgumentError('invalid_registration');
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
}
