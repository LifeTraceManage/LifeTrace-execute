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
    required this.protocolVersion,
    required this.schemaVersion,
    this.refreshToken,
    this.displayName,
  });

  final String baseUrl;
  final String accessToken;
  final String? refreshToken;
  final int accessTokenExpiresAtEpochSeconds;
  final String userId;
  final String email;
  final String? displayName;
  final String sessionId;
  final List<String> scopes;
  final int protocolVersion;
  final int schemaVersion;

  StoredCloudSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? accessTokenExpiresAtEpochSeconds,
    String? userId,
    String? email,
    String? displayName,
    String? sessionId,
    List<String>? scopes,
  }) =>
      StoredCloudSession(
        baseUrl: baseUrl,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        accessTokenExpiresAtEpochSeconds:
            accessTokenExpiresAtEpochSeconds ?? this.accessTokenExpiresAtEpochSeconds,
        userId: userId ?? this.userId,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        sessionId: sessionId ?? this.sessionId,
        scopes: scopes ?? this.scopes,
        protocolVersion: protocolVersion,
        schemaVersion: schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessTokenExpiresAtEpochSeconds': accessTokenExpiresAtEpochSeconds,
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'sessionId': sessionId,
        'scopes': scopes,
        'protocolVersion': protocolVersion,
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
        displayName: json['displayName'] as String?,
        sessionId: json['sessionId'] as String,
        scopes: (json['scopes'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        protocolVersion: (json['protocolVersion'] as num).toInt(),
        schemaVersion: (json['schemaVersion'] as num).toInt(),
      );
}

abstract interface class CloudSessionStore {
  Future<void> save(StoredCloudSession session);
  Future<StoredCloudSession?> load();
  Future<void> clear();
}

class SecureSessionStore implements CloudSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'lifetrace_execute_cloud_session_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<void> save(StoredCloudSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
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

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
