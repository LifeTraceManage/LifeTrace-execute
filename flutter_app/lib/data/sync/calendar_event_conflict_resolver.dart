import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart' as db;
import '../repository/calendar_event_database_mapper.dart';
import '../repository/calendar_event_repository.dart';
import '../repository/calendar_event_wire_mapper.dart';

class CalendarEventConflictResolver {
  CalendarEventConflictResolver(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<void> keepServer(String conflictId) async {
    await database.transaction(() async {
      final conflict = await (database.select(database.syncConflicts)
            ..where((table) => table.id.equals(conflictId)))
          .getSingleOrNull();
      if (conflict == null) return;
      if (conflict.entityType != DriftCalendarEventRepository.entityType) {
        throw StateError('仅支持处理日程冲突');
      }

      await _deleteOutbox(conflict.userId, conflict.entityId);
      if (conflict.serverDeleted) {
        await _deleteEvent(conflict.userId, conflict.entityId);
      } else {
        final payloadJson = conflict.serverPayloadJson;
        final serverVersion = conflict.serverVersion;
        if (payloadJson == null || serverVersion == null) {
          throw StateError('服务器冲突结果缺少日程内容');
        }
        final event = CalendarEventWireMapper.fromPayload(
          _decodeObject(payloadJson),
          serverVersion: serverVersion,
        );
        await database
            .into(database.calendarEvents)
            .insertOnConflictUpdate(CalendarEventDatabaseMapper.toRow(event));
      }
      await _deleteConflicts(conflict.userId, conflict.entityId);
    });
  }

  Future<void> keepLocal({
    required String conflictId,
    required String deviceId,
  }) async {
    await database.transaction(() async {
      final conflict = await (database.select(database.syncConflicts)
            ..where((table) => table.id.equals(conflictId)))
          .getSingleOrNull();
      if (conflict == null) return;
      if (conflict.entityType != DriftCalendarEventRepository.entityType) {
        throw StateError('仅支持处理日程冲突');
      }

      final queued = await (database.select(database.syncOutbox)
            ..where(
              (table) =>
                  table.userId.equals(conflict.userId) &
                  table.entityType.equals(conflict.entityType) &
                  table.entityId.equals(conflict.entityId),
            )
            ..orderBy([
              (table) => OrderingTerm.asc(table.createdAt),
              (table) => OrderingTerm.asc(table.changeId),
            ])
            ..limit(1))
          .getSingleOrNull();
      if (queued == null) throw StateError('冲突缺少对应的本地待同步变更');

      final serverVersion = conflict.serverVersion;
      if (serverVersion == null || serverVersion.isEmpty) {
        throw StateError('冲突缺少最新云端版本号');
      }
      final row = await (database.select(database.calendarEvents)
            ..where(
              (table) =>
                  table.userId.equals(conflict.userId) &
                  table.id.equals(conflict.entityId),
            ))
          .getSingleOrNull();
      final now = DateTime.now().toUtc().toIso8601String();

      await _deleteOutbox(conflict.userId, conflict.entityId);
      switch (queued.operation) {
        case 'upsert':
          if (row == null) throw StateError('本地日程已不存在，无法保留本地版本');
          final local = CalendarEventDatabaseMapper.fromRow(row);
          final rebased = local.copyWith(
            updatedAt: now,
            localVersion: local.localVersion + 1,
            serverVersion: serverVersion,
            modifiedByDevice: deviceId,
          );
          await database
              .into(database.calendarEvents)
              .insertOnConflictUpdate(CalendarEventDatabaseMapper.toRow(rebased));
          await database.into(database.syncOutbox).insert(
                db.SyncOutboxCompanion.insert(
                  changeId: _uuid.v4(),
                  userId: conflict.userId,
                  entityType: conflict.entityType,
                  entityId: conflict.entityId,
                  operation: 'upsert',
                  baseServerVersion: serverVersion,
                  entitySchemaVersion: Value(queued.entitySchemaVersion),
                  clientModifiedAt: now,
                  payloadJson: Value(
                    jsonEncode(CalendarEventWireMapper.toPayload(rebased)),
                  ),
                  createdAt: now,
                ),
              );
        case 'delete':
          await _deleteEvent(conflict.userId, conflict.entityId);
          await database.into(database.syncOutbox).insert(
                db.SyncOutboxCompanion.insert(
                  changeId: _uuid.v4(),
                  userId: conflict.userId,
                  entityType: conflict.entityType,
                  entityId: conflict.entityId,
                  operation: 'delete',
                  baseServerVersion: serverVersion,
                  entitySchemaVersion: Value(queued.entitySchemaVersion),
                  clientModifiedAt: now,
                  createdAt: now,
                ),
              );
        default:
          throw StateError('不支持的日程冲突变更类型：${queued.operation}');
      }
      await _deleteConflicts(conflict.userId, conflict.entityId);
    });
  }

  Future<void> _deleteOutbox(String userId, String eventId) =>
      (database.delete(database.syncOutbox)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.entityType.equals(
                    DriftCalendarEventRepository.entityType,
                  ) &
                  table.entityId.equals(eventId),
            ))
          .go();

  Future<void> _deleteConflicts(String userId, String eventId) =>
      (database.delete(database.syncConflicts)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.entityType.equals(
                    DriftCalendarEventRepository.entityType,
                  ) &
                  table.entityId.equals(eventId),
            ))
          .go();

  Future<void> _deleteEvent(String userId, String eventId) =>
      (database.delete(database.calendarEvents)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.id.equals(eventId),
            ))
          .go();

  static Map<String, dynamic> _decodeObject(String raw) {
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Calendar conflict payload must be an object');
  }
}
