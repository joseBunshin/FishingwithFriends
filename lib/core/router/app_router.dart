import 'package:fishing_with_friends/core/router/app_shell.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/auth/presentation/sign_in_screen.dart';
import 'package:fishing_with_friends/features/catches/presentation/catch_detail_screen.dart';
import 'package:fishing_with_friends/features/catches/presentation/catch_log_screen.dart';
import 'package:fishing_with_friends/features/catches/presentation/catches_screen.dart';
import 'package:fishing_with_friends/features/friends/presentation/friends_screen.dart';
import 'package:fishing_with_friends/features/home/presentation/home_screen.dart';
import 'package:fishing_with_friends/features/map/presentation/map_screen.dart';
import 'package:fishing_with_friends/features/me/presentation/me_screen.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/edit_profile_screen.dart';
import 'package:fishing_with_friends/features/profile/presentation/onboarding_screen.dart';
import 'package:fishing_with_friends/features/stats/presentation/stats_screen.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/celebration_screen.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/year_in_review_screen.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/tournament_detail_screen.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/tournaments_screen.dart';
import 'package:fishing_with_friends/features/trips/presentation/trip_detail_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  const AppRoutes._();

  static const signIn = '/sign-in';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const catches = '/catches';
  static const logCatch = '/log';
  static const stats = '/stats';
  static const tourneys = '/tourneys';
  static const map = '/map';
  static const friends = '/friends';
  static const me = '/me';
  static const catchDetail = '/catches/:id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final isSignedIn = user != null;
      final goingToSignIn = state.matchedLocation == AppRoutes.signIn;
      final goingToOnboarding =
          state.matchedLocation == AppRoutes.onboarding;

      if (!isSignedIn && !goingToSignIn) return AppRoutes.signIn;
      if (isSignedIn && goingToSignIn) return AppRoutes.home;

      // After sign-in, send users that haven't finished onboarding to
      // the onboarding flow. We only redirect if the profile has loaded
      // and is missing the completed-at timestamp; while it's loading we
      // let the user through (they'll be re-evaluated when the profile
      // resolves via the AuthRefreshNotifier listening to myProfileProvider).
      if (isSignedIn && !goingToOnboarding) {
        final profile = ref.read(myProfileProvider).valueOrNull;
        if (profile != null && !profile.hasCompletedOnboarding) {
          return AppRoutes.onboarding;
        }
      }

      // Don't keep them on /onboarding after they've completed it.
      if (goingToOnboarding) {
        final profile = ref.read(myProfileProvider).valueOrNull;
        if (profile != null && profile.hasCompletedOnboarding) {
          return AppRoutes.home;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/me/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.logCatch,
        builder: (_, __) => const CatchLogScreen(),
      ),
      GoRoute(
        path: '/catches/:id',
        builder: (_, state) =>
            CatchDetailScreen(catchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (_, state) =>
            TripDetailScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (_, state) => TournamentDetailScreen(
          tournamentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/celebrate/:catchId',
        builder: (_, state) => CelebrationScreen(
          catchId: state.pathParameters['catchId']!,
        ),
      ),
      GoRoute(
        path: '/year-in-review',
        builder: (_, __) => const YearInReviewScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.catches,
            builder: (_, __) => const CatchesScreen(),
          ),
          GoRoute(
            path: AppRoutes.stats,
            builder: (_, __) => const StatsScreen(),
          ),
          GoRoute(
            path: AppRoutes.tourneys,
            builder: (_, __) => const TournamentsScreen(),
          ),
          GoRoute(
            path: AppRoutes.map,
            builder: (_, __) => const MapScreen(),
          ),
          GoRoute(
            path: AppRoutes.friends,
            builder: (_, __) => const FriendsScreen(),
          ),
          GoRoute(
            path: AppRoutes.me,
            builder: (_, __) => const MeScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _authSub = _ref.listen<AsyncValue<dynamic>>(
      authStateChangesProvider,
      (_, __) => notifyListeners(),
    );
    // Re-evaluate redirects when the user's profile loads or its
    // onboarding-completed timestamp flips.
    _profileSub = _ref.listen<AsyncValue<dynamic>>(
      myProfileProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<dynamic>> _authSub;
  late final ProviderSubscription<AsyncValue<dynamic>> _profileSub;

  @override
  void dispose() {
    _authSub.close();
    _profileSub.close();
    super.dispose();
  }
}
