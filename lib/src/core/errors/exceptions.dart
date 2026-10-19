/// Exception classes representing lower-level errors in the EPUB engine.
library;

/// Base exception for reading system operations.
abstract class ReadingSystemException implements Exception {
  final String message;
  final dynamic cause;

  const ReadingSystemException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message${cause != null ? " (Cause: $cause)" : ""}';
}

/// Thrown when EPUB container or ZIP structure is invalid.
class ContainerException extends ReadingSystemException {
  const ContainerException(super.message, [super.cause]);
}

/// Thrown when XML or OPF parsing fails.
class PublicationParseException extends ReadingSystemException {
  const PublicationParseException(super.message, [super.cause]);
}

/// Thrown when a requested resource is missing from the container.
class ResourceNotFoundException extends ReadingSystemException {
  final String href;
  const ResourceNotFoundException(this.href, [dynamic cause])
      : super('Resource not found in publication: $href', cause);
}

/// Thrown when content protection or DRM validation fails.
class ProtectionException extends ReadingSystemException {
  const ProtectionException(super.message, [super.cause]);
}

/// Thrown when license authentication fails or license is expired.
class LicenseException extends ProtectionException {
  const LicenseException(super.message, [super.cause]);
}

/// Thrown when a locator position cannot be resolved.
class LocatorException extends ReadingSystemException {
  const LocatorException(super.message, [super.cause]);
}
