/// Folder-scan storage access (Android "All files access").
///
/// On Android 11+ EPUBs are invisible to dart:io directory listing unless the
/// app holds MANAGE_EXTERNAL_STORAGE, which the user grants on a system
/// Settings screen - so a picked folder scanned as empty even when full of
/// books. Other platforms need nothing here.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class StorageAccess {
  StorageAccess._();

  static const _channel = MethodChannel('fourpages/storage');

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether folder scanning can see EPUB files. Always true off Android.
  static Future<bool> hasFolderAccess() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "All files access" screen and completes with the
  /// result once the user comes back to the app.
  static Future<bool> requestFolderAccess() async {
    if (!_isAndroid) return true;
    final returned = Completer<void>();
    late final AppLifecycleListener listener;
    var leftApp = false;
    listener = AppLifecycleListener(
      onHide: () => leftApp = true,
      onResume: () {
        if (leftApp && !returned.isCompleted) returned.complete();
      },
    );
    try {
      await _channel.invokeMethod<void>('requestAllFilesAccess');
      // Older Android shows an in-app permission dialog (no hide/resume).
      await returned.future.timeout(const Duration(minutes: 5), onTimeout: () {});
    } catch (_) {
      // Fall through to the re-check.
    } finally {
      listener.dispose();
    }
    return hasFolderAccess();
  }

  /// Ensures folder access before a scan, explaining why first. Returns
  /// whether scanning can proceed.
  static Future<bool> ensureFolderAccess(BuildContext context) async {
    if (await hasFolderAccess()) return true;
    if (!context.mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheetSurface,
        title: Text(l10n.allowAccessToYourBooks, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18)),
        content: Text(
          l10n.allFilesAccessExplanation,
          style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.notNow),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
    if (proceed != true) return false;
    return requestFolderAccess();
  }
}
