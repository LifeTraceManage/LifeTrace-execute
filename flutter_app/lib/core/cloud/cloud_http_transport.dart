import 'package:dio/dio.dart';

import 'cloud_contract.dart';

class CloudHttpTransport {
  CloudHttpTransport({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'LifeTrace-Execute-Flutter',
                },
              ),
            );

  final Dio _dio;

  Future<Map<String, dynamic>> requestJson({
    required String method,
    required String baseUrl,
    required String path,
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final origin = normalizeBaseUrl(baseUrl);
    try {
      final response = await _dio.request<Object?>(
        '$origin$path',
        data: body,
        options: Options(
          method: method,
          headers: {
            if (accessToken != null && accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
            if (body != null) 'Content-Type': 'application/json; charset=utf-8',
          },
        ),
      );
      final data = response.data;
      if (data == null || data == '') return <String, dynamic>{};
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const FormatException('LifeTrace Cloud 返回了非 JSON 对象');
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      final raw = error.response?.data;
      final json = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
      throw CloudApiException(
        statusCode: statusCode,
        code: json['code'] as String?,
        retryable: json['retryable'] == true || statusCode == 429 || statusCode >= 500,
        message: json['message'] as String? ??
            (statusCode == 0
                ? '无法连接 LifeTrace Cloud'
                : 'LifeTrace Cloud 请求失败（HTTP $statusCode）'),
      );
    }
  }

  String normalizeBaseUrl(String raw) {
    final value = raw.trim().replaceFirst(RegExp(r'/+$'), '');
    if (value.isEmpty) throw const FormatException('请输入 LifeTrace Cloud 地址');
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      throw const FormatException('LifeTrace Cloud 必须使用 HTTPS');
    }
    if (uri.host.isEmpty) throw const FormatException('Cloud 地址缺少有效主机名');
    if (uri.hasQuery || uri.hasFragment) {
      throw const FormatException('Cloud 地址不能包含 query 或 fragment');
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw const FormatException('Cloud 地址必须填写服务 origin，不要附加 API 路径');
    }
    return Uri(scheme: 'https', host: uri.host, port: uri.hasPort ? uri.port : null)
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
  }
}
