import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design tokens are stable', () {
    // Sanity guard so accidental token deletion shows up in CI.
    expect(AppColors.lake.toARGB32(), isNonZero);
    expect(AppSpacing.minTap, greaterThanOrEqualTo(48));
  });
}
