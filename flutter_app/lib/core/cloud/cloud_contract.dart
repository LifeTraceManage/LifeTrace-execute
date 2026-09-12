class CloudContract {
  const CloudContract._();

  static const appId = 'lifetrace-execute-android';
  static const platform = 'android';
  static const protocolVersion = 1;
  static const schemaVersion = 1;

  static const requestedScopes = <String>[
    'account:read',
    'account:write',
    'devices:read',
    'devices:write',
    'sync:read',
    'sync:write',
    'execution:read',
    'execution:write',
    'habits:read',
    'habits:write',
    'reviews:read',
    'reviews:write',
    'files:read',
    'files:write',
  ];

  static const requiredSyncEntityTypes = <String>{
    'execution.task',
    'execution.project',
    'execution.calendar_event',
    'execution.important_date',
    'execution.focus_session',
    'execution.memo',
    'execution.reminder',
    'review.daily',
    'file.metadata',
    'entity.link',
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
    this.refreshExpiresInSeconds,
  });

  final String accessToken;
  final String? refreshToken;
  final int expiresInSeconds;
  final int? refreshExpiresInSeconds;
  final CloudUser user;
  final String sessionId;
  final List<String> scopes;

  factory CloudAuthResult.fromJson(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>;
    return CloudAuthResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresInSeconds: (json['expiresIn'] as num?)?.toInt() ?? 0,
      refreshExpiresInSeconds: (json['refreshExpiresIn'] as num?)?.toInt(),
      user: CloudUser.fromJson(json['user'] as Map<String, dynamic>),
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
