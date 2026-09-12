import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/important_date/execution_important_date.dart';
import '../../domain/important_date/important_date_occurrence.dart';
import '../local/app_database.dart' as db;

abstract final class ImportantDateDatabaseMapper {
  static db.ImportantDate toRow(ExecutionImportantDate item) => db.ImportantDate(
        id: item.id,
        userId: item.userId,
        title: item.title,
        date: item.date,
        repeat: item.repeat.wireValue,
        kind: item.kind.wireValue,
        calendar: item.calendar.wireValue,
        lunarYear: item.lunarYear,
        lunarMonth: item.lunarMonth,
        lunarDay: item.lunarDay,
        lunarLeapMonth: item.lunarLeapMonth,
        enabled: item.enabled,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        localVersion: item.localVersion,
        serverVersion: item.serverVersion,
        modifiedByDevice: item.modifiedByDevice,
      );

  static ExecutionImportantDate fromRow(db.ImportantDate row) =>
      ExecutionImportantDate(
        id: row.id,
        userId: row.userId,
        title: row.title,
        date: row.date,
        repeat: ImportantDateRepeat.fromWire(row.repeat),
        kind: ImportantDateKind.fromWire(row.kind),
        calendar: ImportantDateCalendar.fromWire(row.calendar),
        lunarYear: row.lunarYear,
        lunarMonth: row.lunarMonth,
        lunarDay: row.lunarDay,
        lunarLeapMonth: row.lunarLeapMonth,
        enabled: row.enabled,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class ImportantDateWireMapper {
  static Map<String, dynamic> toPayload(ExecutionImportantDate item) => {
        'id': item.id,
        'userId': item.userId,
        'title': item.title,
        'date': item.date,
        'repeat': item.repeat.wireValue,
        'kind': item.kind.wireValue,
        'calendar': item.calendar.wireValue,
        'lunarYear': item.lunarYear,
        'lunarMonth': item.lunarMonth,
        'lunarDay': item.lunarDay,
        'lunarLeapMonth': item.lunarLeapMonth,
        'enabled': item.enabled,
      };

  static ExecutionImportantDate fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
    required String serverModifiedAt,
  }) {
    final item = ExecutionImportantDate(
      id: _requiredString(payload, 'id'),
      userId: _requiredString(payload, 'userId'),
      title: _requiredString(payload, 'title'),
      date: _requiredString(payload, 'date'),
      repeat:
          ImportantDateRepeat.fromWire(_requiredString(payload, 'repeat')),
      kind: ImportantDateKind.fromWire(_requiredString(payload, 'kind')),
      calendar:
          ImportantDateCalendar.fromWire(_requiredString(payload, 'calendar')),
      lunarYear: _nullableInt(payload['lunarYear']),
      lunarMonth: _nullableInt(payload['lunarMonth']),
      lunarDay: _nullableInt(payload['lunarDay']),
      lunarLeapMonth: _bool(payload['lunarLeapMonth'], fallback: false),
      enabled: _bool(payload['enabled'], fallback: true),
      createdAt: serverModifiedAt,
      updatedAt: serverModifiedAt,
      localVersion: 1,
      serverVersion: serverVersion,
      modifiedByDevice: null,
    );
    _validateItem(item);
    return item;
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = json[name]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw FormatException('ImportantDate payload missing $name');
    }
    return value;
  }

  static int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _bool(Object? value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value.toString() == 'true') return true;
    if (value.toString() == 'false') return false;
    throw const FormatException('ImportantDate boolean field is invalid');
  }
}

abstract interface class ImportantDateRepository {
  Stream<List<ExecutionImportantDate>> watchImportantDates(String userId);
  Future<List<ExecutionImportantDate>> listImportantDates(String userId);

  Future<ExecutionImportantDate> createImportantDate({
    required String userId,
    required String deviceId,
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    DateTime? solarDate,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool lunarLeapMonth = false,
    bool enabled = true,
  });

  Future<ExecutionImportantDate> updateImportantDate({
    required ExecutionImportantDate item,
    required String deviceId,
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    DateTime? solarDate,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool lunarLeapMonth = false,
    required bool enabled,
  });

  Future<void> deleteImportantDate({
    required String userId,
    required String importantDateId,
  });
}

class DriftImportantDateRepository implements ImportantDateRepository {
  DriftImportantDateRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const entityType = 'execution.important_date';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<ExecutionImportantDate>> watchImportantDates(String userId) {
    final query = database.select(database.importantDates)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) => rows
              .map(ImportantDateDatabaseMapper.fromRow)
              .toList(growable: false),
        );
  }

  @override
  Future<List<ExecutionImportantDate>> listImportantDates(String userId) async {
    final query = database.select(database.importantDates)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return (await query.get())
        .map(ImportantDateDatabaseMapper.fromRow)
        .toList(growable: false);
  }

  @override
  Future<ExecutionImportantDate> createImportantDate({
    required String userId,
    required String deviceId,
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    DateTime? solarDate,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool lunarLeapMonth = false,
    bool enabled = true,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final normalized = _build(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      repeat: repeat,
      kind: kind,
      calendar: calendar,
      solarDate: solarDate,
      lunarYear: lunarYear,
      lunarMonth: lunarMonth,
      lunarDay: lunarDay,
      lunarLeapMonth: lunarLeapMonth,
      enabled: enabled,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    await writeLocalChange(normalized);
    return normalized;
  }

  @override
  Future<ExecutionImportantDate> updateImportantDate({
    required ExecutionImportantDate item,
    required String deviceId,
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    DateTime? solarDate,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool lunarLeapMonth = false,
    required bool enabled,
  }) async {
    final updated = _build(
      id: item.id,
      userId: item.userId,
      title: title,
      repeat: repeat,
      kind: kind,
      calendar: calendar,
      solarDate: solarDate,
      lunarYear: lunarYear,
      lunarMonth: lunarMonth,
      lunarDay: lunarDay,
      lunarLeapMonth: lunarLeapMonth,
      enabled: enabled,
      createdAt: item.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      localVersion: item.localVersion + 1,
      serverVersion: item.serverVersion,
      modifiedByDevice: deviceId,
    );
    await writeLocalChange(updated);
    return updated;
  }

  @override
  Future<void> deleteImportantDate({
    required String userId,
    required String importantDateId,
  }) async {
    final existing = await (database.select(database.importantDates)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.id.equals(importantDateId),
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
              entityId: importantDateId,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.importantDates)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.id.equals(importantDateId),
            ))
          .go();
    });
  }

  Future<void> writeLocalChange(ExecutionImportantDate item) async {
    _validateItem(item);
    await database.transaction(() async {
      await database.into(database.importantDates).insertOnConflictUpdate(
            ImportantDateDatabaseMapper.toRow(item),
          );
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: item.userId,
              entityType: entityType,
              entityId: item.id,
              operation: 'upsert',
              baseServerVersion: item.serverVersion ?? '0',
              clientModifiedAt: item.updatedAt,
              payloadJson:
                  Value(jsonEncode(ImportantDateWireMapper.toPayload(item))),
              createdAt: item.updatedAt,
            ),
          );
    });
  }

  static ExecutionImportantDate _build({
    required String id,
    required String userId,
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    required DateTime? solarDate,
    required int? lunarYear,
    required int? lunarMonth,
    required int? lunarDay,
    required bool lunarLeapMonth,
    required bool enabled,
    required String createdAt,
    required String updatedAt,
    required int localVersion,
    String? serverVersion,
    String? modifiedByDevice,
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', '重要日期标题不能为空');
    }

    late final String anchor;
    int? nextLunarYear;
    int? nextLunarMonth;
    int? nextLunarDay;
    var nextLeap = false;

    if (calendar == ImportantDateCalendar.solar) {
      if (solarDate == null) {
        throw ArgumentError('公历重要日期必须选择日期');
      }
      anchor = _ymd(solarDate);
    } else {
      if (lunarYear == null || lunarMonth == null || lunarDay == null) {
        throw ArgumentError('农历重要日期必须填写农历年、月、日');
      }
      final derived = lunarDateToSolar(
        lunarYear,
        lunarMonth,
        lunarDay,
        leapMonth: lunarLeapMonth,
      );
      if (derived == null) {
        throw ArgumentError('该农历日期不存在，请检查闰月和日期');
      }
      anchor = _ymd(derived);
      nextLunarYear = lunarYear;
      nextLunarMonth = lunarMonth;
      nextLunarDay = lunarDay;
      nextLeap = lunarLeapMonth;
    }

    final item = ExecutionImportantDate(
      id: id,
      userId: userId,
      title: cleanTitle,
      date: anchor,
      repeat: repeat,
      kind: kind,
      calendar: calendar,
      lunarYear: nextLunarYear,
      lunarMonth: nextLunarMonth,
      lunarDay: nextLunarDay,
      lunarLeapMonth: nextLeap,
      enabled: enabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
      localVersion: localVersion,
      serverVersion: serverVersion,
      modifiedByDevice: modifiedByDevice,
    );
    _validateItem(item);
    return item;
  }

  static String _ymd(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return local.year.toString().padLeft(4, '0') +
        '-' +
        two(local.month) +
        '-' +
        two(local.day);
  }
}

void _validateItem(ExecutionImportantDate item) {
  if (item.title.trim().isEmpty) {
    throw const FormatException('ImportantDate title must not be empty');
  }
  final date = DateTime.tryParse(item.date + 'T00:00:00');
  if (date == null) throw const FormatException('ImportantDate date is invalid');

  if (item.calendar == ImportantDateCalendar.solar) {
    if (item.lunarYear != null ||
        item.lunarMonth != null ||
        item.lunarDay != null ||
        item.lunarLeapMonth) {
      throw const FormatException(
        'Solar ImportantDate cannot contain lunar source fields',
      );
    }
    return;
  }

  final year = item.lunarYear;
  final month = item.lunarMonth;
  final day = item.lunarDay;
  if (month == null || day == null) {
    throw const FormatException('Lunar ImportantDate requires month/day');
  }
  if (item.repeat == ImportantDateRepeat.once && year == null) {
    throw const FormatException(
      'One-off lunar ImportantDate requires lunarYear',
    );
  }
  if (month < 1 || month > 12 || day < 1 || day > 30) {
    throw const FormatException('Lunar ImportantDate source fields invalid');
  }
  if (year != null &&
      lunarDateToSolar(
            year,
            month,
            day,
            leapMonth: item.lunarLeapMonth,
          ) ==
          null) {
    throw const FormatException('Lunar ImportantDate does not exist');
  }
}

class PreviewImportantDateRepository implements ImportantDateRepository {
  final List<ExecutionImportantDate> _items = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<ExecutionImportantDate>> watchImportantDates(String userId) async* {
    List<ExecutionImportantDate> snapshot() =>
        _items.where((item) => item.userId == userId).toList(growable: false);
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<List<ExecutionImportantDate>> listImportantDates(String userId) async =>
      _items.where((item) => item.userId == userId).toList(growable: false);

  @override
  Future<ExecutionImportantDate> createImportantDate({
    required String userId,
    required String deviceId,
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    DateTime? solarDate,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool lunarLeapMonth = false,
    bool enabled = true,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final item = DriftImportantDateRepository._build(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      repeat: repeat,
      kind: kind,
      calendar: calendar,
      solarDate: solarDate,
      lunarYear: lunarYear,
      lunarMonth: lunarMonth,
      lunarDay: lunarDay,
      lunarLeapMonth: lunarLeapMonth,
      enabled: enabled,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    _items.add(item);
    _changes.add(null);
    return item;
  }

  @override
  Future<ExecutionImportantDate> updateImportantDate({
    required ExecutionImportantDate item,
    required String deviceId,
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    DateTime? solarDate,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool lunarLeapMonth = false,
    required bool enabled,
  }) async {
    final updated = DriftImportantDateRepository._build(
      id: item.id,
      userId: item.userId,
      title: title,
      repeat: repeat,
      kind: kind,
      calendar: calendar,
      solarDate: solarDate,
      lunarYear: lunarYear,
      lunarMonth: lunarMonth,
      lunarDay: lunarDay,
      lunarLeapMonth: lunarLeapMonth,
      enabled: enabled,
      createdAt: item.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      localVersion: item.localVersion + 1,
      serverVersion: item.serverVersion,
      modifiedByDevice: deviceId,
    );
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    if (index >= 0) _items[index] = updated;
    _changes.add(null);
    return updated;
  }

  @override
  Future<void> deleteImportantDate({
    required String userId,
    required String importantDateId,
  }) async {
    _items.removeWhere(
      (item) => item.userId == userId && item.id == importantDateId,
    );
    _changes.add(null);
  }
}
