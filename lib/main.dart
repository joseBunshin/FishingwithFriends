import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fishing_with_friends/app.dart';
import 'package:fishing_with_friends/core/env/env.dart';
import 'package:fishing_with_friends/features/notifications/application/push_background_handler.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/firebase_options.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // Firebase init runs in the background — main() does NOT await it.
  // On iOS the FCM SDK can block on APNs registration and never return,
  // freezing the app on the launch screen. Detaching it here means the
  // app boots immediately and Firebase comes online a few seconds later.
  // Worst case (Firebase fails entirely): in-app notifications still work
  // (they read from Supabase); only push delivery is affected.
  if (!kIsWeb) {
    unawaited(
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      )
          .timeout(const Duration(seconds: 8))
          .then((_) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackground);
      }).catchError((Object e) {
        debugPrint('Firebase init skipped: $e');
      }),
    );
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(prefs)),
      ],
      child: const FishingWithFriendsApp(),
    ),
  );
}
