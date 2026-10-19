/// Pass-through protection provider for unprotected EPUB publications.
library;

import 'dart:async';
import '../../domain/protection/content_protection.dart';
import '../../domain/protection/drm_state.dart';
import '../../domain/protection/protection_rights.dart';

class PlainProtectionProvider implements ContentProtection {
  final _controller = StreamController<DrmState>.broadcast();

  @override
  String get schemeId => 'none';

  @override
  DrmState get currentState => const DrmState(
        status: DrmStatus.contentReady,
        schemeId: 'none',
      );

  @override
  Stream<DrmState> get stateStream => _controller.stream;

  @override
  Future<bool> authenticate(String passphrase) async => true;

  @override
  Future<DrmState> validateLicense() async => currentState;

  @override
  List<int> decryptResourceStream(String href, List<int> encryptedBytes) => encryptedBytes;

  @override
  ProtectionRights getRights() => const ProtectionRights();

  void dispose() {
    _controller.close();
  }
}
