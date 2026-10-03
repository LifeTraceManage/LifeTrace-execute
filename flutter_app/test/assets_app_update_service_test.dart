import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/workspaces/assets/src/update/app_update_service.dart';

void main() {
  group('AppVersion', () {
    test('parses release workflow tag with build and commit suffix', () {
      final version =
          AppVersion.tryParseReleaseTag('v0.2.0-build.2-ebea25b');

      expect(version, isNotNull);
      expect(version!.display, '0.2.0+2');
    });

    test('compares semantic version before build number', () {
      const current = AppVersion(major: 0, minor: 2, patch: 0, build: 9);
      const latest = AppVersion(major: 0, minor: 3, patch: 0, build: 1);

      expect(latest.compareTo(current), greaterThan(0));
    });

    test('uses build number when semantic versions are equal', () {
      const current = AppVersion(major: 0, minor: 2, patch: 0, build: 2);
      const latest = AppVersion(major: 0, minor: 2, patch: 0, build: 3);

      expect(latest.compareTo(current), greaterThan(0));
    });

    test('rejects unsupported tags', () {
      expect(AppVersion.tryParseReleaseTag('debug-ebea25b'), isNull);
    });
  });
}
