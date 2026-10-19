/// WebView Security Policy enforcing explicit permission denials and sandboxing for Web content.
library;

class WebViewSecurityPolicy {
  final bool allowGeolocation;
  final bool allowCamera;
  final bool allowMicrophone;
  final bool allowNotifications;
  final bool allowArbitraryNativeBridge;
  final bool allowCleartextHttp;

  const WebViewSecurityPolicy({
    this.allowGeolocation = false,
    this.allowCamera = false,
    this.allowMicrophone = false,
    this.allowNotifications = false,
    this.allowArbitraryNativeBridge = false,
    this.allowCleartextHttp = false,
  });

  /// Default strict security sandbox policy.
  static const WebViewSecurityPolicy strict = WebViewSecurityPolicy();

  /// Evaluates whether a requested platform resource permission should be granted.
  bool isPermissionGranted(String permissionType) {
    switch (permissionType.toLowerCase()) {
      case 'geolocation':
        return allowGeolocation;
      case 'camera':
        return allowCamera;
      case 'microphone':
        return allowMicrophone;
      case 'notification':
      case 'notifications':
        return allowNotifications;
      default:
        return false;
    }
  }
}
