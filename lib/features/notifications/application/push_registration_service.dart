import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/notifications/data/device_tokens_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-stop service for FCM permission + token registration.
///
/// Flow:
///   1. App calls `requestAndRegister()` post-first-success of a catch
///      save (less friction than blocking sign-in with the prompt).
///   2. Service requests notification permission via firebase_messaging.
///   3. If granted, fetches the FCM token and upserts it into
///      device_tokens for the current user.
///   4. Subscribes to onTokenRefresh and re-upserts when the token rotates.
///
/// kIsWeb bypass — we don't ship FCM web in v1.
///
/// **DEBUG INSTRUMENTATION (1.0.0+6):** every step fires a local
/// notification on the device so we can see exactly where the chain
/// breaks without a USB cable. Remove these calls (search for
/// `_debugNotify`) once push delivery is verified working end-to-end.
class PushRegistrationService {
  PushRegistrationService(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _refreshSub;
  bool _registered = false;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Idempotent — safe to call multiple times. Returns true if a token
  /// was registered (or was already registered) for the current user.
  Future<bool> requestAndRegister() async {
    if (kIsWeb) return false;
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      await _debugNotify('FCM step 0: no user — skipping');
      return false;
    }
    if (_registered) {
      await _debugNotify('FCM already registered — short-circuit');
      return true;
    }

    await _debugNotify('FCM step 1: requesting permission');
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _debugNotify(
        'FCM step 2: permission = ${settings.authorizationStatus.name}',
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        await _debugNotify('FCM aborted: permission not granted');
        return false;
      }

      // iOS needs APNs to be registered before getToken returns.
      // getAPNSToken() returns the cached token; it does NOT wait for iOS
      // to complete registration. On a fresh app launch, registration can
      // take 1-5+ seconds (network round-trip to Apple). Retry with backoff
      // so the post-save call doesn't race the launch-time registration.
      String? apnsToken;
      if (Platform.isIOS || Platform.isMacOS) {
        await _debugNotify('FCM step 3: fetching APNs token (with retry)');
        for (var i = 0; i < 6; i++) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null) break;
          await _debugNotify(
            'FCM step 3.${i + 1}: APNs token still NULL, retrying in 1.5s',
          );
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
        await _debugNotify(
          'FCM step 4: APNs token = ${apnsToken == null ? "NULL after 6 retries" : "ok (${apnsToken.length} chars)"}',
        );
        if (apnsToken == null) {
          await _debugNotify(
            'FCM aborted: APNs token still null after ~9s of retries. '
            'iOS itself is refusing to issue an APNs token — likely '
            'provisioning profile missing push entitlement, or stale '
            'profile cached. Try a fresh archive in Xcode.',
          );
          return false;
        }
      }

      await _debugNotify('FCM step 5: fetching FCM token');
      final token = await messaging.getToken();
      await _debugNotify(
        'FCM step 6: FCM token = ${token == null ? "NULL" : "ok (${token.length} chars)"}',
      );
      if (token == null || token.isEmpty) {
        await _debugNotify('FCM aborted: FCM token null/empty');
        return false;
      }

      await _debugNotify('FCM step 7: upserting to device_tokens');
      await _ref
          .read(deviceTokensRepositoryProvider)
          .upsert(
            userId: user.id,
            token: token,
            platform: _platformLabel(),
          );
      await _debugNotify('FCM step 8: ✓ device_tokens upsert succeeded');

      _refreshSub ??= messaging.onTokenRefresh.listen((newToken) async {
        final u = _ref.read(currentUserProvider);
        if (u == null) return;
        await _ref
            .read(deviceTokensRepositoryProvider)
            .upsert(
              userId: u.id,
              token: newToken,
              platform: _platformLabel(),
            );
      });

      _registered = true;
      return true;
    } on Object catch (e) {
      debugPrint('Push registration skipped: $e');
      await _debugNotify('FCM EXCEPTION: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    _registered = false;
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  /// TEMPORARY DEBUG SURFACE — writes a row to public.push_debug_log so
  /// we can query the registration chain remotely in SQL editor without
  /// needing device logs. Migration 0026 created the table.
  /// Remove once push delivery is verified end-to-end.
  Future<void> _debugNotify(String msg) async {
    debugPrint('[push-debug] $msg');
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await _ref.read(supabaseClientProvider).from('push_debug_log').insert({
        'user_id': user.id,
        'msg': msg,
      });
    } on Object catch (e) {
      // Last-resort: still try local notifications so we have SOMETHING
      // visible even if Supabase write fails.
      debugPrint('[push-debug] table insert failed: $e');
      try {
        await _local.show(
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
          'Push debug',
          msg,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default',
              'General',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      } on Object catch (_) {
        // Both surfaces failed; nothing more we can do without a cable.
      }
    }
  }
}

final deviceTokensRepositoryProvider =
    Provider<DeviceTokensRepository>((ref) {
  return DeviceTokensRepository(ref.watch(supabaseClientProvider));
});

final pushRegistrationServiceProvider =
    Provider<PushRegistrationService>((ref) {
  final svc = PushRegistrationService(ref);
  ref.onDispose(svc.dispose);
  return svc;
});
