import 'package:aread/src/presentation/platform/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compareVersions', () {
    expect(AppUpdater.compareVersions('v1.2.0', '1.1.9'), greaterThan(0));
    expect(AppUpdater.compareVersions('1.0', '1.0.0+5'), 0);
    expect(AppUpdater.compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(AppUpdater.compareVersions('v2.0.0-beta', '1.9.9'), greaterThan(0));
  });

  Map<String, Object?> release(String tag, List<String> apks) => {
        'tag_name': tag,
        'body': 'Notes',
        'assets': [
          for (final n in apks) {'name': n, 'browser_download_url': 'https://x/$n', 'size': 10},
        ],
      };

  test('picks the APK for this phone, ignores old or Play releases', () {
    final r = release('v1.1.0', ['app-armeabi-v7a-release.apk', 'app-arm64-v8a-release.apk', 'app-playstore.apk']);
    final u = AppUpdater.parseGithubRelease(r, currentVersion: '1.0.0', abis: ['arm64-v8a']);
    expect(u!.version, '1.1.0');
    expect(u.apkUrl.toString(), endsWith('arm64-v8a-release.apk'));
    expect(AppUpdater.parseGithubRelease(r, currentVersion: '1.1.0', abis: ['arm64-v8a']), isNull);
    final universal = AppUpdater.parseGithubRelease(
      release('1.2.0', ['fourpages.apk']), currentVersion: '1.0.0', abis: ['x86_64']);
    expect(universal!.apkUrl.toString(), endsWith('fourpages.apk'));
    expect(AppUpdater.parseGithubRelease(release('1.2.0', ['notes.txt']), currentVersion: '1.0.0', abis: []), isNull);
  });

  test('release notes lose their Markdown', () {
    const md = '## [1.0.2] - 2026-10-21\r\n\r\n### Added\n- **Undo** after `highlighting`\n* See [the guide](https://x.y)\n\n\n\nDone';
    expect(
      AppUpdater.plainNotes(md),
      '[1.0.2] - 2026-10-21\n\nAdded\n• Undo after highlighting\n• See the guide\n\nDone',
    );
    expect(AppUpdater.plainNotes('   '), isNull);
    expect(AppUpdater.plainNotes(null), isNull);
  });
}
