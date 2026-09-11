import 'package:dio/dio.dart';

import 'cloud_contract.dart';
import 'cloud_http_transport.dart';

class CloudFileObject {
  const CloudFileObject({
    required this.id,
    required this.domain,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.status,
    this.entityType,
    this.entityId,
  });

  final String id;
  final String domain;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final String status;
  final String? entityType;
  final String? entityId;

  factory CloudFileObject.fromJson(Map<String, dynamic> json) =>
      CloudFileObject(
        id: json['id'] as String,
        domain: json['domain'] as String? ?? '',
        originalName: json['originalName'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String? ?? '',
        status: json['status'] as String? ?? '',
        entityType: json['entityType'] as String?,
        entityId: json['entityId'] as String?,
      );
}

class SignedFileTransfer {
  const SignedFileTransfer({
    required this.url,
    required this.requiredHeaders,
    required this.expiresSeconds,
  });

  final String url;
  final Map<String, String> requiredHeaders;
  final int expiresSeconds;

  factory SignedFileTransfer.fromJson(Map<String, dynamic> json) =>
      SignedFileTransfer(
        url: json['url'] as String,
        requiredHeaders: (json['requiredHeaders'] as Map? ?? const {})
            .map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
        expiresSeconds: (json['expiresSeconds'] as num?)?.toInt() ?? 0,
      );
}

class PreparedCloudFile {
  const PreparedCloudFile({
    required this.file,
    required this.deduplicated,
    this.upload,
  });

  final CloudFileObject file;
  final bool deduplicated;
  final SignedFileTransfer? upload;
}

abstract interface class FilesClient {
  Future<PreparedCloudFile> prepare({
    required String baseUrl,
    required String accessToken,
    required String originalName,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    required String entityType,
    required String entityId,
  });

  Future<void> upload({
    required SignedFileTransfer transfer,
    required Stream<List<int>> bytes,
    required int sizeBytes,
  });

  Future<CloudFileObject> complete({
    required String baseUrl,
    required String accessToken,
    required String fileId,
  });

  Future<void> markFailed({
    required String baseUrl,
    required String accessToken,
    required String fileId,
    required String reason,
  });
}

class LifeTraceFilesClient implements FilesClient {
  LifeTraceFilesClient({
    CloudHttpTransport? transport,
    Dio? uploadDio,
  })  : _transport = transport ?? CloudHttpTransport(),
        _uploadDio = uploadDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(minutes: 5),
                receiveTimeout: const Duration(minutes: 2),
              ),
            );

  final CloudHttpTransport _transport;
  final Dio _uploadDio;

  @override
  Future<PreparedCloudFile> prepare({
    required String baseUrl,
    required String accessToken,
    required String originalName,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    required String entityType,
    required String entityId,
  }) async {
    final json = await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/files',
      accessToken: accessToken,
      body: {
        'domain': 'notes_attachments',
        'originalName': originalName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'entityType': entityType,
        'entityId': entityId,
      },
    );
    final fileRaw = json['file'];
    if (fileRaw is! Map) {
      throw const FormatException('文件 prepare 响应缺少 file');
    }
    final uploadRaw = json['upload'];
    return PreparedCloudFile(
      file: CloudFileObject.fromJson(
        Map<String, dynamic>.from(fileRaw),
      ),
      deduplicated: json['deduplicated'] == true,
      upload: uploadRaw is Map
          ? SignedFileTransfer.fromJson(
              Map<String, dynamic>.from(uploadRaw),
            )
          : null,
    );
  }

  @override
  Future<void> upload({
    required SignedFileTransfer transfer,
    required Stream<List<int>> bytes,
    required int sizeBytes,
  }) async {
    try {
      await _uploadDio.put<Object?>(
        transfer.url,
        data: bytes,
        options: Options(
          headers: {
            ...transfer.requiredHeaders,
            Headers.contentLengthHeader: sizeBytes,
          },
          responseType: ResponseType.plain,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode ?? 0;
      throw CloudApiException(
        statusCode: status,
        code: 'FILE_OBJECT_UPLOAD_FAILED',
        retryable: status == 0 || status == 429 || status >= 500,
        message: status == 0
            ? '无法连接对象存储'
            : '文件上传失败（HTTP $status）',
      );
    }
  }

  @override
  Future<CloudFileObject> complete({
    required String baseUrl,
    required String accessToken,
    required String fileId,
  }) async {
    final json = await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/files/$fileId/complete',
      accessToken: accessToken,
    );
    return CloudFileObject.fromJson(json);
  }

  @override
  Future<void> markFailed({
    required String baseUrl,
    required String accessToken,
    required String fileId,
    required String reason,
  }) async {
    await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/files/$fileId/fail',
      accessToken: accessToken,
      body: {'reason': reason},
    );
  }
}
