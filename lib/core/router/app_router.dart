import 'package:fishing_with_friends/core/router/app_shell.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/auth/presentation/sign_in_screen.dart';
import 'package:fishing_with_friends/features/catches/presentation/catch_log_screen.dart';
import 'package:fishing_with_friends/features/catches/presentation/catches_screen.dart';
import 'package:fishing_with_friends/features/profile/presentation/profile_screen.dart';
import 'package:fishing_with_friends/features/social/presentation/feed_screen.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/tournaments_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  const AppRoutes._();

  static const signIn = '/sign-in';
  static const feed = '/feed';
  static const catches = '/catches';
  static const logCatch = '/log';
  static const tournaments = '/tournaments';
  static const profile = '/profile';
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.feed,
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final isSignedIn = user != null;
      final goingToSignIn = state.matchedLocation == AppRoutes.signIn;

      if (!isSignedIn && !goingToSignIn) return AppRoutes.signIn;
      if (isSignedIn && goingToSignIn) return AppRoutes.feed;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.logCatch,
        builder: (_, __) => const CatchLogScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.feed,
            builder: (_, __) => const FeedScreen(),
          ),
          GoRoute(
            path: AppRoutes.catches,
            builder: (_, __) => const CatchesScreen(),
          ),
          GoRoute(
            path: AppRoutes.tournaments,
            builder: (_, __) => const TournamentsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _sub = _ref.listen<AsyncValue<dynamic>>(
      authStateChangesProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<dynamic>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
