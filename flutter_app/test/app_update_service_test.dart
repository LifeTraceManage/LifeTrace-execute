import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/update/app_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('AppVersion', () {
    test('parses package and release versions', () {
      final current = AppVersion.fromPackageInfo(
        PackageInfo(
          appName: 'LifeTrace Execute',
          packageName: 'com.lifetrace.execute',
          version: '0.3.0',
          buildNumber: '3',
        ),
      );
      final latest = AppVersion.fromReleaseTag(
        'v0.3.1-build.4-abcdef0',
      );

      expect(current.label, '0.3.0+3');
      expect(latest?.label, '0.3.1+4');
      expect(latest!.compareTo(current), greaterThan(0));
    });

    test('build number participates in ordering', () {
      final older = AppVersion.fromReleaseTag('v0.3.0-build.3-a');
      final newer = AppVersion.fromReleaseTag('v0.3.0-build.4-b');

      expect(newer!.compareTo(older!), greaterThan(0));
    });
  });

  group('AppUpdateRelease', () {
    test('selects APK asset and GitHub digest', () {
      final release = AppUpdateRelease.fromGitHubJson({
        'tag_name': 'v0.4.0-build.5-1234567',
        'name': 'LifeTrace Execute v0.4.0+5',
        'body': 'Manual update test',
        'html_url': 'https://github.com/example/release',
        'assets': [
          {
            'name': 'LifeTrace-Execute-v0.4.0+5.apk.sha256',
            'browser_download_url': 'https://example.test/checksum',
            'size': 100,
          },
          {
            'name': 'LifeTrace-Execute-v0.4.0+5.apk',
            'browser_download_url': 'https://example.test/app.apk',
            'size': 73400320,
            'digest': 'sha256:ABCDEF',
          },
        ],
      });

      expect(release.version.label, '0.4.0+5');
      expect(release.apkName, 'LifeTrace-Execute-v0.4.0+5.apk');
      expect(release.apkUrl, 'https://example.test/app.apk');
      expect(release.apkSize, 73400320);
      expect(release.sha256, 'abcdef');
    });

    test('rejects a release without APK', () {
      expect(
        () => AppUpdateRelease.fromGitHubJson({
          'tag_name': 'v0.4.0-build.5-1234567',
          'assets': const [],
        }),
        throwsA(isA<AppUpdateException>()),
      );
    });
  });
}
