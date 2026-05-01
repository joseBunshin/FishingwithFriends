/// Base type for surfaceable errors. UI layers can catch this and render
/// the [message] without leaking internal details.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message';
}

class AuthFailure extends AppException {
  const AuthFailure(super.message, {super.cause});
}

class ValidationFailure extends AppException {
  const ValidationFailure(super.message, {super.cause});
}

class NetworkFailure extends AppException {
  const NetworkFailure(super.message, {super.cause});
}
