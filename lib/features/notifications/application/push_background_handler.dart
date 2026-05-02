import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Background message handler — runs in a separate isolate when the app
/// is terminated or in the background and a data-only push lands.
///
/// MUST be a top-level function annotated with @pragma('vm:entry-point')
/// so the FCM dart entry-point tree-shaker doesn't strip it.
///
/// We keep it intentionally minimal: log + return. Tap routing happens
/// in the foreground isolate via getInitialMessage / onMessageOpenedApp.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackground(RemoteMessage message) async {
  // Firebase needs to be initialized in the background isolate too.
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint(
      'BG push: ${message.messageId} '
      'kind=${message.data['kind']} '
      'deeplink=${message.data['deeplink_path']}',
    );
  }
}
