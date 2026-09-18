import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/collection/entity_link.dart';
import '../local/app_database.dart' as db;

abstract final class EntityLinkDatabaseMapper {
  static db.EntityLink toRow(ExecutionEntityLink link) => db.EntityLink(
        id: link.id,
        userId: link.userId,
        sourceType: link.sourceType,
        sourceId: link.sourceId,
        targetType: link.targetType,
        targetId: link.targetId,
        relationType: link.relationType,
        metadataJson:
            link.metadata == null ? null : jsonEncode(link.metadata),
        createdAt: link.createdAt,
        updatedAt: link.updatedAt,
        localVersion: link.localVersion,
        serverVersion: link.serverVersion,
        modifiedByDevice: link.modifiedByDevice,
      );

  static ExecutionEntityLink fromRow(db.EntityLink row) => ExecutionEntityLink(
        id: row.id,
        userId: row.userId,
        sourceType: row.sourceType,
        sourceId: row.sourceId,
        targetType: row.targetType,
        targetId: row.targetId,
        relationType: row.relationType,
        metadata: _decodeMetadata(row.metadataJson),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );

  static Map<String, dynamic>? _decodeMetadata(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('EntityLink metadata must be a JSON object');
  }
}

abstract final class EntityLinkWireMapper {
  static Map<String, dynamic> toPayload(ExecutionEntityLink link) => {
        'meta': {
          'id': link.id,
          'userId': link.userId,
          'createdAt': link.createdAt,
          'updatedAt': link.updatedAt,
          'deletedAt': null,
          'localVersion': link.localVersion,
          'serverVersion': link.serverVersion,
          'modifiedByDevice': link.modifiedByDevice,
        },
        'source': {
          'entityType': link.sourceType,
          'entityId': link.sourceId,
        },
        'target': {
          'entityType': link.targetType,
          'entityId': link.targetId,
        },
        'relationType': link.relationType,
        'metadata': link.metadata,
      };

  static ExecutionEntityLink fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta'], 'meta');
    final source = _map(payload['source'], 'source');
    final target = _map(payload['target'], 'target');
    final metadataValue = payload['metadata'];
    return ExecutionEntityLink(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      sourceType: _requiredString(source, 'entityType'),
      sourceId: _requiredString(source, 'entityId'),
      targetType: _requiredString(target, 'entityType'),
      targetId: _requiredString(target, 'entityId'),
      relationType: _requiredString(payload, 'relationType'),
      metadata: metadataValue == null
          ? null
          : _map(metadataValue, 'metadata'),
      createdAt: _requiredString(meta, 'createdAt'),
      updatedAt: _requiredString(meta, 'updatedAt'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
  }

  static Map<String, dynamic> _map(Object? value, String name) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('EntityLink $name must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) {
      throw FormatException('EntityLink payload is missing $name');
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

class DriftEntityLinkRepository {
  DriftEntityLinkRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const entityType = 'entity.link';

  final db.AppDatabase database;
  final Uuid _uuid;

  Stream<List<ExecutionEntityLink>> watchLinksForEntity({
    required String userId,
    required String entityType,
    required String entityId,
  }) {
    final query = database.select(database.entityLinks)
      ..where(
        (table) =>
            table.userId.equals(userId) &
            ((table.sourceType.equals(entityType) &
                    table.sourceId.equals(entityId)) |
                (table.targetType.equals(entityType) &
                    table.targetId.equals(entityId))),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) => rows
              .map(EntityLinkDatabaseMapper.fromRow)
              .toList(growable: false),
        );
  }

  Future<ExecutionEntityLink> createLink({
    required String userId,
    required String deviceId,
    required String sourceType,
    required String sourceId,
    required String targetType,
    required String targetId,
    required String relationType,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final link = ExecutionEntityLink(
      id: _uuid.v4(),
      userId: userId,
      sourceType: sourceType,
      sourceId: sourceId,
      targetType: targetType,
      targetId: targetId,
      relationType: relationType,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    await writeLocalChange(link);
    return link;
  }

  Future<void> deleteLink({
    required String userId,
    required String linkId,
  }) async {
    final row = await (database.select(database.entityLinks)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.id.equals(linkId),
          ))
        .getSingleOrNull();
    if (row == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction(() async {
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: userId,
              entityType: entityType,
              entityId: linkId,
              operation: 'delete',
              baseServerVersion: row.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.entityLinks)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.id.equals(linkId),
            ))
          .go();
    });
  }

  Future<void> writeLocalChange(
    ExecutionEntityLink link, {
    String? createdAtOverride,
  }) async {
    final dependencies = jsonEncode([
      {'entityType': link.sourceType, 'entityId': link.sourceId},
      {'entityType': link.targetType, 'entityId': link.targetId},
    ]);
    await database.transaction(() async {
      await database
          .into(database.entityLinks)
          .insertOnConflictUpdate(EntityLinkDatabaseMapper.toRow(link));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: link.userId,
              entityType: entityType,
              entityId: link.id,
              operation: 'upsert',
              baseServerVersion: link.serverVersion ?? '0',
              clientModifiedAt: link.updatedAt,
              payloadJson: Value(
                jsonEncode(EntityLinkWireMapper.toPayload(link)),
              ),
              dependenciesJson: Value(dependencies),
              createdAt: createdAtOverride ?? link.updatedAt,
            ),
          );
    });
  }
}
