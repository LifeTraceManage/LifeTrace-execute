import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/focus/focus_timer_engine.dart';
import 'package:lifetrace_execute/data/repository/focus_repository.dart';
import 'package:lifetrace_execute/domain/focus/focus_timer_state.dart';

void main() {
  late PreviewFocusRepository repository;
  late DateTime now;
  late FocusTimerEngine engine;

  setUp(() {
    repository = PreviewFocusRepository();
    now = DateTime.utc(2026, 9, 12, 10);
    engine = FocusTimerEngine(
      repository: repository,
      clock: () => now,
    );
  });

  test('pause excludes wall clock time and resume rebuilds expectedEndAt',
      () async {
    final running = await engine.start(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    expect(running.status, FocusTimerStatus.running);
    expect(
      DateTime.parse(running.expectedEndAt!),
      DateTime.utc(2026, 9, 12, 10, 25),
    );

    now = DateTime.utc(2026, 9, 12, 10, 10);
    final paused = await engine.pause(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    expect(paused.status, FocusTimerStatus.paused);
    expect(paused.remainingSecondsWhenPaused, 15 * 60);

    now = DateTime.utc(2026, 9, 12, 11, 10);
    final resumed = await engine.resume(userId: 'user-1');
    expect(resumed.status, FocusTimerStatus.running);
    expect(
      DateTime.parse(resumed.expectedEndAt!),
      DateTime.utc(2026, 9, 12, 11, 25),
    );
  });

  test('process recovery advances completed focus into active break', () async {
    await engine.start(
      userId: 'user-1',
      deviceId: 'device-1',
      linkedTaskId: 'task-1',
    );

    now = DateTime.utc(2026, 9, 12, 10, 27);
    final recovered = await engine.reconcile(
      userId: 'user-1',
      deviceId: 'device-1',
    );

    expect(recovered.phase, FocusPhase.breakTime);
    expect(recovered.status, FocusTimerStatus.running);
    expect(recovered.remainingSeconds(now: now), 3 * 60);

    final sessions = await repository.listSessions('user-1');
    expect(sessions, hasLength(1));
    expect(sessions.single.completed, isTrue);
    expect(sessions.single.focusSeconds, 25 * 60);
    expect(sessions.single.taskId, 'task-1');
  });

  test('recovery across focus and break returns idle without duplicate session',
      () async {
    await engine.start(
      userId: 'user-1',
      deviceId: 'device-1',
    );

    now = DateTime.utc(2026, 9, 12, 10, 32);
    final recovered = await engine.reconcile(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    expect(recovered.status, FocusTimerStatus.idle);
    expect(recovered.phase, FocusPhase.focus);
    expect(recovered.round, 2);

    await engine.reconcile(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    expect(await repository.listSessions('user-1'), hasLength(1));
  });

  test('reset records only actual focused seconds as incomplete', () async {
    await engine.start(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    now = DateTime.utc(2026, 9, 12, 10, 5);

    final reset = await engine.reset(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    expect(reset.status, FocusTimerStatus.idle);

    final sessions = await repository.listSessions('user-1');
    expect(sessions, hasLength(1));
    expect(sessions.single.completed, isFalse);
    expect(sessions.single.focusSeconds, 5 * 60);
  });

  test('long mode persists 50/10 preference across a reset', () async {
    await engine.ensureState(userId: 'user-1');
    await engine.configureMode(
      userId: 'user-1',
      mode: FocusMode.long,
    );
    final running = await engine.start(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    expect(running.focusSeconds, 50 * 60);
    expect(running.breakSeconds, 10 * 60);

    final reset = await engine.reset(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    expect(reset.mode, FocusMode.long);
    expect(reset.focusSeconds, 50 * 60);
    expect(reset.breakSeconds, 10 * 60);
  });
}
