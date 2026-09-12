import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/focus_repository.dart';
import 'package:lifetrace_execute/domain/focus/execution_focus_session.dart';
import 'package:lifetrace_execute/domain/focus/focus_timer_state.dart';

void main() {
  late AppDatabase database;
  late DriftFocusRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftFocusRepository(database);
  });

  tearDown(() async => database.close());

  test('session, outbox and next timer state commit atomically', () async {
    const session = ExecutionFocusSession(
      id: 'focus-1',
      userId: 'user-1',
      taskId: 'task-1',
      mode: FocusMode.short,
      startedAt: '2026-09-12T02:00:00.000Z',
      endedAt: '2026-09-12T02:25:00.000Z',
      focusSeconds: 1500,
      completed: true,
      createdAt: '2026-09-12T02:25:00.000Z',
      updatedAt: '2026-09-12T02:25:00.000Z',
      localVersion: 1,
      modifiedByDevice: 'device-1',
    );
    const next = FocusTimerState(
      userId: 'user-1',
      mode: FocusMode.short,
      focusSeconds: 1500,
      breakSeconds: 300,
      phase: FocusPhase.breakTime,
      status: FocusTimerStatus.running,
      startedAt: '2026-09-12T02:25:00.000Z',
      expectedEndAt: '2026-09-12T02:30:00.000Z',
      remainingSecondsWhenPaused: 300,
      linkedTaskId: 'task-1',
      round: 1,
      updatedAt: '2026-09-12T02:25:00.000Z',
    );

    await repository.recordSessionAndSaveState(
      session: session,
      nextState: next,
    );

    final sessions = await database.select(database.focusSessions).get();
    expect(sessions, hasLength(1));
    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.entityType, DriftFocusRepository.entityType);
    expect(outbox.single.changeId, 'focus-1:create');
    final payload = jsonDecode(outbox.single.payloadJson!);
    expect(payload['focusSeconds'], 1500);
    expect(payload['completed'], isTrue);

    final states = await database.select(database.focusTimerStates).get();
    expect(states.single.phase, 'break');
  });

  test('replaying same session id does not duplicate session or outbox',
      () async {
    const session = ExecutionFocusSession(
      id: 'focus-stable',
      userId: 'user-1',
      mode: FocusMode.short,
      startedAt: '2026-09-12T02:00:00.000Z',
      endedAt: '2026-09-12T02:25:00.000Z',
      focusSeconds: 1500,
      completed: true,
      createdAt: '2026-09-12T02:25:00.000Z',
      updatedAt: '2026-09-12T02:25:00.000Z',
      localVersion: 1,
    );
    final idle = FocusTimerState.idle(
      userId: 'user-1',
      updatedAt: '2026-09-12T02:25:00.000Z',
    );

    await repository.recordSessionAndSaveState(
      session: session,
      nextState: idle,
    );
    await repository.recordSessionAndSaveState(
      session: session,
      nextState: idle,
    );

    expect(await database.select(database.focusSessions).get(), hasLength(1));
    expect(await database.select(database.syncOutbox).get(), hasLength(1));
  });

  test('wire mapper preserves Cloud focus contract', () {
    const session = ExecutionFocusSession(
      id: 'focus-2',
      userId: 'user-1',
      taskId: 'task-2',
      mode: FocusMode.long,
      startedAt: '2026-09-12T02:00:00.000Z',
      endedAt: '2026-09-12T02:50:00.000Z',
      focusSeconds: 3000,
      completed: true,
      createdAt: '2026-09-12T02:50:00.000Z',
      updatedAt: '2026-09-12T02:50:00.000Z',
      localVersion: 1,
    );

    final payload = FocusSessionWireMapper.toPayload(session);
    expect(payload['mode'], 'long');
    expect(payload['taskId'], 'task-2');
    expect(payload.containsKey('localVersion'), isFalse);

    final parsed = FocusSessionWireMapper.fromPayload(
      payload,
      serverVersion: '7',
      serverModifiedAt: '2026-09-12T02:51:00.000Z',
    );
    expect(parsed.id, session.id);
    expect(parsed.serverVersion, '7');
    expect(parsed.focusSeconds, 3000);
  });
}
