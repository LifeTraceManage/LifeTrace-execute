import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/collection/execution_file_metadata.dart';
import '../local/app_database.dart' as db;

abstract final class FileMetadataDatabaseMapper {
  static db.FileRecord toRow(ExecutionFileMetadata file) => db.FileRecord(
        id: file.id,
        userId: file.userId,
        originalName: file.originalName,
        mimeType: file.mimeType,
        sizeBytes: file.sizeBytes,
        sha256: file.sha256,
        storageState: file.storageState.wireValue,
        createdByDevice: file.createdByDevice,
        createdAt: file.createdAt,
        updatedAt: file.updatedAt,
        localVersion: file.localVersion,
        serverVersion: file.serverVersion,
        modifiedByDevice: file.modifiedByDevice,
      );

  static ExecutionFileMetadata fromRow(db.FileRecord row) =>
      ExecutionFileMetadata(
        id: row.id,
        userId: row.userId,
        originalName: row.originalName,
        mimeType: row.mimeType,
        sizeBytes: row.sizeBytes,
        sha256: row.sha256,
        storageState: ExecutionFileStorageState.fromWire(row.storageState),
        createdByDevice: row.createdByDevice,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class FileMetadataWireMapper {
  static Map<String, dynamic> toPayload(ExecutionFileMetadata file) => {
        'meta': {
          'id': file.id,
          'userId': file.userId,
          'createdAt': file.createdAt,
          'updatedAt': file.updatedAt,
          'deletedAt': null,
          'localVersion': file.localVersion,
          'serverVersion': file.serverVersion,
          'modifiedByDevice': file.modifiedByDevice,
        },
        'originalName': file.originalName,
        'mimeType': file.mimeType,
        'sizeBytes': file.sizeBytes,
        'sha256': file.sha256,
        'storageState': file.storageState.wireValue,
        'createdByDevice': file.createdByDevice,
      };

  static ExecutionFileMetadata fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta']);
    return ExecutionFileMetadata(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      originalName: _requiredString(payload, 'originalName'),
      mimeType: _requiredString(payload, 'mimeType'),
      sizeBytes: _int(payload['sizeBytes']) ?? 0,
      sha256: _requiredString(payload, 'sha256'),
      storageState: ExecutionFileStorageState.fromWire(
        _requiredString(payload, 'storageState'),
      ),
      createdByDevice: _nullableString(payload['createdByDevice']),
      createdAt: _requiredString(meta, 'createdAt'),
      updatedAt: _requiredString(meta, 'updatedAt'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('FileMetadata meta must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) {
      throw FormatException('FileMetadata payload is missing $name');
    }
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class DriftFileMetadataRepository {
  DriftFileMetadataRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const entityType = 'file.metadata';

  final db.AppDatabase database;
  final Uuid _uuid;

  Stream<List<ExecutionFileMetadata>> watchFiles(String userId) {
    final query = database.select(database.fileRecords)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) => rows
              .map(FileMetadataDatabaseMapper.fromRow)
              .toList(growable: false),
        );
  }

  Future<void> writeLocalChange(ExecutionFileMetadata file) async {
    await database.transaction(() async {
      await database
          .into(database.fileRecords)
          .insertOnConflictUpdate(FileMetadataDatabaseMapper.toRow(file));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: file.userId,
              entityType: entityType,
              entityId: file.id,
              operation: 'upsert',
              baseServerVersion: file.serverVersion ?? '0',
              clientModifiedAt: file.updatedAt,
              payloadJson: Value(
                jsonEncode(FileMetadataWireMapper.toPayload(file)),
              ),
              createdAt: file.updatedAt,
            ),
          );
    });
  }
}
