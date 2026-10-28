import 'dart:typed_data';

enum CredentialKind { sanad, nid, avatar }

enum UploadFailure { tooLarge, unsupportedType, emptyFile, unavailable }

class CredentialFile {
  const CredentialFile({required this.name, required this.bytes});

  static const maxBytes = 20 * 1024 * 1024;
  final String name;
  final Uint8List bytes;

  UploadFailure? validate() {
    if (bytes.isEmpty) return UploadFailure.emptyFile;
    if (bytes.length > maxBytes) return UploadFailure.tooLarge;
    final extension = name.split('.').last.toLowerCase();
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    const pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];
    final png =
        bytes.length >= pngHeader.length &&
        Iterable<int>.generate(pngHeader.length)
            .every((index) => bytes[index] == pngHeader[index]);
    if (({'jpg', 'jpeg'}.contains(extension) && jpeg) ||
        (extension == 'png' && png)) {
      return null;
    }
    return UploadFailure.unsupportedType;
  }
}

abstract interface class CredentialPicker {
  Future<CredentialFile?> pick();
}

abstract interface class CredentialUploadRepository {
  Future<String> upload({
    required String userId,
    required CredentialKind kind,
    required CredentialFile file,
    required void Function(double progress) onProgress,
  });
}
