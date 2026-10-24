import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/phone_screen.dart';
import '../features/auth/presentation/screens/role_selection_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/onboarding/presentation/screens/minimal_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',

    redirect: (context, state) {
      if (auth.initializing) {
        return null;
      }

      final path = state.uri.path;

      if (auth.isSignedIn) {
        return path == '/home' ? null : '/home';
      }

      if (!auth.otpVerified) {
        if (auth.phone == null) {
          return path == '/login' ? null : '/login';
        }

        return path == '/otp' ? null : '/otp';
      }

      if (auth.role == null || !auth.roleConfirmed) {
        return path == '/role' ? null : '/role';
      }

      if (path == '/profile') {
        return null;
      }

      return '/profile';
    },

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const PhoneScreen();
        },
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          return const OtpScreen();
        },
      ),
      GoRoute(
        path: '/role',
        builder: (context, state) {
          return const RoleSelectionScreen();
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) {
          return const MinimalProfileScreen();
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          return const HomeScreen();
        },
      ),
    ],
  );
});
