import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/onboarding/domain/advocate_registration.dart';
import 'package:legal_link/features/onboarding/domain/credential_upload.dart';
import 'package:legal_link/features/sos/domain/sos_draft.dart';

void main() {
  test('NID supports the three contract lengths and Western digits only', () {
    for (final value in ['1234567890', '1234567890123', '12345678901234567']) {
      expect(AdvocateRegistration.validNid(value), true);
    }
    for (final value in [
      '',
      '123456789',
      '123456789012',
      '১২৩৪৫৬৭৮৯০',
      '123456789x',
    ]) {
      expect(AdvocateRegistration.validNid(value), false);
    }
  });

  test(
    'credential validation rejects empty, oversized and disguised files',
    () {
      expect(
        CredentialFile(name: 'empty.png', bytes: Uint8List(0)).validate(),
        UploadFailure.emptyFile,
      );
      expect(
        CredentialFile(
          name: 'large.jpg',
          bytes: Uint8List(CredentialFile.maxBytes + 1),
        ).validate(),
        UploadFailure.tooLarge,
      );
      expect(
        CredentialFile(
          name: 'fake.png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ).validate(),
        UploadFailure.unsupportedType,
      );
      expect(
        CredentialFile(
          name: 'fake.jpg',
          bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ).validate(),
        UploadFailure.unsupportedType,
      );
      expect(
        CredentialFile(
          name: 'photo.JPG',
          bytes: Uint8List.fromList([255, 216, 255]),
        ).validate(),
        isNull,
      );
    },
  );

  test('SOS requires valid required fields and a Bangladeshi contact', () {
    const draft = SosDraft(
      personName: 'A Person',
      policeStation: 'Dhanmondi',
      districtCourt: 'Dhaka',
      contactPhone: '+8801712345678',
    );
    expect(draft.isValid, true);
    expect(SosDraft.validPhone('01712345678'), true);
    expect(SosDraft.validPhone('+8801212345678'), false);
    expect(SosDraft.validPhone('1234'), false);
    expect(
      const SosDraft(
        personName: '',
        policeStation: 'Thana',
        districtCourt: 'Dhaka',
        contactPhone: '01712345678',
      ).isValid,
      false,
    );
  });
}
