import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fishing_with_friends/features/notifications/data/notifications_repository_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Wires up foreground push display + tap routing.
///
/// Lifecycles:
///   - Foreground (app open): RemoteMessage arrives via onMessage stream.
///     iOS shows nothing by default; Android shows the system notification.
///     We render an in-app toast via flutter_local_notifications so the
///     user sees something either way.
///   - Background tap (app in tray): onMessageOpenedApp fires when the
///     user taps the system notification.
///   - Cold-start tap (app fully closed): getInitialMessage returns the
///     RemoteMessage that launched the app, if any.
///
/// `start(router)` should be called once after the GoRouter is ready
/// (in app.dart's build, behind a one-shot guard).
class PushMessageHandler {
  PushMessageHandler(this._ref);

  final Ref _ref;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _started = false;
  GoRouter? _router;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Idempotent — call from app.dart once the router is built.
  Future<void> start(GoRouter router) async {
    if (kIsWeb || _started) return;
    _started = true;
    _router = router;

    try {
      await _initLocalNotifications();
    } on Object catch (e) {
      debugPrint('local notifications init skipped: $e');
    }

    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForeground);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onTapped);

    // Cold-start tap.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _onTapped(initial);
  }

  Future<void> stop() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _foregroundSub = null;
    _openedSub = null;
    _started = false;
  }

  Future<void> _initLocalNotifications() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(
      init,
      onDidReceiveNotificationResponse: _onLocalTap,
    );
    // Android 8+ requires an explicit channel.
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          'default',
          'General',
          description: 'Friend requests, tournaments, feed highlights',
          importance: Importance.high,
        ),
      );
    }
  }

  void _onForeground(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;
    final title =
        notification?.title ?? (data['title'] as String? ?? 'Notification');
    final body = notification?.body ?? (data['body'] as String? ?? '');
    final deeplink = data['deeplink_path'] as String? ?? '';

    // Refresh the in-app notifications list so the unread badge updates.
    _ref.invalidate(myNotificationsProvider);

    _local.show(
      message.hashCode,
      title,
      body.isEmpty ? null : body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default',
          'General',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: deeplink,
    );
  }

  void _onTapped(RemoteMessage message) {
    final path = message.data['deeplink_path'] as String?;
    _ref.invalidate(myNotificationsProvider);
    if (path != null && path.isNotEmpty) {
      _router?.push(path);
    }
  }

  void _onLocalTap(NotificationResponse response) {
    final path = response.payload;
    if (path != null && path.isNotEmpty) {
      _router?.push(path);
    }
  }
}

final pushMessageHandlerProvider = Provider<PushMessageHandler>((ref) {
  final h = PushMessageHandler(ref);
  ref.onDispose(h.stop);
  return h;
});
