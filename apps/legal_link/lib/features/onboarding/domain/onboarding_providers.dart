import 'package:riverpod/riverpod.dart';

import 'advocate_registration.dart';
import 'credential_upload.dart';

final credentialPickerProvider = Provider<CredentialPicker>((ref) {
  throw StateError('CredentialPicker must be bound in app/di.dart');
});

final credentialUploadRepositoryProvider = Provider<CredentialUploadRepository>(
  (ref) {
    throw StateError('CredentialUploadRepository must be bound in app/di.dart');
  },
);

final advocateRegistrationRepositoryProvider =
    Provider<AdvocateRegistrationRepository>((ref) {
      throw StateError(
        'AdvocateRegistrationRepository must be bound in app/di.dart',
      );
    });
