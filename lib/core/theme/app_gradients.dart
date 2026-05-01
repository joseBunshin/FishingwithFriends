import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Gradients are reserved for celebratory surfaces only — PR takeovers, share
/// cards, badge unlocks. Chrome (app bars, scaffolds, sign-in) stays flat.
class AppGradients {
  const AppGradients._();

  static const LinearGradient celebration = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.orange, AppColors.orangeDeep],
  );

  static const LinearGradient navyHero = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.navy, AppColors.navyDeep],
  );
}
