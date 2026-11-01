import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/auth/data/supabase_auth_repository.dart';
import 'package:legal_link/features/auth/domain/user_role.dart';
import 'package:legal_link/features/onboarding/data/supabase_advocate_registration_repository.dart';
import 'package:legal_link/features/onboarding/data/supabase_credential_upload_repository.dart';
import 'package:legal_link/features/onboarding/domain/advocate_registration.dart';
import 'package:legal_link/features/onboarding/domain/credential_upload.dart';
import 'package:legal_link/features/sos/data/supabase_client_sos_repository.dart';
import 'package:legal_link/features/sos/domain/sos_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const enabled = bool.fromEnvironment('RUN_LOCAL_INTEGRATION');
const url = String.fromEnvironment('SUPABASE_URL');
const key = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() {
  test(
    'local fixed OTP: real signup, PIN hash, credential upload and registration',
    registrationFlow,
    skip: !enabled,
  );
  test(
    'local fixed OTP: real SOS create, ownership read and cancel',
    sosFlow,
    skip: !enabled,
  );
}

Future<SupabaseClient> login(String phone) async {
  final client = SupabaseClient(
    url,
    key,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final repository = SupabaseAuthRepository(client);
  await repository.sendOtp(phone);
  await repository.verifyOtp(phone: phone, otp: '123456');
  return client;
}

Future<void> registrationFlow() async {
  final client = await login('+8801700000099');
  addTearDown(client.dispose);
  final auth = SupabaseAuthRepository(client);
  await auth.completeSignup(
    role: UserRole.advocate,
    fullName: 'Local Advocate',
    language: 'en',
  );
  final user = await auth.getCurrentUser();
  expect(user!.role, UserRole.advocate);
  final paths = await uploadPhotos(client, user.id);
  final application = AdvocateRegistration(
    nid: '1234567890',
    barCouncilNumber: 'LOCAL-42',
    courts: ['Dhaka Court'],
    districts: ['Dhaka'],
    specializations: {Specialization.bail},
    feeMin: 1000,
    feeMax: 5000,
    languages: {'bn', 'en'},
    pin: '4826',
    yearsPractice: 5,
    sanadReference: paths[0],
    nidReference: paths[1],
    avatarReference: paths[2],
  );
  await SupabaseAdvocateRegistrationRepository(client)
      .submit(user.id, application);
  final row = await client
      .from('advocates')
      .select(
        'nid_number,verification,years_practice,sanad_url,nid_url,attempts',
      )
      .eq('profile_id', user.id)
      .single();
  expect(row['nid_number'], '1234567890');
  expect(row['verification'], 'pending');
  expect(row['years_practice'], 5);
  expect(row['sanad_url'], paths[0]);
  expect(row['nid_url'], paths[1]);
  expect(row['attempts'], 0);
  await verifyReapplication(client, user.id, application);
}

Future<void> verifyReapplication(
  SupabaseClient client,
  String owner,
  AdvocateRegistration application,
) async {
  await SupabaseAdvocateRegistrationRepository(client)
      .submit(owner, application);
  final row = await client
      .from('advocates')
      .select('attempts,sanad_url,nid_url')
      .eq('profile_id', owner)
      .single();
  expect(row['attempts'], 0);
  expect(row['sanad_url'], application.sanadReference);
  expect(row['nid_url'], application.nidReference);
}

Future<List<String>> uploadPhotos(SupabaseClient client, String owner) async {
  final repository = SupabaseCredentialUploadRepository(
    client,
    endpoint: Uri.parse('$url/storage/v1/upload/resumable'),
  );
  addTearDown(repository.dispose);
  final photo = CredentialFile(
    name: 'credential.png',
    bytes: Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aHfoAAAAASUVORK5CYII=',
      ),
    ),
  );
  final paths = <String>[];
  for (final kind in CredentialKind.values) {
    double progress = 0;
    paths.add(
      await repository.upload(
        userId: owner,
        kind: kind,
        file: photo,
        onProgress: (value) => progress = value,
      ),
    );
    expect(progress, 1);
  }
  return paths;
}

Future<void> sosFlow() async {
  final client = await login('+8801700000003');
  addTearDown(client.dispose);
  await SupabaseAuthRepository(client).completeSignup(
    role: UserRole.client,
    fullName: 'Local Client',
    language: 'en',
  );
  final repository = SupabaseClientSosRepository(client);
  final request = await repository.submit(
    SosDraft(
      requestId: newSosRequestId(),
      personName: 'Local SOS Test',
      policeStation: 'Dhanmondi',
      districtCourt: 'Dhaka',
      contactPhone: '+8801700000003',
    ),
  );
  expect(request.status, ClientSosStatus.open);
  final confirmed = await repository.watch(request.id, request.district).first;
  expect(confirmed.id, request.id);
  final cancelled = await repository.cancel(request.id);
  expect(cancelled.status, ClientSosStatus.cancelled);
}
