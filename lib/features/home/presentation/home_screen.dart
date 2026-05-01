import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: Text('Home — built out in M0/U3')),
      ),
    );
  }
}
