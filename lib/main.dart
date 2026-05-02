import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fishing_with_friends/app.dart';
import 'package:fishing_with_friends/core/env/env.dart';
import 'package:fishing_with_friends/features/notifications/application/push_background_handler.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // Firebase only initializes on mobile. Web is skipped — FCM web setup
  // is its own beast and out of v1 scope.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Register the background isolate handler before any message can
      // arrive. The handler is a top-level @pragma('vm:entry-point')
      // function in push_background_handler.dart.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackground);
    } on Object catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
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
