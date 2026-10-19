/// Domain failures representing high-level user-facing error states.
library;

abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

class InvalidPublicationFailure extends Failure {
  const InvalidPublicationFailure(super.message, {super.code});
}

class MissingResourceFailure extends Failure {
  const MissingResourceFailure(super.message, {super.code});
}

class ProtectionFailure extends Failure {
  const ProtectionFailure(super.message, {super.code});
}

class LicenseExpiredFailure extends Failure {
  const LicenseExpiredFailure(super.message, {super.code});
}

class NavigationFailure extends Failure {
  const NavigationFailure(super.message, {super.code});
}

class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code});
}
