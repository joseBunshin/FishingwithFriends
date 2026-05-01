import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('design tokens', () {
    test('brand palette uses navy + orange + paper', () {
      expect(AppColors.navy, const Color(0xFF102B47));
      expect(AppColors.orange, const Color(0xFFF08948));
      expect(AppColors.paper, const Color(0xFFF5F7FA));
      expect(AppColors.card, const Color(0xFFFFFFFF));
    });

    test('minimum tap target is at least 48pt', () {
      expect(AppSpacing.minTap, greaterThanOrEqualTo(48));
    });

    test('light theme exposes navy primary, orange secondary, paper surface',
        () {
      final theme = AppTheme.light();
      expect(theme.colorScheme.primary, AppColors.navy);
      expect(theme.colorScheme.secondary, AppColors.orange);
      expect(theme.colorScheme.surface, AppColors.paper);
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme builds and keeps primary distinct from surface', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, isNot(theme.colorScheme.surface));
    });
  });
}
