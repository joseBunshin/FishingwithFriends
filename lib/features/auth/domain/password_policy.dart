/// Sign-up + password-reset policy for Fishing with Friends.
///
/// Modern criteria: length is the dominant factor for entropy, plus a
/// little character-class diversity. We deliberately do NOT require
/// special characters — NIST 800-63B advises against composition rules
/// that don't actually add entropy and just frustrate users.
class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;

  /// Ordered list shown to users so they can see what they're missing.
  static const List<PasswordRule> rules = [
    PasswordRule(
      label: 'At least 8 characters',
      check: _atLeastEightChars,
    ),
    PasswordRule(
      label: 'One uppercase letter (A–Z)',
      check: _hasUppercase,
    ),
    PasswordRule(
      label: 'One lowercase letter (a–z)',
      check: _hasLowercase,
    ),
    PasswordRule(
      label: 'One number (0–9)',
      check: _hasDigit,
    ),
  ];

  /// Returns true when every rule passes.
  static bool isStrong(String password) =>
      rules.every((r) => r.check(password));

  /// Returns the first failing rule, or null if all pass. Suitable for
  /// inline form validators.
  static String? firstFailure(String password) {
    for (final r in rules) {
      if (!r.check(password)) return r.label;
    }
    return null;
  }
}

class PasswordRule {
  const PasswordRule({required this.label, required this.check});
  final String label;
  final bool Function(String) check;
}

bool _atLeastEightChars(String s) => s.length >= PasswordPolicy.minLength;
bool _hasUppercase(String s) => RegExp('[A-Z]').hasMatch(s);
bool _hasLowercase(String s) => RegExp('[a-z]').hasMatch(s);
bool _hasDigit(String s) => RegExp('[0-9]').hasMatch(s);
