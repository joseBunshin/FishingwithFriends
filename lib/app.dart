import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/notifications/application/push_message_handler.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FishingWithFriendsApp extends ConsumerStatefulWidget {
  const FishingWithFriendsApp({super.key});

  @override
  ConsumerState<FishingWithFriendsApp> createState() =>
      _FishingWithFriendsAppState();
}

class _FishingWithFriendsAppState extends ConsumerState<FishingWithFriendsApp> {
  bool _pushStarted = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Lazy-start the push message handler once the router is built.
    // Foreground display + tap routing use the live router instance.
    if (!_pushStarted && !kIsWeb) {
      _pushStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pushMessageHandlerProvider).start(router);
      });
    }

    // Route the user to /reset-password the moment Supabase fires a
    // `passwordRecovery` event (i.e. they tapped the email link). The
    // SDK has already exchanged the token for a session by the time
    // this fires, so the screen can call `auth.updateUser(...)` directly.
    ref.listen<AsyncValue<AuthState>>(authStateChangesProvider, (_, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        router.go(AppRoutes.resetPassword);
      }
    });

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
