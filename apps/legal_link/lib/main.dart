import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/admin/admin.dart';
import 'shared/shared.dart';

void main() {
  runApp(
    const ProviderScope(
      child: LegalLinkApp(),
    ),
  );
}

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
