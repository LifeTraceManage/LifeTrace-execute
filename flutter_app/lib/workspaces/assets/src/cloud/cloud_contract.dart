import 'package:flutter/foundation.dart';

class CloudContract {
  const CloudContract._();

  static const appId = 'lifetrace-assets';
  static String get platform => kIsWeb ? 'web' : 'android';
  static const protocolVersion = 1;
  static const schemaVersion = 1;
  static const clientVersion = '0.2.0';

  static const requestedScopes = <String>[
    'account:read',
    'devices:read',
    'sync:read',
    'sync:write',
    'assets:read',
    'assets:write',
    'links:read',
    'links:write',
  ];

  static const coreSyncEntityTypes = <String>{
    'asset.asset',
    'asset.event',
  };

  static const requiredSyncEntityTypes = <String>{
    ...coreSyncEntityTypes,
    'entity.link',
  };

  static Set<String> readableSyncEntityTypes(Iterable<String> scopes) => {
        ...coreSyncEntityTypes,
        if (scopes.contains('links:read')) 'entity.link',
      };

  static Set<String> writableSyncEntityTypes(Iterable<String> scopes) => {
        ...coreSyncEntityTypes,
        if (scopes.contains('links:write')) 'entity.link',
      };
}

class CloudUser {
  const CloudUser({required this.id, required this.email, this.displayName});
  final String id;
  final String email;
  final String? displayName;

  factory CloudUser.fromJson(Map<String, dynamic> json) => CloudUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
      );
}

class CloudAuthResult {
  const CloudAuthResult({
    required this.accessToken,
    required this.expiresInSeconds,
    required this.user,
    required this.sessionId,
    required this.scopes,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final int expiresInSeconds;
  final CloudUser user;
  final String sessionId;
  final List<String> scopes;

  factory CloudAuthResult.fromJson(Map<String, dynamic> json) {
    final session = Map<String, dynamic>.from(json['session'] as Map);
    return CloudAuthResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresInSeconds: (json['expiresIn'] as num?)?.toInt() ?? 0,
      user: CloudUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
      sessionId: session['id'] as String,
      scopes: (json['scopes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class CloudApiException implements Exception {
  const CloudApiException({
    required this.statusCode,
    required this.retryable,
    required this.message,
    this.code,
  });

  final int statusCode;
  final String? code;
  final bool retryable;
  final String message;

  bool get isExpiredAccessToken =>
      code == 'LIFETRACE_AUTH_ACCESS_TOKEN_EXPIRED';

  @override
  String toString() => message;
}
