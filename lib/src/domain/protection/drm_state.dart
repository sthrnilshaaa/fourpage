/// Finite State Machine representation for DRM / Content Protection.
library;

enum DrmStatus {
  unknown,
  protectionDetected,
  licenseRequired,
  licenseLoaded,
  licenseValidated,
  authorized,
  contentReady,
  expired,
  invalidLicense,
  authenticationRequired,
  decryptionError,
  unsupportedProtection,
}

class DrmState {
  final DrmStatus status;
  final String? schemeId;
  final String? message;
  final bool isAuthenticated;

  const DrmState({
    required this.status,
    this.schemeId,
    this.message,
    this.isAuthenticated = false,
  });

  bool get isReady => status == DrmStatus.contentReady || status == DrmStatus.authorized;
  bool get hasError =>
      status == DrmStatus.expired ||
      status == DrmStatus.invalidLicense ||
      status == DrmStatus.decryptionError ||
      status == DrmStatus.unsupportedProtection;

  DrmState copyWith({
    DrmStatus? status,
    String? schemeId,
    String? message,
    bool? isAuthenticated,
  }) {
    return DrmState(
      status: status ?? this.status,
      schemeId: schemeId ?? this.schemeId,
      message: message ?? this.message,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  String toString() => 'DrmState(status: $status, scheme: $schemeId, msg: $message)';
}
