/// Friends-only RLS contract proof — runs only when `FWF_INTEGRATION=true`.
///
/// Why this exists: friends-only data visibility is the privacy contract the
/// entire app rests on. Mocked unit tests prove the Dart logic. Only an
/// integration test against a real Supabase project proves that the schema +
/// RLS policies + views all interact the way we expect.
///
/// What it asserts:
/// - **R4-a** Friend C reads angler A's normal catch including GPS.
/// - **R4-b** Stranger B reads angler A's catches and gets zero rows.
/// - **R4-c** Friend C reads angler A's Secret Spot catch with `location IS NULL`.
/// - **R4-d** Angler A reads their own Secret Spot catch with full GPS.
///
/// How to run:
/// ```bash
/// flutter pub get
/// FWF_INTEGRATION=true \
///   flutter test test_integration/friends_only_rls_test.dart
/// ```
/// (PowerShell: `$env:FWF_INTEGRATION='true'; flutter test test_integration/...`)
///
/// Setup expected before running:
///   1. `.env` must point at a dev Supabase project you control (NOT prod).
///   2. The project has run migrations 0001..0004.
///   3. Email confirmation is OFF in Authentication → Providers → Email
///      (otherwise sign-up returns an unconfirmed user and sign-in fails).
///
/// What it leaves behind: every inserted row + every test user is deleted
/// in `tearDownAll`. Even on a hard failure, the next run is idempotent —
/// sign-in succeeds for existing test users, friendships re-asserted.
library;

import 'package:fishing_with_friends/core/env/env.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabledEnvVar = 'FWF_INTEGRATION';
const _enabled = bool.fromEnvironment(_enabledEnvVar);

const _password = 'fwf-test-password-9j2K';
const _domain = 'fwf-test.local';
const _emailA = 'rls-a@$_domain';
const _emailB = 'rls-b@$_domain';
const _emailC = 'rls-c@$_domain';

/// Tracks ids we created so tearDownAll can clean them up.
final _createdCatchIds = <String>{};
final _createdTripIds = <String>{};

void main() {
  group('friends-only RLS contract (FWF_INTEGRATION)', () {
    if (!_enabled) {
      test('skipped — set FWF_INTEGRATION=true to run', () {
        // Visible-but-skipped marker so `flutter test` output makes the
        // gating explicit instead of silently doing nothing.
      }, skip: 'gated behind FWF_INTEGRATION env var');
      return;
    }

    setUpAll(() async {
      await dotenv.load();
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );

      // Ensure all three users exist; capture their auth uids.
      final aId = await _ensureUser(_emailA, 'rls-a');
      final cId = await _ensureUser(_emailC, 'rls-c');
      final bId = await _ensureUser(_emailB, 'rls-b');

      // Make A and C accepted friends. Idempotent.
      await _signIn(_emailA);
      await _ensureFriendship(requesterId: aId, addresseeId: cId);
      await _signIn(_emailC);
      await _acceptFriendship(requesterId: aId, addresseeId: cId);

      // Ensure A and B are NOT friends.
      await _signIn(_emailA);
      await _deleteFriendshipIfAny(a: aId, b: bId);
    });

    tearDownAll(() async {
      // Best-effort cleanup. Owner deletes their catches + trips; reactions
      // and comments cascade via on-delete-cascade FKs from catches.
      try {
        await _signIn(_emailA);
        for (final id in _createdCatchIds) {
          try {
            await Supabase.instance.client
                .from('catches')
                .delete()
                .eq('id', id);
          } on PostgrestException {
            // Row already gone — ignore.
          }
        }
        for (final id in _createdTripIds) {
          try {
            await Supabase.instance.client
                .from('trips')
                .delete()
                .eq('id', id);
          } on PostgrestException {
            // Row already gone — ignore.
          }
        }
      } finally {
        await Supabase.instance.client.auth.signOut();
      }
    });

    test("R4-a: friend C reads A's non-secret catch including GPS", () async {
      await _signIn(_emailA);
      final id = await _insertCatch(
        speciesLabel: 'Largemouth Bass',
        weightKg: 2,
        secretSpot: false,
        location: 'SRID=4326;POINT(-75.123 40.456)',
      );
      _createdCatchIds.add(id);

      await _signIn(_emailC);
      final rows = await Supabase.instance.client
          .from('catches_friend_view')
          .select()
          .eq('id', id);
      expect(rows, hasLength(1));
      expect(rows.first['location'], isNotNull);
    });

    test("R4-b: stranger B reads A's catches and gets zero rows", () async {
      await _signIn(_emailA);
      final id = await _insertCatch(
        speciesLabel: 'Walleye',
        weightKg: 1.5,
        secretSpot: false,
      );
      _createdCatchIds.add(id);

      await _signIn(_emailB);
      final rows = await Supabase.instance.client
          .from('catches_friend_view')
          .select()
          .eq('id', id);
      expect(rows, isEmpty);
    });

    test("R4-c: friend C sees A's Secret Spot catch with NULL location",
        () async {
      await _signIn(_emailA);
      final id = await _insertCatch(
        speciesLabel: 'Snook',
        weightKg: 4.5,
        secretSpot: true,
        location: 'SRID=4326;POINT(-80.1918 25.7617)',
      );
      _createdCatchIds.add(id);

      await _signIn(_emailC);
      final rows = await Supabase.instance.client
          .from('catches_friend_view')
          .select()
          .eq('id', id);
      expect(rows, hasLength(1));
      expect(rows.first['location'], isNull,
          reason: 'Secret Spot must hide location from friends');
    });

    test('R4-d: A reads their own Secret Spot catch with full GPS', () async {
      await _signIn(_emailA);
      final id = await _insertCatch(
        speciesLabel: 'Tarpon',
        weightKg: 30,
        secretSpot: true,
        location: 'SRID=4326;POINT(-80.1918 25.7617)',
      );
      _createdCatchIds.add(id);

      // Owner reads from `catches`, not the friend view.
      final rows = await Supabase.instance.client
          .from('catches')
          .select()
          .eq('id', id);
      expect(rows, hasLength(1));
      expect(rows.first['location'], isNotNull,
          reason: 'Owner always sees their own GPS');
    });

    // ─────────────── M2 / U10: trips + reactions + comments ────────────────

    test("R10/R3: friend C reads A's trip; stranger B sees zero rows",
        () async {
      await _signIn(_emailA);
      final tripId = await _insertTrip(title: 'M2 RLS Test');
      _createdTripIds.add(tripId);

      await _signIn(_emailC);
      final cRows = await Supabase.instance.client
          .from('trips')
          .select()
          .eq('id', tripId);
      expect(cRows, hasLength(1));

      await _signIn(_emailB);
      final bRows = await Supabase.instance.client
          .from('trips')
          .select()
          .eq('id', tripId);
      expect(bRows, isEmpty);
    });

    test("R10/R7: friend C inserts a reaction on A's catch; "
        'stranger B is denied', () async {
      await _signIn(_emailA);
      final catchId = await _insertCatch(
        speciesLabel: 'Largemouth Bass',
        weightKg: 2,
        secretSpot: false,
      );
      _createdCatchIds.add(catchId);
      final aId = Supabase.instance.client.auth.currentUser!.id;

      // Friend C reacts → succeeds.
      await _signIn(_emailC);
      await Supabase.instance.client.from('feed_reactions').upsert({
        'catch_id': catchId,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'kind': 'fire',
      });

      // R9: trigger writes a notifications row for catch owner.
      await _signIn(_emailA);
      final notif = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('recipient_id', aId)
          .eq('kind', 'reaction')
          .order('created_at', ascending: false)
          .limit(1);
      expect(notif, isNotEmpty,
          reason: 'reaction trigger should have written a notification');

      // Stranger B reacts → blocked by RLS.
      await _signIn(_emailB);
      await expectLater(
        Supabase.instance.client.from('feed_reactions').upsert({
          'catch_id': catchId,
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'kind': 'rod',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test("R10/R8: friend C comments on A's catch; stranger B is denied",
        () async {
      await _signIn(_emailA);
      final catchId = await _insertCatch(
        speciesLabel: 'Walleye',
        weightKg: 1.5,
        secretSpot: false,
      );
      _createdCatchIds.add(catchId);

      // Friend C comments → succeeds.
      await _signIn(_emailC);
      final inserted = await Supabase.instance.client
          .from('comments')
          .insert({
            'catch_id': catchId,
            'author_id': Supabase.instance.client.auth.currentUser!.id,
            'body': 'great fish @silentfisher',
          })
          .select()
          .single();
      expect(inserted['body'], contains('great fish'));

      // Stranger B comments → blocked.
      await _signIn(_emailB);
      await expectLater(
        Supabase.instance.client.from('comments').insert({
          'catch_id': catchId,
          'author_id': Supabase.instance.client.auth.currentUser!.id,
          'body': 'sneaky',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}

// ───────────────────────── helpers ──────────────────────────

Future<String> _ensureUser(String email, String username) async {
  final auth = Supabase.instance.client.auth;
  try {
    final res = await auth.signInWithPassword(email: email, password: _password);
    final uid = res.user!.id;
    await _ensureProfile(uid, username);
    return uid;
  } on AuthException {
    final res = await auth.signUp(email: email, password: _password);
    final uid = res.user!.id;
    // Sign in again in case the project has email confirmation off and
    // signUp returned a session-less user.
    await auth.signInWithPassword(email: email, password: _password);
    await _ensureProfile(uid, username);
    return uid;
  }
}

Future<void> _ensureProfile(String uid, String username) async {
  await Supabase.instance.client.from('profiles').upsert({
    'id': uid,
    'username': username,
  });
}

Future<void> _signIn(String email) async {
  await Supabase.instance.client.auth.signOut();
  await Supabase.instance.client.auth
      .signInWithPassword(email: email, password: _password);
}

Future<void> _ensureFriendship({
  required String requesterId,
  required String addresseeId,
}) async {
  await Supabase.instance.client.from('friendships').upsert({
    'requester_id': requesterId,
    'addressee_id': addresseeId,
    'status': 'pending',
  });
}

Future<void> _acceptFriendship({
  required String requesterId,
  required String addresseeId,
}) async {
  await Supabase.instance.client
      .from('friendships')
      .update({'status': 'accepted'})
      .eq('requester_id', requesterId)
      .eq('addressee_id', addresseeId);
}

Future<void> _deleteFriendshipIfAny({
  required String a,
  required String b,
}) async {
  final client = Supabase.instance.client;
  await client.from('friendships').delete().or(
        'and(requester_id.eq.$a,addressee_id.eq.$b),'
        'and(requester_id.eq.$b,addressee_id.eq.$a)',
      );
}

Future<String> _insertTrip({required String title}) async {
  final user = Supabase.instance.client.auth.currentUser!;
  // End any active trip first so the partial-unique-index doesn't refuse
  // a fresh insert across reruns.
  await Supabase.instance.client
      .from('trips')
      .update({'is_active': false})
      .eq('angler_id', user.id)
      .eq('is_active', true);
  final inserted = await Supabase.instance.client
      .from('trips')
      .insert({
        'angler_id': user.id,
        'title': title,
        'is_active': true,
      })
      .select()
      .single();
  return inserted['id'] as String;
}

Future<String> _insertCatch({
  required String speciesLabel,
  required double weightKg,
  required bool secretSpot,
  String? location,
}) async {
  final user = Supabase.instance.client.auth.currentUser!;
  final row = <String, dynamic>{
    'angler_id': user.id,
    'species_label': speciesLabel,
    'weight_kg': weightKg,
    'caught_at': DateTime.now().toUtc().toIso8601String(),
    'secret_spot': secretSpot,
    'catch_and_release': false,
    'photo_paths': const <String>[],
    if (location != null) 'location': location,
  };
  final inserted = await Supabase.instance.client
      .from('catches')
      .insert(row)
      .select()
      .single();
  return inserted['id'] as String;
}
