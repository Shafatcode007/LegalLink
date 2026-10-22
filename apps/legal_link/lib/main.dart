import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'features/admin/admin.dart';
import 'shared/shared.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox<dynamic>('auth_box');

  runApp(
    ProviderScope(
      overrides: createDiOverrides(),
      child: const LegalLinkApp(),
    ),
  );
}

/// Existing Admin surface retained for the Admin smoke test.
class LegalLinkApp extends StatelessWidget {
  const LegalLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LegalLink (আইন সহায়)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.parchment,
        primaryColor: AppColors.brass,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brass,
          surface: AppColors.parchment,
          onSurface: AppColors.oxford,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.parchment,
          foregroundColor: AppColors.oxford,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const AdminVerificationQueueScreen(),
    );
  }
}
