import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/calendar/execution_calendar_event.dart';
import '../local/app_database.dart' as db;
import 'calendar_event_database_mapper.dart';
import 'calendar_event_wire_mapper.dart';

abstract interface class CalendarEventRepository {
  Stream<List<ExecutionCalendarEvent>> watchEvents(String userId);

  Future<ExecutionCalendarEvent> createEvent({
    required String userId,
    required String deviceId,
    required String title,
    required String startAt,
    String? description,
    String? location,
    bool allDay = false,
    String? endAt,
  });

  Future<ExecutionCalendarEvent> updateEvent({
    required ExecutionCalendarEvent event,
    required String deviceId,
    String? title,
    String? description,
    String? location,
    bool? allDay,
    String? startAt,
    String? endAt,
    bool clearDescription = false,
    bool clearLocation = false,
    bool clearEndAt = false,
  });

  Future<void> deleteEvent({
    required String userId,
    required String eventId,
  });
}

class DriftCalendarEventRepository implements CalendarEventRepository {
  DriftCalendarEventRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const entityType = 'execution.calendar_event';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<ExecutionCalendarEvent>> watchEvents(String userId) {
    final query = database.select(database.calendarEvents)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.asc(table.startAt)]);
    return query.watch().map(
          (rows) => rows
              .map(CalendarEventDatabaseMapper.fromRow)
              .toList(growable: false),
        );
  }

  @override
  Future<ExecutionCalendarEvent> createEvent({
    required String userId,
    required String deviceId,
    required String title,
    required String startAt,
    String? description,
    String? location,
    bool allDay = false,
    String? endAt,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', '日程标题不能为空');
    }
    _validateRange(startAt, endAt);

    final now = DateTime.now().toUtc().toIso8601String();
    final event = ExecutionCalendarEvent(
      id: _uuid.v4(),
      userId: userId,
      title: cleanTitle,
      description: _clean(description),
      location: _clean(location),
      allDay: allDay,
      startAt: startAt,
      endAt: _clean(endAt),
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    await _writeLocalChange(event);
    return event;
  }

  @override
  Future<ExecutionCalendarEvent> updateEvent({
    required ExecutionCalendarEvent event,
    required String deviceId,
    String? title,
    String? description,
    String? location,
    bool? allDay,
    String? startAt,
    String? endAt,
    bool clearDescription = false,
    bool clearLocation = false,
    bool clearEndAt = false,
  }) async {
    final nextTitle = (title ?? event.title).trim();
    if (nextTitle.isEmpty) {
      throw ArgumentError.value(nextTitle, 'title', '日程标题不能为空');
    }
    final nextStartAt = startAt ?? event.startAt;
    final nextEndAt = clearEndAt ? null : endAt ?? event.endAt;
    _validateRange(nextStartAt, nextEndAt);

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = ExecutionCalendarEvent(
      id: event.id,
      userId: event.userId,
      title: nextTitle,
      description: clearDescription
          ? null
          : description == null
              ? event.description
              : _clean(description),
      location: clearLocation
          ? null
          : location == null
              ? event.location
              : _clean(location),
      allDay: allDay ?? event.allDay,
      startAt: nextStartAt,
      endAt: nextEndAt,
      createdAt: event.createdAt,
      updatedAt: now,
      localVersion: event.localVersion + 1,
      serverVersion: event.serverVersion,
      modifiedByDevice: deviceId,
    );
    await _writeLocalChange(updated);
    return updated;
  }

  @override
  Future<void> deleteEvent({
    required String userId,
    required String eventId,
  }) async {
    final existing = await (database.select(database.calendarEvents)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.id.equals(eventId),
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
              entityId: eventId,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.calendarEvents)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.id.equals(eventId),
            ))
          .go();
    });
  }

  Future<void> _writeLocalChange(ExecutionCalendarEvent event) async {
    await database.transaction(() async {
      await database
          .into(database.calendarEvents)
          .insertOnConflictUpdate(CalendarEventDatabaseMapper.toRow(event));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: event.userId,
              entityType: entityType,
              entityId: event.id,
              operation: 'upsert',
              baseServerVersion: event.serverVersion ?? '0',
              clientModifiedAt: event.updatedAt,
              payloadJson: Value(
                jsonEncode(CalendarEventWireMapper.toPayload(event)),
              ),
              createdAt: event.updatedAt,
            ),
          );
    });
  }

  static void _validateRange(String startAt, String? endAt) {
    final start = DateTime.tryParse(startAt);
    if (start == null) {
      throw ArgumentError.value(startAt, 'startAt', '无效的开始时间');
    }
    if (endAt == null || endAt.trim().isEmpty) return;
    final end = DateTime.tryParse(endAt);
    if (end == null) {
      throw ArgumentError.value(endAt, 'endAt', '无效的结束时间');
    }
    if (end.isBefore(start)) {
      throw ArgumentError.value(endAt, 'endAt', '结束时间不能早于开始时间');
    }
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

class PreviewCalendarEventRepository implements CalendarEventRepository {
  PreviewCalendarEventRepository()
      : _events = [
          _sample(
            id: 'preview-calendar-1',
            title: '项目会议',
            startAt: '2026-09-11T06:30:00.000Z',
            endAt: '2026-09-11T07:30:00.000Z',
            location: '会议室',
          ),
          _sample(
            id: 'preview-calendar-2',
            title: '训练',
            startAt: '2026-09-11T11:00:00.000Z',
            endAt: '2026-09-11T12:00:00.000Z',
          ),
        ];

  final List<ExecutionCalendarEvent> _events;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  final Uuid _uuid = const Uuid();

  static ExecutionCalendarEvent _sample({
    required String id,
    required String title,
    required String startAt,
    String? endAt,
    String? location,
  }) =>
      ExecutionCalendarEvent(
        id: id,
        userId: 'preview-user',
        title: title,
        location: location,
        startAt: startAt,
        endAt: endAt,
        createdAt: '2026-09-11T00:00:00.000Z',
        updatedAt: '2026-09-11T00:00:00.000Z',
        localVersion: 1,
        modifiedByDevice: 'web-preview',
      );

  @override
  Stream<List<ExecutionCalendarEvent>> watchEvents(String userId) async* {
    List<ExecutionCalendarEvent> snapshot() => _events
        .where((event) => event.userId == userId)
        .toList(growable: false)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<ExecutionCalendarEvent> createEvent({
    required String userId,
    required String deviceId,
    required String title,
    required String startAt,
    String? description,
    String? location,
    bool allDay = false,
    String? endAt,
  }) async {
    DriftCalendarEventRepository._validateRange(startAt, endAt);
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('日程标题不能为空');
    final now = DateTime.now().toUtc().toIso8601String();
    final event = ExecutionCalendarEvent(
      id: _uuid.v4(),
      userId: userId,
      title: cleanTitle,
      description: DriftCalendarEventRepository._clean(description),
      location: DriftCalendarEventRepository._clean(location),
      allDay: allDay,
      startAt: startAt,
      endAt: DriftCalendarEventRepository._clean(endAt),
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    _events.add(event);
    _changes.add(true);
    return event;
  }

  @override
  Future<ExecutionCalendarEvent> updateEvent({
    required ExecutionCalendarEvent event,
    required String deviceId,
    String? title,
    String? description,
    String? location,
    bool? allDay,
    String? startAt,
    String? endAt,
    bool clearDescription = false,
    bool clearLocation = false,
    bool clearEndAt = false,
  }) async {
    final updated = event.copyWith(
      title: title?.trim(),
      description: description,
      location: location,
      allDay: allDay,
      startAt: startAt,
      endAt: endAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      localVersion: event.localVersion + 1,
      modifiedByDevice: deviceId,
      clearDescription: clearDescription,
      clearLocation: clearLocation,
      clearEndAt: clearEndAt,
    );
    DriftCalendarEventRepository._validateRange(
      updated.startAt,
      updated.endAt,
    );
    final index = _events.indexWhere((item) => item.id == event.id);
    if (index >= 0) _events[index] = updated;
    _changes.add(true);
    return updated;
  }

  @override
  Future<void> deleteEvent({
    required String userId,
    required String eventId,
  }) async {
    _events.removeWhere(
      (event) => event.userId == userId && event.id == eventId,
    );
    _changes.add(true);
  }
}
