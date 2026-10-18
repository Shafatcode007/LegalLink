import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class AinSohayApp extends ConsumerWidget {
  const AinSohayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final auth = ref.watch(authControllerProvider);

    return MaterialApp.router(
      title: 'Ain Sohay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(auth.language),
      routerConfig: router,
      locale: Locale(auth.language),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
