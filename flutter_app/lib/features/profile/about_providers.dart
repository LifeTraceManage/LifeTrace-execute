import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppAboutInfo {
  const AppAboutInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    required this.platform,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String platform;
}

final appAboutInfoProvider = FutureProvider<AppAboutInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppAboutInfo(
    appName: info.appName,
    packageName: info.packageName,
    version: info.version,
    buildNumber: info.buildNumber,
    platform: _platformLabel(defaultTargetPlatform),
  );
});

String _platformLabel(TargetPlatform platform) => switch (platform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
