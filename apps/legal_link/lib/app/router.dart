import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/user_role.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/phone_screen.dart';
import '../features/auth/presentation/screens/role_selection_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/onboarding/presentation/screens/minimal_profile_screen.dart';
import '../features/onboarding/presentation/screens/advocate_registration_screen.dart';
import '../features/sos/presentation/screens/sos_screen.dart';
import '../features/sos/presentation/screens/sos_broadcast_form_screen.dart';
import '../features/sos/presentation/screens/advocate_sos_inbox_screen.dart';
import '../features/admin/presentation/screens/admin_verification_queue_screen.dart';
import '../features/admin/presentation/screens/advocate_profile_view_screen.dart';
import 'client_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) => _redirect(auth, state.uri.path),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const PhoneScreen()),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const MinimalProfileScreen(),
      ),
      GoRoute(
        path: '/advocate-registration',
        builder: (context, state) =>
            AdvocateRegistrationScreen(userId: auth.user!.id),
      ),
      ShellRoute(
        builder: (context, state, child) => auth.user?.role == UserRole.client
            ? ClientShell(
                phone: auth.user!.phone,
                expanded: state.uri.path == '/sos',
                child: child,
              )
            : child,
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/sos',
            builder: (context, state) =>
                SosScreen(contactPhone: auth.user!.phone),
          ),
        ],
      ),
      GoRoute(
        path: '/sos/new',
        builder: (context, state) => const SosBroadcastFormScreen(),
      ),
      GoRoute(
        path: '/sos/inbox',
        builder: (context, state) => const AdvocateSosInboxScreen(),
      ),
      GoRoute(
        path: '/admin/queue',
        builder: (context, state) => const AdminVerificationQueueScreen(),
      ),
      GoRoute(
        path: '/advocate/profile',
        builder: (context, state) =>
            AdvocateProfileViewScreen(advocateId: auth.user!.id),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String? _redirect(AuthState auth, String path) {
  if (auth.initializing) return path == '/login' ? null : '/login';
  if (auth.isSignedIn) {
    if (path == '/home') return null;
    if (path == '/advocate-registration' &&
        auth.user!.role == UserRole.advocate) {
      return null;
    }
    if (path == '/sos' && auth.user!.role == UserRole.client) return null;
    if (path == '/sos/new' && auth.user!.role == UserRole.client) return null;
    if (path == '/sos/inbox' && auth.user!.role == UserRole.advocate) {
      return null;
    }
    if (path == '/admin/queue' && auth.user!.role == UserRole.admin) {
      return null;
    }
    if (path == '/advocate/profile') return null;
    return '/home';
  }
  if (!auth.otpVerified) {
    final next = auth.phone == null ? '/login' : '/otp';
    return path == next ? null : next;
  }
  if (auth.role == null || !auth.roleConfirmed) {
    return path == '/role' ? null : '/role';
  }
  return path == '/profile' ? null : '/profile';
}
