import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.language,
    required this.role,
  });

  final String id;
  final String phone;
  final String fullName;
  final String language;
  final UserRole role;
}
