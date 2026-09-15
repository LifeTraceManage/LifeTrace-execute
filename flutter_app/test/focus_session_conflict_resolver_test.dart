import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart'
    hide FocusTimerState;
import 'package:lifetrace_execute/data/repository/focus_repository.dart';
import 'package:lifetrace_execute/data/sync/focus_session_conflict_resolver.dart';
import 'package:lifetrace_execute/domain/focus/execution_focus_session.dart';
import 'package:lifetrace_execute/domain/focus/focus_timer_state.dart';

void main() {
  late AppDatabase database;
  late DriftFocusRepository repository;
  late FocusSessionConflictResolver resolver;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftFocusRepository(database);
    resolver = FocusSessionConflictResolver(database);
  });

  tearDown(() async => database.close());

  test('keepServer replaces local focus history and clears queued change',
      () async {
    const local = ExecutionFocusSession(
      id: 'focus-conflict',
      userId: 'user-1',
      taskId: 'task-1',
      mode: FocusMode.short,
      startedAt: '2026-09-12T01:00:00.000Z',
      endedAt: '2026-09-12T01:25:00.000Z',
      focusSeconds: 1500,
      completed: true,
      createdAt: '2026-09-12T01:25:00.000Z',
      updatedAt: '2026-09-12T01:25:00.000Z',
      localVersion: 1,
      modifiedByDevice: 'device-local',
    );
    await repository.recordSessionAndSaveState(
      session: local,
      nextState: FocusTimerState.idle(
        userId: 'user-1',
        updatedAt: '2026-09-12T01:25:00.000Z',
      ),
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(local.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'focus-server-conflict',
            userId: 'user-1',
            entityType: DriftFocusRepository.entityType,
            entityId: local.id,
            createdAt: '2026-09-12T02:00:00.000Z',
            serverPayloadJson: Value(
              jsonEncode(_payload(local.id, 1200, false)),
            ),
            serverVersion: const Value('8'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepServer('focus-server-conflict');

    final sessions = await database.select(database.focusSessions).get();
    expect(sessions, hasLength(1));
    expect(sessions.single.focusSeconds, 1200);
    expect(sessions.single.completed, isFalse);
    expect(sessions.single.serverVersion, '8');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });

  test('keepLocal rebases immutable local session onto latest server version',
      () async {
    const local = ExecutionFocusSession(
      id: 'focus-local-conflict',
      userId: 'user-1',
      taskId: 'task-1',
      mode: FocusMode.long,
      startedAt: '2026-09-12T03:00:00.000Z',
      endedAt: '2026-09-12T03:40:00.000Z',
      focusSeconds: 2400,
      completed: false,
      createdAt: '2026-09-12T03:40:00.000Z',
      updatedAt: '2026-09-12T03:40:00.000Z',
      localVersion: 1,
      modifiedByDevice: 'device-local',
    );
    await repository.recordSessionAndSaveState(
      session: local,
      nextState: FocusTimerState.idle(
        userId: 'user-1',
        mode: FocusMode.long,
        updatedAt: '2026-09-12T03:40:00.000Z',
      ),
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(local.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    final queued = (await database.select(database.syncOutbox).get()).single;
    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'focus-local-conflict-row',
            userId: 'user-1',
            entityType: DriftFocusRepository.entityType,
            entityId: local.id,
            createdAt: '2026-09-12T04:00:00.000Z',
            changeId: Value(queued.changeId),
            serverPayloadJson: Value(
              jsonEncode(_payload(local.id, 3000, true)),
            ),
            serverVersion: const Value('15'),
            reason: const Value('server version changed'),
          ),
        );

    await resolver.keepLocal(
      conflictId: 'focus-local-conflict-row',
      deviceId: 'device-rebase',
    );

    final session = (await database.select(database.focusSessions).get()).single;
    expect(session.focusSeconds, 2400);
    expect(session.completed, isFalse);
    expect(session.serverVersion, '15');
    expect(session.modifiedByDevice, 'device-rebase');
    expect(session.localVersion, 2);

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.baseServerVersion, '15');
    final payload = jsonDecode(outbox.single.payloadJson!);
    expect(payload['focusSeconds'], 2400);
    expect(payload['completed'], isFalse);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });
}

Map<String, dynamic> _payload(
  String id,
  int focusSeconds,
  bool completed,
) =>
    {
      'id': id,
      'userId': 'user-1',
      'taskId': 'task-1',
      'mode': 'short',
      'startedAt': '2026-09-12T01:00:00.000Z',
      'endedAt': '2026-09-12T01:25:00.000Z',
      'focusSeconds': focusSeconds,
      'completed': completed,
    };
