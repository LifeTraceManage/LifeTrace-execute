import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/reminder/execution_reminder.dart';
import '../local/app_database.dart' as db;

abstract final class ReminderSubjectTypes {
  static const task = 'task';
  static const calendarEvent = 'calendar_event';
  static const importantDate = 'important_date';
  static const focusSession = 'focus_session';

  static String entityType(String subjectType) => switch (subjectType) {
        task => 'execution.task',
        calendarEvent => 'execution.calendar_event',
        importantDate => 'execution.important_date',
        focusSession => 'execution.focus_session',
        _ => throw ArgumentError.value(
            subjectType,
            'subjectType',
            '不支持的 Reminder subjectType',
          ),
      };
}

abstract final class ReminderDatabaseMapper {
  static db.Reminder toRow(ExecutionReminder reminder) => db.Reminder(
        id: reminder.id,
        userId: reminder.userId,
        subjectType: reminder.subjectType,
        subjectId: reminder.subjectId,
        triggerAt: reminder.triggerAt,
        status: reminder.status.wireValue,
        fireKey: reminder.fireKey,
        snoozedUntil: reminder.snoozedUntil,
        lastFiredAt: reminder.lastFiredAt,
        title: reminder.title,
        body: reminder.body,
        createdAt: reminder.createdAt,
        updatedAt: reminder.updatedAt,
        localVersion: reminder.localVersion,
        serverVersion: reminder.serverVersion,
        modifiedByDevice: reminder.modifiedByDevice,
      );

  static ExecutionReminder fromRow(db.Reminder row) => ExecutionReminder(
        id: row.id,
        userId: row.userId,
        subjectType: row.subjectType,
        subjectId: row.subjectId,
        triggerAt: row.triggerAt,
        status: ExecutionReminderStatus.fromWire(row.status),
        fireKey: row.fireKey,
        snoozedUntil: row.snoozedUntil,
        lastFiredAt: row.lastFiredAt,
        title: row.title,
        body: row.body,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class ReminderWireMapper {
  static Map<String, dynamic> toPayload(ExecutionReminder reminder) => {
        'meta': {
          'id': reminder.id,
          'userId': reminder.userId,
          'createdAt': reminder.createdAt,
          'updatedAt': reminder.updatedAt,
          'deletedAt': null,
          'localVersion': reminder.localVersion,
          'serverVersion': reminder.serverVersion,
          'modifiedByDevice': reminder.modifiedByDevice,
        },
        'subjectType': reminder.subjectType,
        'subjectId': reminder.subjectId,
        'triggerAt': reminder.triggerAt,
        'status': reminder.status.wireValue,
        'fireKey': reminder.fireKey,
        'snoozedUntil': reminder.snoozedUntil,
        'lastFiredAt': reminder.lastFiredAt,
        'title': reminder.title,
        'body': reminder.body,
      };

  static ExecutionReminder fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta'], 'meta');
    final triggerAt = _requiredString(payload, 'triggerAt');
    if (DateTime.tryParse(triggerAt) == null) {
      throw const FormatException('Reminder triggerAt must be RFC3339');
    }
    return ExecutionReminder(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      subjectType: _requiredString(payload, 'subjectType'),
      subjectId: _requiredString(payload, 'subjectId'),
      triggerAt: triggerAt,
      status: ExecutionReminderStatus.fromWire(
        _requiredString(payload, 'status'),
      ),
      fireKey: _requiredString(payload, 'fireKey'),
      snoozedUntil: _nullableString(payload['snoozedUntil']),
      lastFiredAt: _nullableString(payload['lastFiredAt']),
      title: _nullableString(payload['title']),
      body: _nullableString(payload['body']),
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
    throw FormatException('Reminder $name must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) throw FormatException('Reminder payload missing $name');
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final clean = value.toString().trim();
    return clean.isEmpty ? null : clean;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

abstract interface class ReminderRepository {
  Stream<List<ExecutionReminder>> watchReminders(String userId);
  Future<List<ExecutionReminder>> listReminders(String userId);
  Future<List<ExecutionReminder>> listForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  });

  Stream<List<ExecutionReminder>> watchForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  });

  Future<ExecutionReminder?> findActiveForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  });

  Future<ExecutionReminder> schedule({
    required String userId,
    required String deviceId,
    required String subjectType,
    required String subjectId,
    required String triggerAt,
    String? title,
    String? body,
  });

  Future<ExecutionReminder> cancel({
    required ExecutionReminder reminder,
    required String deviceId,
  });

  Future<void> delete({
    required String userId,
    required String reminderId,
  });
}

class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const entityType = 'execution.reminder';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<ExecutionReminder>> watchReminders(String userId) {
    final query = database.select(database.reminders)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) =>
              rows.map(ReminderDatabaseMapper.fromRow).toList(growable: false),
        );
  }

  @override
  Future<List<ExecutionReminder>> listReminders(String userId) async {
    final query = database.select(database.reminders)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return (await query.get())
        .map(ReminderDatabaseMapper.fromRow)
        .toList(growable: false);
  }

  @override
  Future<List<ExecutionReminder>> listForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  }) async {
    final query = database.select(database.reminders)
      ..where(
        (table) =>
            table.userId.equals(userId) &
            table.subjectType.equals(subjectType) &
            table.subjectId.equals(subjectId),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return (await query.get())
        .map(ReminderDatabaseMapper.fromRow)
        .toList(growable: false);
  }

  @override
  Future<List<ExecutionReminder>> listForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  }) async =>
      _items
          .where(
            (item) =>
                item.userId == userId &&
                item.subjectType == subjectType &&
                item.subjectId == subjectId,
          )
          .toList(growable: false);

  @override
  Stream<List<ExecutionReminder>> watchForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  }) {
    final query = database.select(database.reminders)
      ..where(
        (table) =>
            table.userId.equals(userId) &
            table.subjectType.equals(subjectType) &
            table.subjectId.equals(subjectId),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) =>
              rows.map(ReminderDatabaseMapper.fromRow).toList(growable: false),
        );
  }

  @override
  Future<ExecutionReminder?> findActiveForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  }) async {
    final rows = await (database.select(database.reminders)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.subjectType.equals(subjectType) &
                table.subjectId.equals(subjectId) &
                table.status.equals(ExecutionReminderStatus.scheduled.wireValue),
          )
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : ReminderDatabaseMapper.fromRow(rows.first);
  }

  @override
  Future<ExecutionReminder> schedule({
    required String userId,
    required String deviceId,
    required String subjectType,
    required String subjectId,
    required String triggerAt,
    String? title,
    String? body,
  }) async {
    final trigger = DateTime.tryParse(triggerAt);
    if (trigger == null) {
      throw ArgumentError.value(triggerAt, 'triggerAt', '提醒时间必须是 RFC3339');
    }
    if (!trigger.isAfter(DateTime.now().toUtc())) {
      throw ArgumentError.value(triggerAt, 'triggerAt', '提醒时间必须晚于当前时间');
    }
    ReminderSubjectTypes.entityType(subjectType);

    final existing = await findActiveForSubject(
      userId: userId,
      subjectType: subjectType,
      subjectId: subjectId,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final normalizedTrigger = trigger.toUtc().toIso8601String();
    final reminder = ExecutionReminder(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      subjectType: subjectType,
      subjectId: subjectId,
      triggerAt: normalizedTrigger,
      status: ExecutionReminderStatus.scheduled,
      fireKey: '$subjectId@$normalizedTrigger',
      title: _clean(title),
      body: _clean(body),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      localVersion: (existing?.localVersion ?? 0) + 1,
      serverVersion: existing?.serverVersion,
      modifiedByDevice: deviceId,
    );
    await writeLocalChange(reminder);
    return reminder;
  }

  @override
  Future<ExecutionReminder> cancel({
    required ExecutionReminder reminder,
    required String deviceId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final cancelled = reminder.copyWith(
      status: ExecutionReminderStatus.cancelled,
      updatedAt: now,
      localVersion: reminder.localVersion + 1,
      modifiedByDevice: deviceId,
      clearSnoozedUntil: true,
    );
    await writeLocalChange(cancelled);
    return cancelled;
  }

  @override
  Future<void> delete({
    required String userId,
    required String reminderId,
  }) async {
    final existing = await (database.select(database.reminders)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.id.equals(reminderId),
          ))
        .getSingleOrNull();
    if (existing == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction(() async {
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: userId,
              entityType: entityType,
              entityId: reminderId,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.reminders)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.id.equals(reminderId),
            ))
          .go();
    });
  }

  Future<void> writeLocalChange(ExecutionReminder reminder) async {
    final dependencyType =
        ReminderSubjectTypes.entityType(reminder.subjectType);
    await database.transaction(() async {
      await database
          .into(database.reminders)
          .insertOnConflictUpdate(ReminderDatabaseMapper.toRow(reminder));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: reminder.userId,
              entityType: entityType,
              entityId: reminder.id,
              operation: 'upsert',
              baseServerVersion: reminder.serverVersion ?? '0',
              clientModifiedAt: reminder.updatedAt,
              payloadJson: Value(
                jsonEncode(ReminderWireMapper.toPayload(reminder)),
              ),
              dependenciesJson: Value(
                jsonEncode([
                  {
                    'entityType': dependencyType,
                    'entityId': reminder.subjectId,
                  },
                ]),
              ),
              createdAt: reminder.updatedAt,
            ),
          );
    });
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

class PreviewReminderRepository implements ReminderRepository {
  final List<ExecutionReminder> _items = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<ExecutionReminder>> watchReminders(String userId) async* {
    List<ExecutionReminder> snapshot() =>
        _items.where((item) => item.userId == userId).toList(growable: false);
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<List<ExecutionReminder>> listReminders(String userId) async =>
      _items.where((item) => item.userId == userId).toList(growable: false);

  @override
  Stream<List<ExecutionReminder>> watchForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  }) async* {
    List<ExecutionReminder> snapshot() => _items
        .where(
          (item) =>
              item.userId == userId &&
              item.subjectType == subjectType &&
              item.subjectId == subjectId,
        )
        .toList(growable: false);
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<ExecutionReminder?> findActiveForSubject({
    required String userId,
    required String subjectType,
    required String subjectId,
  }) async {
    for (final item in _items.reversed) {
      if (item.userId == userId &&
          item.subjectType == subjectType &&
          item.subjectId == subjectId &&
          item.isScheduled) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<ExecutionReminder> schedule({
    required String userId,
    required String deviceId,
    required String subjectType,
    required String subjectId,
    required String triggerAt,
    String? title,
    String? body,
  }) async {
    final existing = await findActiveForSubject(
      userId: userId,
      subjectType: subjectType,
      subjectId: subjectId,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final normalized = DateTime.parse(triggerAt).toUtc().toIso8601String();
    final reminder = ExecutionReminder(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      subjectType: subjectType,
      subjectId: subjectId,
      triggerAt: normalized,
      status: ExecutionReminderStatus.scheduled,
      fireKey: '$subjectId@$normalized',
      title: DriftReminderRepository._clean(title),
      body: DriftReminderRepository._clean(body),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      localVersion: (existing?.localVersion ?? 0) + 1,
      modifiedByDevice: deviceId,
    );
    _items.removeWhere((item) => item.id == reminder.id);
    _items.add(reminder);
    _changes.add(null);
    return reminder;
  }

  @override
  Future<ExecutionReminder> cancel({
    required ExecutionReminder reminder,
    required String deviceId,
  }) async {
    final updated = reminder.copyWith(
      status: ExecutionReminderStatus.cancelled,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      localVersion: reminder.localVersion + 1,
      modifiedByDevice: deviceId,
    );
    _items.removeWhere((item) => item.id == reminder.id);
    _items.add(updated);
    _changes.add(null);
    return updated;
  }

  @override
  Future<void> delete({
    required String userId,
    required String reminderId,
  }) async {
    _items.removeWhere(
      (item) => item.userId == userId && item.id == reminderId,
    );
    _changes.add(null);
  }
}
