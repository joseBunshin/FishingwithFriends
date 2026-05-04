import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/friends/application/friend_search_controller.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:fishing_with_friends/features/friends/presentation/friends_screen.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Stub controller that returns a fixed list of search results synchronously.
/// Bypasses the real debounced network search so the widget test exercises
/// the row layout, not the search pipeline.
class _StubFriendSearchController extends FriendSearchController {
  _StubFriendSearchController(this._results);

  final List<Profile> _results;

  @override
  Future<List<Profile>> build() async {
    return _results;
  }
}

const _bobby = Profile(
  id: 'angler-1',
  username: 'bobbybait',
  displayName: 'Bobby Bait',
);

const _emptyBundle = FriendsBundle(
  accepted: [],
  pendingIncoming: [],
  pendingOutgoing: [],
  profilesById: {},
);

Widget _wrap({required List<Profile> searchResults}) {
  final router = GoRouter(
    initialLocation: '/friends',
    routes: [
      GoRoute(path: '/friends', builder: (_, __) => const FriendsScreen()),
      GoRoute(
        path: '/profile/:userId',
        builder: (_, __) => const Scaffold(body: Text('profile')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      // Supabase isn't initialized in widget tests; null user is fine
      // here — the screen body falls through to the @angler placeholder.
      currentUserProvider.overrideWithValue(null),
      friendsBundleProvider.overrideWith((ref) async => _emptyBundle),
      friendSearchControllerProvider.overrideWith(
        () => _StubFriendSearchController(searchResults),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

Future<void> _setWidth(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('FriendsScreen search-result row layout', () {
    // Regression guard for fix-fwf-bug-batch-3 U2. Search-result rows
    // collapsed to vertical-text + missing-avatar at iPhone SE width
    // because _SearchResults wrapped its rows in a Column without
    // crossAxisAlignment.stretch — _AnglerRow's Expanded inside Row
    // then collapsed to its minimum intrinsic width (1 char per line).
    for (final width in [320.0, 375.0, 414.0]) {
      testWidgets('renders horizontally at ${width.toInt()}pt width',
          (tester) async {
        await _setWidth(tester, width);
        await tester.pumpWidget(_wrap(searchResults: const [_bobby]));
        await tester.pumpAndSettle();

        // Avatar is rendered (radius 24 → 48x48 SizedBox).
        expect(find.byType(AvatarView), findsWidgets);

        // Display name renders on a single line — height stays small,
        // not running the length of the page. The "Bobby Bait" Text
        // widget should be wider than it is tall.
        final nameFinder = find.text('Bobby Bait');
        expect(nameFinder, findsOneWidget);
        final nameSize = tester.getSize(nameFinder);
        expect(
          nameSize.width,
          greaterThan(nameSize.height),
          reason: 'Username text rendered vertically (height >= width) — '
              'the _SearchResults Column likely lost its stretch alignment.',
        );

        // The trailing "Add" button is also visible — a confirming check
        // that the row hasn't collapsed to its minimum intrinsic width.
        expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
      });
    }
  });
}
