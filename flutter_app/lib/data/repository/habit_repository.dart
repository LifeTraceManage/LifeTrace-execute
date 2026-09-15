import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/habit/habit.dart';
import '../local/app_database.dart' as db;

abstract final class HabitActivityDatabaseMapper {
  static db.HabitActivity toRow(HabitActivity activity) => db.HabitActivity(
        id: activity.id,
        userId: activity.userId,
        name: activity.name,
        activityType: activity.activityType,
        unit: activity.unit,
        minimumTarget: activity.minimumTarget,
        normalTarget: activity.normalTarget,
        targetPeriod: activity.targetPeriod,
        targetDaysJson: jsonEncode(activity.targetDays),
        icon: activity.icon,
        color: activity.color,
        scheduleType: activity.scheduleType,
        startDate: activity.startDate,
        checkinMethod: activity.checkinMethod,
        syncSource: activity.syncSource,
        description: activity.description,
        isArchived: activity.isArchived,
        createdAt: activity.createdAt,
        updatedAt: activity.updatedAt,
        localVersion: activity.localVersion,
        serverVersion: activity.serverVersion,
        modifiedByDevice: activity.modifiedByDevice,
      );

  static HabitActivity fromRow(db.HabitActivity row) => HabitActivity(
        id: row.id,
        userId: row.userId,
        name: row.name,
        activityType: row.activityType,
        unit: row.unit,
        minimumTarget: row.minimumTarget,
        normalTarget: row.normalTarget,
        targetPeriod: row.targetPeriod,
        targetDays: _decodeIntList(row.targetDaysJson),
        icon: row.icon,
        color: row.color,
        scheduleType: row.scheduleType,
        startDate: row.startDate,
        checkinMethod: row.checkinMethod,
        syncSource: row.syncSource,
        description: row.description,
        isArchived: row.isArchived,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class HabitLogDatabaseMapper {
  static db.HabitLog toRow(HabitLog log) => db.HabitLog(
        id: log.id,
        userId: log.userId,
        activityId: log.activityId,
        logDate: log.logDate,
        value: log.value,
        status: log.status,
        note: log.note,
        metadataJson: log.metadata == null ? null : jsonEncode(log.metadata),
        createdAt: log.createdAt,
        updatedAt: log.updatedAt,
        localVersion: log.localVersion,
        serverVersion: log.serverVersion,
        modifiedByDevice: log.modifiedByDevice,
      );

  static HabitLog fromRow(db.HabitLog row) => HabitLog(
        id: row.id,
        userId: row.userId,
        activityId: row.activityId,
        logDate: row.logDate,
        value: row.value,
        status: row.status,
        note: row.note,
        metadata: _decodeMap(row.metadataJson),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class HabitActivityWireMapper {
  static Map<String, dynamic> toPayload(HabitActivity activity) => {
        'meta': {
          'id': activity.id,
          'userId': activity.userId,
          'createdAt': activity.createdAt,
          'updatedAt': activity.updatedAt,
          'deletedAt': null,
          'localVersion': activity.localVersion,
          'serverVersion': activity.serverVersion,
          'modifiedByDevice': activity.modifiedByDevice,
        },
        'name': activity.name,
        'activityType': activity.activityType,
        'unit': activity.unit,
        'minimumTarget': activity.minimumTarget,
        'normalTarget': activity.normalTarget,
        'targetPeriod': activity.targetPeriod,
        'targetDays': activity.targetDays,
        'icon': activity.icon,
        'color': activity.color,
        'scheduleType': activity.scheduleType,
        'startDate': activity.startDate,
        'checkinMethod': activity.checkinMethod,
        'syncSource': activity.syncSource,
        'description': activity.description,
        'isArchived': activity.isArchived,
      };

  static HabitActivity fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _requiredMap(payload['meta'], 'Activity meta');
    final activity = HabitActivity(
      id: _requiredString(meta, 'id', 'Activity'),
      userId: _requiredString(meta, 'userId', 'Activity'),
      name: _requiredString(payload, 'name', 'Activity'),
      activityType: _requiredString(payload, 'activityType', 'Activity'),
      unit: _requiredString(payload, 'unit', 'Activity'),
      minimumTarget: _double(payload['minimumTarget']),
      normalTarget: _double(payload['normalTarget']),
      targetPeriod: _requiredString(payload, 'targetPeriod', 'Activity'),
      targetDays: _intList(payload['targetDays']),
      icon: _nullableString(payload['icon']),
      color: _nullableString(payload['color']),
      scheduleType: _nullableString(payload['scheduleType']),
      startDate: _nullableString(payload['startDate']),
      checkinMethod: _nullableString(payload['checkinMethod']),
      syncSource: _nullableString(payload['syncSource']),
      description: _nullableString(payload['description']),
      isArchived: payload['isArchived'] == true,
      createdAt: _requiredString(meta, 'createdAt', 'Activity'),
      updatedAt: _requiredString(meta, 'updatedAt', 'Activity'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
    _validateActivity(activity);
    return activity;
  }
}

abstract final class HabitLogWireMapper {
  static Map<String, dynamic> toPayload(HabitLog log) => {
        'meta': {
          'id': log.id,
          'userId': log.userId,
          'createdAt': log.createdAt,
          'updatedAt': log.updatedAt,
          'deletedAt': null,
          'localVersion': log.localVersion,
          'serverVersion': log.serverVersion,
          'modifiedByDevice': log.modifiedByDevice,
        },
        'activityId': log.activityId,
        'logDate': log.logDate,
        'value': log.value,
        'status': log.status,
        'note': log.note,
        'metadata': log.metadata,
      };

  static HabitLog fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _requiredMap(payload['meta'], 'ActivityLog meta');
    final log = HabitLog(
      id: _requiredString(meta, 'id', 'ActivityLog'),
      userId: _requiredString(meta, 'userId', 'ActivityLog'),
      activityId: _nullableString(payload['activityId']),
      logDate: _requiredString(payload, 'logDate', 'ActivityLog'),
      value: _double(payload['value']),
      status: _nullableString(payload['status']),
      note: _nullableString(payload['note']),
      metadata: _mapOrNull(payload['metadata']),
      createdAt: _requiredString(meta, 'createdAt', 'ActivityLog'),
      updatedAt: _requiredString(meta, 'updatedAt', 'ActivityLog'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
    _validateLog(log);
    return log;
  }
}

abstract interface class HabitRepository {
  Stream<List<HabitActivity>> watchActivities(String userId);
  Stream<List<HabitLog>> watchLogsForDate({
    required String userId,
    required String logDate,
  });

  Future<HabitActivity> createActivity({
    required String userId,
    required String deviceId,
    required String name,
    required String activityType,
    required String unit,
    String targetPeriod = 'daily',
    List<int> targetDays = const [],
    double? minimumTarget,
    double? normalTarget,
    String? icon,
    String? color,
    String? scheduleType,
    String? startDate,
    String? checkinMethod = HabitWireValues.checkinManual,
    String? syncSource,
    String? description,
  });

  Future<HabitActivity> updateActivity({
    required HabitActivity activity,
    required String deviceId,
    String? name,
    String? activityType,
    String? unit,
    String? targetPeriod,
    List<int>? targetDays,
    double? minimumTarget,
    double? normalTarget,
    String? icon,
    String? color,
    String? scheduleType,
    String? startDate,
    String? checkinMethod,
    String? syncSource,
    String? description,
    bool? isArchived,
    bool clearMinimumTarget = false,
    bool clearNormalTarget = false,
    bool clearIcon = false,
    bool clearColor = false,
    bool clearScheduleType = false,
    bool clearStartDate = false,
    bool clearCheckinMethod = false,
    bool clearSyncSource = false,
    bool clearDescription = false,
  });

  Future<HabitLog> upsertDailyLog({
    required String userId,
    required String deviceId,
    required String activityId,
    required String logDate,
    double? value,
    String? status,
    String? note,
    Map<String, dynamic>? metadata,
  });

  Future<void> deleteActivity({required HabitActivity activity});
  Future<void> deleteLog({required HabitLog log});
}

class DriftHabitRepository implements HabitRepository {
  DriftHabitRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const activityEntityType = 'habit.activity';
  static const logEntityType = 'habit.log';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<HabitActivity>> watchActivities(String userId) {
    final query = database.select(database.habitActivities)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.isArchived),
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    return query.watch().map(
          (rows) => rows
              .map(HabitActivityDatabaseMapper.fromRow)
              .toList(growable: false),
        );
  }

  @override
  Stream<List<HabitLog>> watchLogsForDate({
    required String userId,
    required String logDate,
  }) {
    _validateLocalDate(logDate, 'logDate');
    final query = database.select(database.habitLogs)
      ..where(
        (table) =>
            table.userId.equals(userId) & table.logDate.equals(logDate),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return query.watch().map(
          (rows) =>
              rows.map(HabitLogDatabaseMapper.fromRow).toList(growable: false),
        );
  }

  @override
  Future<HabitActivity> createActivity({
    required String userId,
    required String deviceId,
    required String name,
    required String activityType,
    required String unit,
    String targetPeriod = 'daily',
    List<int> targetDays = const [],
    double? minimumTarget,
    double? normalTarget,
    String? icon,
    String? color,
    String? scheduleType,
    String? startDate,
    String? checkinMethod = HabitWireValues.checkinManual,
    String? syncSource,
    String? description,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final activity = HabitActivity(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim(),
      activityType: activityType.trim(),
      unit: unit.trim(),
      minimumTarget: minimumTarget,
      normalTarget: normalTarget,
      targetPeriod: targetPeriod.trim(),
      targetDays: List<int>.unmodifiable(targetDays),
      icon: _clean(icon),
      color: _clean(color),
      scheduleType: _clean(scheduleType),
      startDate: _clean(startDate),
      checkinMethod: _clean(checkinMethod),
      syncSource: _clean(syncSource),
      description: _clean(description),
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    _validateActivity(activity);
    await _writeActivity(activity);
    return activity;
  }

  @override
  Future<HabitActivity> updateActivity({
    required HabitActivity activity,
    required String deviceId,
    String? name,
    String? activityType,
    String? unit,
    String? targetPeriod,
    List<int>? targetDays,
    double? minimumTarget,
    double? normalTarget,
    String? icon,
    String? color,
    String? scheduleType,
    String? startDate,
    String? checkinMethod,
    String? syncSource,
    String? description,
    bool? isArchived,
    bool clearMinimumTarget = false,
    bool clearNormalTarget = false,
    bool clearIcon = false,
    bool clearColor = false,
    bool clearScheduleType = false,
    bool clearStartDate = false,
    bool clearCheckinMethod = false,
    bool clearSyncSource = false,
    bool clearDescription = false,
  }) async {
    final updated = activity.copyWith(
      name: name?.trim(),
      activityType: activityType?.trim(),
      unit: unit?.trim(),
      targetPeriod: targetPeriod?.trim(),
      targetDays:
          targetDays == null ? null : List<int>.unmodifiable(targetDays),
      minimumTarget: minimumTarget,
      normalTarget: normalTarget,
      icon: _clean(icon),
      color: _clean(color),
      scheduleType: _clean(scheduleType),
      startDate: _clean(startDate),
      checkinMethod: _clean(checkinMethod),
      syncSource: _clean(syncSource),
      description: _clean(description),
      isArchived: isArchived,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      localVersion: activity.localVersion + 1,
      modifiedByDevice: deviceId,
      clearMinimumTarget: clearMinimumTarget,
      clearNormalTarget: clearNormalTarget,
      clearIcon: clearIcon,
      clearColor: clearColor,
      clearScheduleType: clearScheduleType,
      clearStartDate: clearStartDate,
      clearCheckinMethod: clearCheckinMethod,
      clearSyncSource: clearSyncSource,
      clearDescription: clearDescription,
    );
    _validateActivity(updated);
    await _writeActivity(updated);
    return updated;
  }

  @override
  Future<HabitLog> upsertDailyLog({
    required String userId,
    required String deviceId,
    required String activityId,
    required String logDate,
    double? value,
    String? status,
    String? note,
    Map<String, dynamic>? metadata,
  }) async {
    _validateLocalDate(logDate, 'logDate');
    final existing = await (database.select(database.habitLogs)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.activityId.equals(activityId) &
                table.logDate.equals(logDate),
          )
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    final now = DateTime.now().toUtc().toIso8601String();
    final log = HabitLog(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      activityId: activityId,
      logDate: logDate,
      value: value,
      status: _clean(status),
      note: _clean(note),
      metadata: metadata == null
          ? null
          : Map<String, dynamic>.unmodifiable(metadata),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      localVersion: (existing?.localVersion ?? 0) + 1,
      serverVersion: existing?.serverVersion,
      modifiedByDevice: deviceId,
    );
    _validateLog(log);
    await _writeLog(log);
    return log;
  }

  @override
  Future<void> deleteActivity({required HabitActivity activity}) async {
    await _deleteEntity(
      userId: activity.userId,
      entityType: activityEntityType,
      entityId: activity.id,
      baseServerVersion: activity.serverVersion,
      deleteLocal: () => (database.delete(database.habitActivities)
            ..where(
              (table) =>
                  table.userId.equals(activity.userId) &
                  table.id.equals(activity.id),
            ))
          .go(),
    );
  }

  @override
  Future<void> deleteLog({required HabitLog log}) async {
    await _deleteEntity(
      userId: log.userId,
      entityType: logEntityType,
      entityId: log.id,
      baseServerVersion: log.serverVersion,
      deleteLocal: () => (database.delete(database.habitLogs)
            ..where(
              (table) =>
                  table.userId.equals(log.userId) & table.id.equals(log.id),
            ))
          .go(),
    );
  }

  Future<void> _writeActivity(HabitActivity activity) async {
    await database.transaction(() async {
      await database
          .into(database.habitActivities)
          .insertOnConflictUpdate(HabitActivityDatabaseMapper.toRow(activity));
      await _enqueue(
        userId: activity.userId,
        entityType: activityEntityType,
        entityId: activity.id,
        baseServerVersion: activity.serverVersion,
        modifiedAt: activity.updatedAt,
        payload: HabitActivityWireMapper.toPayload(activity),
      );
    });
  }

  Future<void> _writeLog(HabitLog log) async {
    await database.transaction(() async {
      await database
          .into(database.habitLogs)
          .insertOnConflictUpdate(HabitLogDatabaseMapper.toRow(log));
      await _enqueue(
        userId: log.userId,
        entityType: logEntityType,
        entityId: log.id,
        baseServerVersion: log.serverVersion,
        modifiedAt: log.updatedAt,
        payload: HabitLogWireMapper.toPayload(log),
      );
    });
  }

  Future<void> _enqueue({
    required String userId,
    required String entityType,
    required String entityId,
    required String? baseServerVersion,
    required String modifiedAt,
    required Map<String, dynamic> payload,
  }) =>
      database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: userId,
              entityType: entityType,
              entityId: entityId,
              operation: 'upsert',
              baseServerVersion: baseServerVersion ?? '0',
              clientModifiedAt: modifiedAt,
              payloadJson: Value(jsonEncode(payload)),
              createdAt: modifiedAt,
            ),
          );

  Future<void> _deleteEntity({
    required String userId,
    required String entityType,
    required String entityId,
    required String? baseServerVersion,
    required Future<int> Function() deleteLocal,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction(() async {
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: userId,
              entityType: entityType,
              entityId: entityId,
              operation: 'delete',
              baseServerVersion: baseServerVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await deleteLocal();
    });
  }
}

List<int> _decodeIntList(String raw) {
  final value = jsonDecode(raw);
  if (value is! List) return const [];
  return value
      .whereType<num>()
      .map((item) => item.toInt())
      .toList(growable: false);
}

Map<String, dynamic>? _decodeMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = jsonDecode(raw);
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

Map<String, dynamic> _requiredMap(Object? value, String name) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$name must be a JSON object');
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('ActivityLog metadata must be a JSON object');
}

String _requiredString(
  Map<String, dynamic> json,
  String name,
  String entity,
) {
  final value = _nullableString(json[name]);
  if (value == null) throw FormatException('$entity payload is missing $name');
  return value;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

List<int> _intList(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Activity targetDays must be a JSON array');
  }
  return value.map((item) {
    if (item is num) return item.toInt();
    final parsed = int.tryParse(item.toString());
    if (parsed == null) {
      throw const FormatException('Activity targetDays contains non-integer');
    }
    return parsed;
  }).toList(growable: false);
}

void _validateActivity(HabitActivity activity) {
  if (activity.name.trim().isEmpty) {
    throw ArgumentError('Habit activity name 不能为空');
  }
  if (activity.activityType.trim().isEmpty) {
    throw ArgumentError('Habit activityType 不能为空');
  }
  if (activity.unit.trim().isEmpty) {
    throw ArgumentError('Habit unit 不能为空');
  }
  if (activity.targetPeriod.trim().isEmpty) {
    throw ArgumentError('Habit targetPeriod 不能为空');
  }
  if (activity.minimumTarget != null &&
      (!activity.minimumTarget!.isFinite || activity.minimumTarget! < 0)) {
    throw ArgumentError('minimumTarget 必须是非负有限数');
  }
  if (activity.normalTarget != null &&
      (!activity.normalTarget!.isFinite || activity.normalTarget! < 0)) {
    throw ArgumentError('normalTarget 必须是非负有限数');
  }
  if (activity.startDate != null) {
    _validateLocalDate(activity.startDate!, 'startDate');
  }
}

void _validateLog(HabitLog log) {
  _validateLocalDate(log.logDate, 'logDate');
  if (log.value != null && !log.value!.isFinite) {
    throw ArgumentError('Habit log value 必须是有限数');
  }
}

void _validateLocalDate(String raw, String name) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) {
    throw ArgumentError.value(raw, name, '必须是 YYYY-MM-DD');
  }
  final date = DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  final normalized =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  if (normalized != raw) {
    throw ArgumentError.value(raw, name, '日期不存在');
  }
}

String? _clean(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}
