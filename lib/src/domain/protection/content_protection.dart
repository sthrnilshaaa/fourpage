/// Abstract contract for DRM and Content Protection modules.
library;

import 'dart:async';
import 'drm_state.dart';
import 'protection_rights.dart';

abstract class ContentProtection {
  /// Protection scheme identifier (e.g., 'http://readium.org/2014/lcp' or 'none').
  String get schemeId;

  /// Current state of content protection.
  DrmState get currentState;

  /// Stream of state changes.
  Stream<DrmState> get stateStream;

  /// Authenticates using passphrase or credentials.
  Future<bool> authenticate(String passphrase);

  /// Validates license signature and status.
  Future<DrmState> validateLicense();

  /// Decrypts a raw resource stream for display/rendering.
  /// Standard security rule: Never write raw unencrypted keys to persistent disk storage.
  List<int> decryptResourceStream(String href, List<int> encryptedBytes);

  /// Returns current rights associated with license.
  ProtectionRights getRights();
}
