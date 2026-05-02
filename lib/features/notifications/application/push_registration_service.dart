import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/notifications/data/device_tokens_repository.dart';
import 'package:flutter/foundation.dart';
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
class PushRegistrationService {
  PushRegistrationService(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _refreshSub;
  bool _registered = false;

  /// Idempotent — safe to call multiple times. Returns true if a token
  /// was registered (or was already registered) for the current user.
  Future<bool> requestAndRegister() async {
    if (kIsWeb) return false;
    final user = _ref.read(currentUserProvider);
    if (user == null) return false;
    if (_registered) return true;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }

      // iOS needs APNs to be registered before getToken returns.
      if (Platform.isIOS || Platform.isMacOS) {
        await messaging.getAPNSToken();
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return false;

      await _ref
          .read(deviceTokensRepositoryProvider)
          .upsert(
            userId: user.id,
            token: token,
            platform: _platformLabel(),
          );

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
