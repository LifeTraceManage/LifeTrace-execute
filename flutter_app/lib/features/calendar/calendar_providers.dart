import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/calendar_event_repository.dart';
import '../../data/sync/calendar_event_conflict_resolver.dart';
import '../../domain/calendar/execution_calendar_event.dart';
import '../tasks/task_providers.dart';

final calendarEventRepositoryProvider = Provider<CalendarEventRepository>((ref) {
  if (kIsWeb) return PreviewCalendarEventRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftCalendarEventRepository(database);
});

final calendarEventListProvider =
    StreamProvider<List<ExecutionCalendarEvent>>((ref) async* {
  final repository = ref.watch(calendarEventRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionCalendarEvent>[];
    return;
  }
  yield* repository.watchEvents(userId);
});

class CalendarConflictUi {
  const CalendarConflictUi({
    required this.conflictId,
    required this.eventId,
    required this.localTitle,
    required this.serverTitle,
    required this.serverDeleted,
    required this.reason,
  });

  final String conflictId;
  final String eventId;
  final String? localTitle;
  final String? serverTitle;
  final bool serverDeleted;
  final String reason;
}

final calendarConflictsProvider =
    StreamProvider<List<CalendarConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <CalendarConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <CalendarConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.equals(DriftCalendarEventRepository.entityType) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => CalendarConflictUi(
                conflictId: row.id,
                eventId: row.entityId,
                localTitle: _payloadTitle(row.localPayloadJson),
                serverTitle:
                    row.serverDeleted ? null : _payloadTitle(row.serverPayloadJson),
                serverDeleted: row.serverDeleted,
                reason: row.reason,
              ),
            )
            .toList(growable: false),
      );
});

final calendarConflictResolverProvider =
    Provider<CalendarEventConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : CalendarEventConflictResolver(database);
});

final calendarCommandsProvider =
    Provider<CalendarCommands>(CalendarCommands.new);

class CalendarCommands {
  CalendarCommands(this.ref);

  final Ref ref;

  Future<ExecutionCalendarEvent> create({
    required String title,
    required String startAt,
    String? description,
    String? location,
    bool allDay = false,
    String? endAt,
  }) async {
    final event = await ref.read(calendarEventRepositoryProvider).createEvent(
          userId: await _requireUserId(),
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          startAt: startAt,
          description: description,
          location: location,
          allDay: allDay,
          endAt: endAt,
        );
    _scheduleSync();
    return event;
  }

  Future<ExecutionCalendarEvent> update({
    required ExecutionCalendarEvent event,
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
    final updated = await ref.read(calendarEventRepositoryProvider).updateEvent(
          event: event,
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          description: description,
          location: location,
          allDay: allDay,
          startAt: startAt,
          endAt: endAt,
          clearDescription: clearDescription,
          clearLocation: clearLocation,
          clearEndAt: clearEndAt,
        );
    _scheduleSync();
    return updated;
  }

  Future<void> delete(ExecutionCalendarEvent event) async {
    await ref.read(calendarEventRepositoryProvider).deleteEvent(
          userId: event.userId,
          eventId: event.id,
        );
    _scheduleSync();
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(calendarConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(calendarConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepLocal(
      conflictId: conflictId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<String> _requireUserId() async {
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) throw StateError('请先连接 LifeTrace Cloud');
    return userId;
  }

  void _scheduleSync() {
    if (kIsWeb) return;
    unawaited(
      ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true),
    );
  }
}

String? _payloadTitle(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final title = value['title']?.toString().trim();
    return title == null || title.isEmpty ? null : title;
  } catch (_) {
    return null;
  }
}
