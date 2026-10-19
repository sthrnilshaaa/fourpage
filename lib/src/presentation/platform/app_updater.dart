/// App updates, per Android build flavor (android/app/build.gradle.kts):
///  - github: asks the GitHub API for the latest release, downloads the APK
///    that fits this phone and hands it to the system installer.
///  - playstore: Google Play's in-app update flow.
/// Other platforms: no updates from inside the app.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/database/app_settings_repository.dart';

enum UpdateChannel { github, playstore, none }

class AppBuildInfo {
  final UpdateChannel channel;
  final String versionName;
  final int versionCode;
  final List<String> abis;
  const AppBuildInfo(this.channel, this.versionName, this.versionCode, this.abis);
}

/// A newer version that can be installed.
class AvailableUpdate {
  final UpdateChannel channel;

  /// Shown to the user, e.g. "1.2.0" (Play only gives a version code).
  final String version;
  final String? notes;

  /// GitHub only: the APK to download.
  final Uri? apkUrl;
  final int? apkSize;

  const AvailableUpdate({required this.channel, required this.version, this.notes, this.apkUrl, this.apkSize});
}

class UpdateCheckException implements Exception {
  final String message;
  const UpdateCheckException(this.message);
  @override
  String toString() => 'UpdateCheckException: $message';
}

class AppUpdater {
  AppUpdater._();
  static final AppUpdater instance = AppUpdater._();

  static const _channel = MethodChannel('fourpages/app_update');
  static const _keyLastCheck = 'update_last_check';
  static const _keySkipped = 'update_skipped_version';
  static const _autoCheckEvery = Duration(hours: 24);

  final _settings = AppSettingsRepository();
  AppBuildInfo? _info;

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<AppBuildInfo?> info() async {
    if (_info != null || !isSupported) return _info;
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('info');
      if (m == null) return null;
      _info = AppBuildInfo(
        switch (m['flavor']) { 'playstore' => UpdateChannel.playstore, 'github' => UpdateChannel.github, _ => UpdateChannel.none },
        (m['versionName'] as String?) ?? AppConstants.appVersion,
        (m['versionCode'] as num?)?.toInt() ?? 0,
        [for (final a in (m['abis'] as List?) ?? const []) a as String],
      );
    } on PlatformException catch (e) {
      debugPrint('App update info failed: $e');
    } on MissingPluginException {
      // Not registered (e.g. a test host).
    }
    return _info;
  }

  /// Newer version, or null when up to date. Throws [UpdateCheckException]
  /// when the check itself failed (offline, API error).
  Future<AvailableUpdate?> check() async {
    final info = await this.info();
    if (info == null) return null;
    await _settings.setString(_keyLastCheck, DateTime.now().toIso8601String());
    return switch (info.channel) {
      UpdateChannel.github => _checkGithub(info),
      UpdateChannel.playstore => _checkPlay(),
      UpdateChannel.none => null,
    };
  }

  /// The once-a-day check run at startup: null when it isn't time yet, the
  /// check failed, or the found version was skipped by the user.
  Future<AvailableUpdate?> autoCheck() async {
    if (!isSupported) return null;
    try {
      final last = DateTime.tryParse(await _settings.getString(_keyLastCheck) ?? '');
      if (last != null && DateTime.now().difference(last) < _autoCheckEvery) return null;
      final update = await check();
      if (update == null) return null;
      if (await _settings.getString(_keySkipped) == update.version) return null;
      return update;
    } catch (e) {
      debugPrint('Auto update check failed: $e');
      return null;
    }
  }

  Future<void> skip(AvailableUpdate update) => _settings.setString(_keySkipped, update.version);

  // --- Play -------------------------------------------------------------------

  Future<AvailableUpdate?> _checkPlay() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('check');
      if (m == null || m['available'] != true) return null;
      return AvailableUpdate(channel: UpdateChannel.playstore, version: '${m['availableVersionCode']}');
    } on PlatformException catch (e) {
      throw UpdateCheckException(e.message ?? e.code);
    }
  }

  /// Starts Google Play's update screen. True when the update went through.
  Future<bool> startPlayUpdate() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Play update failed: $e');
      return false;
    }
  }

  // --- GitHub -----------------------------------------------------------------

  Future<AvailableUpdate?> _checkGithub(AppBuildInfo info) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(AppConstants.githubLatestReleaseApi));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, '${AppConstants.appName}/${info.versionName}');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      // 404: no repo or no release yet - nothing to update to.
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateCheckException('GitHub answered ${response.statusCode}');
      }
      return parseGithubRelease(jsonDecode(body), currentVersion: info.versionName, abis: info.abis);
    } on SocketException catch (e) {
      throw UpdateCheckException(e.message);
    } on TimeoutException {
      throw const UpdateCheckException('timed out');
    } on FormatException catch (e) {
      throw UpdateCheckException(e.message);
    } finally {
      client.close(force: true);
    }
  }

  /// Picks the update out of a GitHub "latest release" response, or null if
  /// it isn't newer than [currentVersion] or has no usable APK.
  @visibleForTesting
  static AvailableUpdate? parseGithubRelease(Object? json, {required String currentVersion, required List<String> abis}) {
    if (json is! Map) return null;
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tag = (json['tag_name'] as String?) ?? '';
    if (compareVersions(tag, currentVersion) <= 0) return null;

    final apks = [
      for (final a in (json['assets'] as List?) ?? const [])
        if (a is Map &&
            (a['name'] as String? ?? '').toLowerCase().endsWith('.apk') &&
            !(a['name'] as String).toLowerCase().contains('playstore') &&
            a['browser_download_url'] is String)
          a,
    ];
    if (apks.isEmpty) return null;
    const allAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
    Map? pick;
    for (final abi in abis) {
      pick = apks.where((a) => (a['name'] as String).contains(abi)).firstOrNull;
      if (pick != null) break;
    }
    // A universal APK: no ABI in its name.
    pick ??= apks.where((a) => !allAbis.any((abi) => (a['name'] as String).contains(abi))).firstOrNull;
    if (pick == null) return null;

    return AvailableUpdate(
      channel: UpdateChannel.github,
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      notes: (json['body'] as String?)?.trim(),
      apkUrl: Uri.parse(pick['browser_download_url'] as String),
      apkSize: (pick['size'] as num?)?.toInt(),
    );
  }

  /// Compares "v1.2.3"-style versions number by number (ignores "+build"
  /// and "-suffix"). Positive when [a] is newer.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[+-]'))
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Downloads the update APK into cacheDir/updates (shared with the
  /// installer through the FileProvider in src/github/AndroidManifest.xml).
  /// [onProgress] gets 0..1, or null while the size is unknown.
  Future<File> downloadApk(AvailableUpdate update, {void Function(double?)? onProgress}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}/update-${update.version}.apk');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final response = await (await client.getUrl(update.apkUrl!)).close();
      if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}');
      final total = response.contentLength > 0 ? response.contentLength : update.apkSize;
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total != null && total > 0 ? received / total : null);
        }
      } finally {
        await sink.close();
      }
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// Opens the system installer. Returns false when the user first has to
  /// allow this app to install apps (their settings screen is opened).
  Future<bool> installApk(File apk) async {
    final result = await _channel.invokeMethod<String>('install', {'path': apk.path});
    if (result == 'needs_permission') {
      await _channel.invokeMethod<void>('openInstallSettings');
      return false;
    }
    return true;
  }
}
