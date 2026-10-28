import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    required this.appName,
    required this.icon,
    required this.child,
    super.key,
  });
  final String appName;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.oxford,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, color: AppColors.brass, size: 38),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 44),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthHint extends StatelessWidget {
  const AuthHint({
    required this.text,
    this.icon = Icons.info_outline,
    super.key,
  });
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 24, color: AppColors.oxfordMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
        ),
      ),
    ],
  );
}
