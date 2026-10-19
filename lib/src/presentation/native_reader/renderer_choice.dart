import '../../data/database/app_settings_repository.dart';

/// Per-book choice between the native PageEngine ("fast layout") and the book's original layout
/// (WebView reader). Unset = the engine's RendererPolicy decides.
class RendererChoice {
  static const native = 'native';
  static const original = 'original';

  static String _key(String publicationId) => 'renderer_$publicationId';

  static Future<String?> get(String publicationId) async {
    try {
      return await AppSettingsRepository().getString(_key(publicationId));
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String publicationId, String value) =>
      AppSettingsRepository().setString(_key(publicationId), value);
}
