import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FishingWithFriendsApp extends ConsumerWidget {
  const FishingWithFriendsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Fishing with Friends',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
