import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  const Env._();

  static String get supabaseUrl => _required('https://zragtwqxezkxbtwvriwg.supabase.co');
  static String get supabaseAnonKey => _required('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpyYWd0d3F4ZXpreGJ0d3ZyaXdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2NDU5NTQsImV4cCI6MjA5MzIyMTk1NH0.Web2i1pXhhn9Sk1e17efgrHfZQBaXa6lRVeKqzJLhmM');

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing $key in .env. Copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }

  static Future<void> load() => dotenv.load();
}
