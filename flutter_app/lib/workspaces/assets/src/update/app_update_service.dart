import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _latestReleaseUrl =
    'https://api.github.com/repos/LifeTraceManage/LifeTrace-execute/releases/latest';

class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  factory AppVersion.fromPackageInfo(PackageInfo info) {
    final parts = info.version.split('.');
    if (parts.length != 3) {
      throw FormatException('Unsupported app version: ${info.version}');
    }
    return AppVersion(
      major: int.parse(parts[0]),
      minor: int.parse(parts[1]),
      patch: int.parse(parts[2]),
      build: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  static AppVersion? tryParseReleaseTag(String tag) {
    final match = RegExp(
      r'^v(\d+)\.(\d+)\.(\d+)(?:-build\.(\d+))?(?:-[0-9a-fA-F]+)?$',
    ).firstMatch(tag.trim());
    if (match == null) return null;
    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.tryParse(match.group(4) ?? '') ?? 0,
    );
  }

  @override
  int compareTo(AppVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
      (build, other.build),
    ]) {
      final comparison = pair.$1.compareTo(pair.$2);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  String get display =>
      build > 0 ? '$major.$minor.$patch+$build' : '$major.$minor.$patch';
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseTag,
    required this.releasePageUrl,
    required this.apkDownloadUrl,
  });

  final AppVersion currentVersion;
  final AppVersion latestVersion;
  final String releaseTag;
  final String releasePageUrl;
  final String? apkDownloadUrl;

  bool get updateAvailable => latestVersion.compareTo(currentVersion) > 0;

  String get preferredDownloadUrl => apkDownloadUrl ?? releasePageUrl;
}

class AppUpdateService {
  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<AppVersion> currentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return AppVersion.fromPackageInfo(packageInfo);
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    final current = await currentVersion();

    final response = await _dio.get<Object?>(
      _latestReleaseUrl,
      options: Options(
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
      ),
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('GitHub Release response is not an object');
    }

    final tag = data['tag_name']?.toString() ?? '';
    final latest = AppVersion.tryParseReleaseTag(tag);
    if (latest == null) {
      throw FormatException('Unsupported release tag: $tag');
    }

    final releasePageUrl = data['html_url']?.toString() ?? '';
    if (releasePageUrl.isEmpty) {
      throw const FormatException('GitHub Release is missing html_url');
    }

    String? apkDownloadUrl;
    final assets = data['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = asset['name']?.toString().toLowerCase() ?? '';
        final url = asset['browser_download_url']?.toString() ?? '';
        if (name.endsWith('.apk') && url.isNotEmpty) {
          apkDownloadUrl = url;
          break;
        }
      }
    }

    return UpdateCheckResult(
      currentVersion: current,
      latestVersion: latest,
      releaseTag: tag,
      releasePageUrl: releasePageUrl,
      apkDownloadUrl: apkDownloadUrl,
    );
  }
}
