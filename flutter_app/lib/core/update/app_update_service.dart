import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    final semantic = _parseSemantic(info.version);
    return AppVersion(
      major: semantic.$1,
      minor: semantic.$2,
      patch: semantic.$3,
      build: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  static AppVersion? fromReleaseTag(String tag) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-build\.(\d+))?',
    ).firstMatch(tag.trim());
    if (match == null) return null;
    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.tryParse(match.group(4) ?? '') ?? 0,
    );
  }

  static (int, int, int) _parseSemantic(String value) {
    final core = value.split('+').first;
    final parts = core.split('.');
    return (
      int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0,
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
      final result = pair.$1.compareTo(pair.$2);
      if (result != 0) return result;
    }
    return 0;
  }

  String get label => '$major.$minor.$patch+$build';
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.tagName,
    required this.title,
    required this.body,
    required this.apkName,
    required this.apkUrl,
    required this.apkSize,
    required this.sha256,
    required this.sha256Url,
    required this.htmlUrl,
  });

  final AppVersion version;
  final String tagName;
  final String title;
  final String body;
  final String apkName;
  final String apkUrl;
  final int apkSize;
  final String? sha256;
  final String? sha256Url;
  final String htmlUrl;

  static AppUpdateRelease fromGitHubJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final version = AppVersion.fromReleaseTag(tagName);
    if (version == null) {
      throw const AppUpdateException('最新 Release 的版本号格式无法识别。');
    }

    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    Map<String, dynamic>? apk;
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apk = asset;
        break;
      }
    }
    if (apk == null) {
      throw const AppUpdateException('最新 Release 中没有可安装的 APK。');
    }

    final digest = apk['digest'] as String?;
    final sha256 = digest != null && digest.startsWith('sha256:')
        ? digest.substring('sha256:'.length).toLowerCase()
        : null;

    String? sha256Url;
    final expectedChecksumName =
        '${apk['name'] as String? ?? ''}.sha256'.toLowerCase();
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name == expectedChecksumName) {
        sha256Url = asset['browser_download_url'] as String?;
        break;
      }
    }

    return AppUpdateRelease(
      version: version,
      tagName: tagName,
      title: json['name'] as String? ?? tagName,
      body: json['body'] as String? ?? '',
      apkName: apk['name'] as String? ?? 'LifeTrace-Execute.apk',
      apkUrl: apk['browser_download_url'] as String? ?? '',
      apkSize: (apk['size'] as num?)?.toInt() ?? 0,
      sha256: sha256,
      sha256Url: sha256Url,
      htmlUrl: json['html_url'] as String? ?? '',
    );
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.current,
    required this.latest,
  });

  final AppVersion current;
  final AppUpdateRelease latest;

  bool get updateAvailable => latest.version.compareTo(current) > 0;
}

enum ApkInstallResult {
  launched,
  permissionRequired,
  signatureMismatch,
}

class AppUpdateService {
  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  static const _latestReleaseUrl =
      'https://api.github.com/repos/LifeTraceManage/LifeTrace-execute/releases/latest';
  static const _channel =
      MethodChannel('com.lifetrace.execute/app_update');

  final Dio _dio;

  Future<AppUpdateCheckResult> checkForUpdate(PackageInfo currentPackage) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const AppUpdateException('应用内更新仅支持 Android 正式客户端。');
    }

    try {
      final response = await _dio.get<dynamic>(
        _latestReleaseUrl,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent':
                'LifeTrace-Execute/${currentPackage.version}+${currentPackage.buildNumber}',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AppUpdateException('GitHub Release 返回了无法识别的数据。');
      }
      return AppUpdateCheckResult(
        current: AppVersion.fromPackageInfo(currentPackage),
        latest: AppUpdateRelease.fromGitHubJson(data),
      );
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      if (code == 403) {
        throw const AppUpdateException('GitHub API 暂时限制访问，请稍后手动重试。');
      }
      throw AppUpdateException(
        '检查更新失败：${error.message ?? '网络请求失败'}',
      );
    }
  }

  Future<File> downloadRelease(
    AppUpdateRelease release, {
    ValueChanged<double>? onProgress,
  }) async {
    if (release.apkUrl.isEmpty) {
      throw const AppUpdateException('Release APK 下载地址为空。');
    }

    final temp = await getTemporaryDirectory();
    final directory = Directory(p.join(temp.path, 'updates'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final expectedSha256 = await _resolveExpectedSha256(release);
    final target = File(p.join(directory.path, release.apkName));
    if (await target.exists() && await _verify(target, expectedSha256)) {
      onProgress?.call(1);
      return target;
    }

    if (await target.exists()) {
      await target.delete();
    }

    try {
      await _dio.download(
        release.apkUrl,
        target.path,
        options: Options(
          headers: {
            'Accept': 'application/octet-stream',
            'User-Agent': 'LifeTrace-Execute-Updater',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );
    } on DioException catch (error) {
      if (await target.exists()) {
        await target.delete();
      }
      throw AppUpdateException(
        '下载更新失败：${error.message ?? '网络请求失败'}',
      );
    }

    if (!await _verify(target, expectedSha256)) {
      await target.delete();
      throw const AppUpdateException('APK SHA-256 校验失败，已删除下载文件。');
    }
    onProgress?.call(1);
    return target;
  }

  Future<ApkInstallResult> install(File apk) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const AppUpdateException('APK 安装仅支持 Android。');
    }

    try {
      final result = await _channel.invokeMethod<String>(
        'installApk',
        {'path': apk.path},
      );
      return switch (result) {
        'launched' => ApkInstallResult.launched,
        'permission_required' => ApkInstallResult.permissionRequired,
        'signature_mismatch' => ApkInstallResult.signatureMismatch,
        _ => throw AppUpdateException('系统安装器返回未知状态：$result'),
      };
    } on PlatformException catch (error) {
      throw AppUpdateException(
        '无法启动系统安装器：${error.message ?? error.code}',
      );
    }
  }

  Future<String> _resolveExpectedSha256(AppUpdateRelease release) async {
    final direct = release.sha256?.trim().toLowerCase();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final checksumUrl = release.sha256Url;
    if (checksumUrl == null || checksumUrl.isEmpty) {
      throw const AppUpdateException(
        'Release 没有提供 APK SHA-256，已拒绝下载未校验的更新。',
      );
    }

    try {
      final response = await _dio.get<String>(
        checksumUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'text/plain',
            'User-Agent': 'LifeTrace-Execute-Updater',
          },
        ),
      );
      final value = response.data?.trim().split(RegExp(r'\\s+')).first ?? '';
      if (!RegExp(r'^[0-9a-fA-F]{64}
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
).hasMatch(value)) {
        throw const AppUpdateException('Release SHA-256 文件格式无效。');
      }
      return value.toLowerCase();
    } on DioException catch (error) {
      throw AppUpdateException(
        '读取 APK SHA-256 失败：${error.message ?? '网络请求失败'}',
      );
    }
  }

  Future<bool> _verify(File file, String expectedSha256) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == expectedSha256.toLowerCase();
  }
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
