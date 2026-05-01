import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Clean gradient surfaces used in place of background photography.
class AppGradients {
  const AppGradients._();

  static const LinearGradient water = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.deepWater, AppColors.lake, AppColors.sky],
  );

  static const LinearGradient dawn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.sky, AppColors.sunrise],
  );

  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.foam, AppColors.paper],
  );
}
