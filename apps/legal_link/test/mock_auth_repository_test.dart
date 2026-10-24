import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:legal_link/features/auth/data/mock_auth_repository.dart';
import 'package:legal_link/features/auth/domain/user_role.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'legal_link_auth_test_',
    );

    Hive.init(tempDirectory.path);

    box = await Hive.openBox<dynamic>('auth_repository_test');
  });

  tearDown(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('mock auth repository completes and restores auth flow', () async {
    final repository = MockAuthRepository(box);

    expect(await repository.getCurrentUser(), isNull);

    expect(await repository.getVerifiedPhone(), isNull);

    const phone = '+8801712345678';

    await repository.sendOtp(phone);

    await expectLater(
      repository.verifyOtp(phone: phone, otp: '000000'),
      throwsA(anything),
    );

    await repository.verifyOtp(phone: phone, otp: '123456');

    expect(await repository.getVerifiedPhone(), phone);

    await repository.completeSignup(
      role: UserRole.client,
      fullName: 'Akib Hassan',
      language: 'bn',
    );

    final user = await repository.getCurrentUser();

    expect(user, isNotNull);
    expect(user!.phone, phone);
    expect(user.fullName, 'Akib Hassan');
    expect(user.language, 'bn');
    expect(user.role, UserRole.client);

    // Same Hive box should restore the persisted user.
    final restoredRepository = MockAuthRepository(box);
    final restoredUser = await restoredRepository.getCurrentUser();

    expect(restoredUser, isNotNull);
    expect(restoredUser!.phone, phone);

    await restoredRepository.signOut();

    expect(await restoredRepository.getCurrentUser(), isNull);

    expect(await restoredRepository.getVerifiedPhone(), isNull);
  });
}
