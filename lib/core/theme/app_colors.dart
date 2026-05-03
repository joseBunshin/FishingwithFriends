import 'package:flutter/material.dart';

/// Brand palette — sampled from Lovable references in `Assests/`.
/// Navy primary + warm orange accent on off-white surfaces. No gradient chrome.
class AppColors {
  const AppColors._();

  // Brand primaries
  static const Color navy = Color(0xFF102B47);
  static const Color navyDeep = Color(0xFF0A1E33);
  static const Color navySoft = Color(0xFF1F4570);

  // Accents
  static const Color orange = Color(0xFFF08948);
  static const Color orangeDeep = Color(0xFFD96F30);

  // Neutrals
  static const Color paper = Color(0xFFF5F7FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color mist = Color(0xFFE2E8F0);
  static const Color slate = Color(0xFF4A5568);
  static const Color ink = Color(0xFF0E1116);
  static const Color white = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF06A77D);
  static const Color warning = Color(0xFFF6BD60);
  static const Color error = Color(0xFFE63946);
}
