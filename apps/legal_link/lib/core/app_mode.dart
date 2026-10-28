import 'package:riverpod/riverpod.dart';

enum AppMode { demo, live }

final appModeProvider = Provider<AppMode>((ref) => AppMode.demo);
