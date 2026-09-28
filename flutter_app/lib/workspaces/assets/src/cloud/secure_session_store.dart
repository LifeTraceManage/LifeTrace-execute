import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredCloudSession {
  const StoredCloudSession({
    required this.baseUrl,
    required this.accessToken,
    required this.accessTokenExpiresAtEpochSeconds,
    required this.userId,
    required this.email,
    required this.sessionId,
    required this.scopes,
    required this.schemaVersion,
    this.refreshToken,
  });

  final String baseUrl;
  final String accessToken;
  final String? refreshToken;
  final int accessTokenExpiresAtEpochSeconds;
  final String userId;
  final String email;
  final String sessionId;
  final List<String> scopes;
  final int schemaVersion;

  StoredCloudSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? accessTokenExpiresAtEpochSeconds,
    String? userId,
    String? email,
    String? sessionId,
    List<String>? scopes,
  }) => StoredCloudSession(
        baseUrl: baseUrl,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        accessTokenExpiresAtEpochSeconds:
            accessTokenExpiresAtEpochSeconds ?? this.accessTokenExpiresAtEpochSeconds,
        userId: userId ?? this.userId,
        email: email ?? this.email,
        sessionId: sessionId ?? this.sessionId,
        scopes: scopes ?? this.scopes,
        schemaVersion: schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessTokenExpiresAtEpochSeconds': accessTokenExpiresAtEpochSeconds,
        'userId': userId,
        'email': email,
        'sessionId': sessionId,
        'scopes': scopes,
        'schemaVersion': schemaVersion,
      };

  factory StoredCloudSession.fromJson(Map<String, dynamic> json) =>
      StoredCloudSession(
        baseUrl: json['baseUrl'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        accessTokenExpiresAtEpochSeconds:
            (json['accessTokenExpiresAtEpochSeconds'] as num).toInt(),
        userId: json['userId'] as String,
        email: json['email'] as String,
        sessionId: json['sessionId'] as String,
        scopes: (json['scopes'] as List<dynamic>? ?? const [])
            .whereType<String>().toList(growable: false),
        schemaVersion: (json['schemaVersion'] as num).toInt(),
      );
}

class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  static const _key = 'lifetrace_assets_cloud_session_v1';
  final FlutterSecureStorage _storage;

  Future<void> save(StoredCloudSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  Future<StoredCloudSession?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return StoredCloudSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _key);
}
