import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/cloud/cloud_contract.dart';
import 'package:lifetrace_execute/core/cloud/cloud_session_manager.dart';
import 'package:lifetrace_execute/core/cloud/lifetrace_sync_client.dart';
import 'package:lifetrace_execute/core/cloud/secure_session_store.dart';
import 'package:lifetrace_execute/core/cloud/sync_models.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/calendar_event_repository.dart';
import 'package:lifetrace_execute/data/repository/daily_review_repository.dart';
import 'package:lifetrace_execute/data/repository/file_metadata_repository.dart';
import 'package:lifetrace_execute/data/repository/important_date_repository.dart';
import 'package:lifetrace_execute/data/repository/memo_repository.dart';
import 'package:lifetrace_execute/data/repository/project_repository.dart';
import 'package:lifetrace_execute/data/repository/reminder_repository.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
import 'package:lifetrace_execute/data/sync/task_sync_coordinator.dart';
import 'package:lifetrace_execute/domain/collection/execution_file_metadata.dart';
import 'package:lifetrace_execute/domain/collection/execution_memo.dart';
import 'package:lifetrace_execute/domain/important_date/execution_important_date.dart';
import 'package:lifetrace_execute/domain/project/execution_project.dart';
import 'package:lifetrace_execute/domain/reminder/execution_reminder.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;
  late DriftProjectRepository projectRepository;
  late DriftCalendarEventRepository calendarRepository;
  late DriftMemoRepository memoRepository;
  late DriftFileMetadataRepository fileMetadataRepository;
  late DriftDailyReviewRepository reviewRepository;
  late DriftReminderRepository reminderRepository;
  late DriftImportantDateRepository importantDateRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
    projectRepository = DriftProjectRepository(database);
    calendarRepository = DriftCalendarEventRepository(database);
    memoRepository = DriftMemoRepository(database);
    fileMetadataRepository = DriftFileMetadataRepository(database);
    reviewRepository = DriftDailyReviewRepository(database);
    reminderRepository = DriftReminderRepository(database);
    importantDateRepository = DriftImportantDateRepository(database);
  });

  tearDown(() async => database.close());

  test('snapshot bootstrap and pull apply upsert and tombstone', () async {
    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'snapshot-request',
          snapshotId: 'snapshot-1',
          snapshotCursor: '10',
          items: [
            SnapshotItem(
              entityType: DriftTaskRepository.entityType,
              entityId: 'remote-1',
              serverVersion: '5',
              payload: _payload('remote-1', 'From snapshot'),
            ),
          ],
          completed: true,
          serverTime: '2026-09-11T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'pull-1',
          serverTime: '2026-09-11T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '11',
              entityType: DriftTaskRepository.entityType,
              entityId: 'remote-2',
              operation: 'upsert',
              serverVersion: '1',
              serverModifiedAt: '2026-09-11T00:01:00.000Z',
              payload: _payload('remote-2', 'From pull'),
            ),
            const PulledChange(
              cursor: '12',
              entityType: DriftTaskRepository.entityType,
              entityId: 'remote-1',
              operation: 'delete',
              serverVersion: '6',
              serverModifiedAt: '2026-09-11T00:01:01.000Z',
              tombstone: {'deletedAt': '2026-09-11T00:01:01.000Z'},
            ),
          ],
          nextCursor: '12',
          hasMore: false,
        ),
      ],
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pulled, 2);
    final tasks = await database.select(database.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'remote-2');
    expect(tasks.single.title, 'From pull');
    final state = (await database.select(database.syncState).get()).single;
    expect(state.cursor, '12');
  });

  test('project snapshot, push and pull use the same execution sync pipeline', () async {
    final local = await projectRepository.createProject(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Local project',
    );
    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'project-snapshot',
          snapshotId: 'project-snapshot-1',
          snapshotCursor: '15',
          items: [
            SnapshotItem(
              entityType: DriftProjectRepository.entityType,
              entityId: 'remote-project',
              serverVersion: '4',
              payload: _projectPayload('remote-project', 'Remote snapshot'),
            ),
          ],
          completed: true,
          serverTime: '2026-09-11T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'project-pull',
          serverTime: '2026-09-11T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '16',
              entityType: DriftProjectRepository.entityType,
              entityId: 'remote-project',
              operation: 'upsert',
              serverVersion: '5',
              serverModifiedAt: '2026-09-11T00:01:00.000Z',
              payload: _projectPayload('remote-project', 'Remote pull'),
            ),
          ],
          nextCursor: '16',
          hasMore: false,
        ),
      ],
      acceptAllPushes: true,
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pushed, 1);
    expect(summary.pulled, 1);
    final projects = await database.select(database.projects).get();
    expect(projects, hasLength(2));
    expect(projects.singleWhere((item) => item.id == local.id).serverVersion, '101');
    expect(projects.singleWhere((item) => item.id == 'remote-project').title, 'Remote pull');
  });

  test('calendar snapshot, push and pull share execution sync pipeline', () async {
    final local = await calendarRepository.createEvent(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Local event',
      startAt: '2026-09-11T06:30:00.000Z',
    );
    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'calendar-snapshot',
          snapshotId: 'calendar-snapshot-1',
          snapshotCursor: '18',
          items: [
            SnapshotItem(
              entityType: DriftCalendarEventRepository.entityType,
              entityId: 'remote-event',
              serverVersion: '2',
              payload: _calendarPayload('remote-event', 'Snapshot event'),
            ),
          ],
          completed: true,
          serverTime: '2026-09-11T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'calendar-pull',
          serverTime: '2026-09-11T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '19',
              entityType: DriftCalendarEventRepository.entityType,
              entityId: 'remote-event',
              operation: 'upsert',
              serverVersion: '3',
              serverModifiedAt: '2026-09-11T00:01:00.000Z',
              payload: _calendarPayload('remote-event', 'Pulled event'),
            ),
          ],
          nextCursor: '19',
          hasMore: false,
        ),
      ],
      acceptAllPushes: true,
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pushed, 1);
    expect(summary.pulled, 1);
    final events = await database.select(database.calendarEvents).get();
    expect(events, hasLength(2));
    expect(events.singleWhere((item) => item.id == local.id).serverVersion, '101');
    expect(
      events.singleWhere((item) => item.id == 'remote-event').title,
      'Pulled event',
    );
  });

  test('memo snapshot, push and pull share execution sync pipeline', () async {
    final local = await memoRepository.createMemo(
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.idea,
      content: 'Local memo',
    );
    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'memo-snapshot',
          snapshotId: 'memo-snapshot-1',
          snapshotCursor: '24',
          items: [
            SnapshotItem(
              entityType: DriftMemoRepository.entityType,
              entityId: 'remote-memo',
              serverVersion: '2',
              payload: _memoPayload('remote-memo', 'Snapshot memo'),
            ),
          ],
          completed: true,
          serverTime: '2026-09-11T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'memo-pull',
          serverTime: '2026-09-11T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '25',
              entityType: DriftMemoRepository.entityType,
              entityId: 'remote-memo',
              operation: 'upsert',
              serverVersion: '3',
              serverModifiedAt: '2026-09-11T00:01:00.000Z',
              payload: _memoPayload('remote-memo', 'Pulled memo'),
            ),
          ],
          nextCursor: '25',
          hasMore: false,
        ),
      ],
      acceptAllPushes: true,
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pushed, 1);
    expect(summary.pulled, 1);
    final memos = await database.select(database.memos).get();
    expect(memos, hasLength(2));
    expect(memos.singleWhere((item) => item.id == local.id).serverVersion, '101');
    expect(
      memos.singleWhere((item) => item.id == 'remote-memo').content,
      'Pulled memo',
    );
  });

  test('file metadata snapshot, push and pull share sync pipeline', () async {
    const local = ExecutionFileMetadata(
      id: 'local-file',
      userId: 'user-1',
      originalName: 'local.png',
      mimeType: 'image/png',
      sizeBytes: 128,
      sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      storageState: ExecutionFileStorageState.serverStored,
      createdByDevice: 'device-1',
      createdAt: '2026-09-11T00:00:00.000Z',
      updatedAt: '2026-09-11T00:00:00.000Z',
      localVersion: 1,
      modifiedByDevice: 'device-1',
    );
    await fileMetadataRepository.writeLocalChange(local);

    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'file-snapshot',
          snapshotId: 'file-snapshot-1',
          snapshotCursor: '28',
          items: [
            SnapshotItem(
              entityType: DriftFileMetadataRepository.entityType,
              entityId: 'remote-file',
              serverVersion: '2',
              payload: _filePayload('remote-file', 'snapshot.png'),
            ),
          ],
          completed: true,
          serverTime: '2026-09-11T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'file-pull',
          serverTime: '2026-09-11T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '29',
              entityType: DriftFileMetadataRepository.entityType,
              entityId: 'remote-file',
              operation: 'upsert',
              serverVersion: '3',
              serverModifiedAt: '2026-09-11T00:01:00.000Z',
              payload: _filePayload('remote-file', 'pulled.png'),
            ),
          ],
          nextCursor: '29',
          hasMore: false,
        ),
      ],
      acceptAllPushes: true,
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pushed, 1);
    expect(summary.pulled, 1);
    final files = await database.select(database.fileRecords).get();
    expect(files, hasLength(2));
    expect(
      files.singleWhere((item) => item.id == 'local-file').serverVersion,
      '101',
    );
    expect(
      files.singleWhere((item) => item.id == 'remote-file').originalName,
      'pulled.png',
    );
  });

  test('daily review snapshot, push and pull share sync pipeline', () async {
    final local = await reviewRepository.saveReview(
      userId: 'user-1',
      deviceId: 'device-1',
      reviewDate: '2026-09-11',
      mood: 4,
      energy: 3,
      completionScore: 0.5,
      completedTaskCount: 1,
      totalTaskCount: 2,
      bestThing: 'Local review',
    );

    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'review-snapshot',
          snapshotId: 'review-snapshot-1',
          snapshotCursor: '30',
          items: [
            SnapshotItem(
              entityType: DriftDailyReviewRepository.entityType,
              entityId: 'remote-review',
              serverVersion: '2',
              payload: _reviewPayload('remote-review', 'Snapshot review'),
            ),
          ],
          completed: true,
          serverTime: '2026-09-11T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'review-pull',
          serverTime: '2026-09-11T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '31',
              entityType: DriftDailyReviewRepository.entityType,
              entityId: 'remote-review',
              operation: 'upsert',
              serverVersion: '3',
              serverModifiedAt: '2026-09-11T00:01:00.000Z',
              payload: _reviewPayload('remote-review', 'Pulled review'),
            ),
          ],
          nextCursor: '31',
          hasMore: false,
        ),
      ],
      acceptAllPushes: true,
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pushed, 1);
    expect(summary.pulled, 1);
    final reviews = await database.select(database.dailyReviews).get();
    expect(reviews, hasLength(2));
    expect(
      reviews.singleWhere((item) => item.id == local.id).serverVersion,
      '101',
    );
    expect(
      reviews.singleWhere((item) => item.id == 'remote-review').bestThing,
      'Pulled review',
    );
  });

  test('important date snapshot, push and pull share sync pipeline', () async {
    final local = await importantDateRepository.createImportantDate(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Local important date',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.anniversary,
      calendar: ImportantDateCalendar.solar,
      solarDate: DateTime(2026, 9, 12),
    );

    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'important-snapshot',
          snapshotId: 'important-snapshot-1',
          snapshotCursor: '31',
          items: [
            SnapshotItem(
              entityType: DriftImportantDateRepository.entityType,
              entityId: 'remote-important',
              serverVersion: '2',
              payload: _importantDatePayload(
                'remote-important',
                'Snapshot important',
              ),
            ),
          ],
          completed: true,
          serverTime: '2026-09-12T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'important-pull',
          serverTime: '2026-09-12T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '32',
              entityType: DriftImportantDateRepository.entityType,
              entityId: 'remote-important',
              operation: 'upsert',
              serverVersion: '3',
              serverModifiedAt: '2026-09-12T00:01:00.000Z',
              payload: _importantDatePayload(
                'remote-important',
                'Pulled important',
              ),
            ),
          ],
          nextCursor: '32',
          hasMore: false,
        ),
      ],
      acceptAllPushes: true,
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pushed, 1);
    expect(summary.pulled, 1);
    final dates = await database.select(database.importantDates).get();
    expect(dates, hasLength(2));
    expect(
      dates.singleWhere((item) => item.id == local.id).serverVersion,
      '101',
    );
    expect(
      dates.singleWhere((item) => item.id == 'remote-important').title,
      'Pulled important',
    );
  });

  test('reminder snapshot, push and fired pull share sync pipeline', () async {
    final local = await reminderRepository.schedule(
      userId: 'user-1',
      deviceId: 'device-1',
      subjectType: ReminderSubjectTypes.task,
      subjectId: 'task-local',
      triggerAt:
          DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String(),
      title: 'Local reminder',
    );

    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'reminder-snapshot',
          snapshotId: 'reminder-snapshot-1',
          snapshotCursor: '32',
          items: [
            SnapshotItem(
              entityType: DriftReminderRepository.entityType,
              entityId: 'remote-reminder',
              serverVersion: '2',
              payload: _reminderPayload(
                'remote-reminder',
                ExecutionReminderStatus.scheduled.wireValue,
              ),
            ),
          ],
          completed: true,
          serverTime: '2026-09-11T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'reminder-pull',
          serverTime: '2026-09-11T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '33',
              entityType: DriftReminderRepository.entityType,
              entityId: 'remote-reminder',
              operation: 'upsert',
              serverVersion: '3',
              serverModifiedAt: '2026-09-11T00:01:00.000Z',
              payload: _reminderPayload(
                'remote-reminder',
                ExecutionReminderStatus.fired.wireValue,
              ),
            ),
          ],
          nextCursor: '33',
          hasMore: false,
        ),
      ],
      acceptAllPushes: true,
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pushed, 1);
    expect(summary.pulled, 1);

    final reminders = await database.select(database.reminders).get();
    expect(reminders, hasLength(2));
    expect(
      reminders.singleWhere((item) => item.id == local.id).serverVersion,
      '101',
    );
    expect(
      reminders.singleWhere((item) => item.id == 'remote-reminder').status,
      ExecutionReminderStatus.fired.wireValue,
    );
  });

  test('accepted push rebases the next unattempted local change', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'First version',
    );
    await repository.updateTask(
      task: created,
      deviceId: 'device-1',
      title: 'Second version',
    );

    final client = _FakeSyncClient(
      snapshots: [emptySnapshot()],
      pulls: [emptyPull('22')],
      acceptAllPushes: true,
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.pushed, 2);
    expect(client.pushBatches, hasLength(2));
    expect(client.pushBatches.first.single.baseServerVersion, '0');
    expect(client.pushBatches[1].single.baseServerVersion, '101');
    expect(client.pushBatches[1].single.payload?['title'], 'Second version');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    final task = (await database.select(database.tasks).get()).single;
    expect(task.serverVersion, '102');
  });

  test('conflict persists record and blocks all queued changes for entity', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Local one',
    );
    await repository.updateTask(
      task: created,
      deviceId: 'device-1',
      title: 'Local two',
    );

    final client = _FakeSyncClient(
      snapshots: [emptySnapshot()],
      pulls: [emptyPull('31')],
      pushHandler: (changes) => PushBatchResult(
        requestId: 'push-conflict',
        serverTime: '2026-09-11T00:02:00.000Z',
        latestCursor: '30',
        results: [
          PushConflict(
            changeId: changes.single.changeId,
            entityType: DriftTaskRepository.entityType,
            entityId: created.id,
            conflictId: 'conflict-1',
            clientBaseServerVersion: '0',
            currentServerVersion: '9',
            serverDeleted: false,
            serverEntity: _payload(created.id, 'Cloud title'),
            reason: 'server version changed',
          ),
        ],
      ),
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.conflicts, 1);
    final conflicts = await database.select(database.syncConflicts).get();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.id, 'conflict-1');
    expect(conflicts.single.serverVersion, '9');
    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(outbox.every((item) => item.blocked), isTrue);
    expect(outbox.every((item) => item.errorCode == 'SYNC_CONFLICT'), isTrue);
  });

  test('rejected push remains blocked with server error', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Will reject',
    );
    final client = _FakeSyncClient(
      snapshots: [emptySnapshot()],
      pulls: [emptyPull('41')],
      pushHandler: (changes) => PushBatchResult(
        requestId: 'push-rejected',
        serverTime: '2026-09-11T00:03:00.000Z',
        latestCursor: '40',
        results: [
          PushRejected(
            changeId: changes.single.changeId,
            entityType: DriftTaskRepository.entityType,
            entityId: created.id,
            code: 'INVALID_ENTITY',
            message: 'bad task',
          ),
        ],
      ),
    );

    final summary = await _coordinatorFor(database, client).syncNow();

    expect(summary.rejected, 1);
    final row = (await database.select(database.syncOutbox).get()).single;
    expect(row.blocked, isTrue);
    expect(row.errorCode, 'INVALID_ENTITY');
    expect(row.errorMessage, 'bad task');
  });

  test('transport failure keeps local change and retry metadata', () async {
    await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Offline safe',
    );
    final client = _FakeSyncClient(
      snapshots: [emptySnapshot()],
      pushError: const CloudApiException(
        statusCode: 503,
        code: 'TEMPORARY',
        retryable: true,
        message: 'temporary outage',
      ),
    );

    await expectLater(
      _coordinatorFor(database, client).syncNow(),
      throwsA(isA<CloudApiException>()),
    );

    expect(await database.select(database.tasks).get(), hasLength(1));
    final row = (await database.select(database.syncOutbox).get()).single;
    expect(row.attemptCount, 1);
    expect(row.blocked, isFalse);
    expect(row.errorCode, 'TEMPORARY');
  });

  test('pull does not overwrite an entity with a local outbox', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Keep local',
    );
    await database.into(database.syncState).insert(
          SyncStateCompanion.insert(
            scope: TaskSyncCoordinator.taskScopeKey,
            userId: 'user-1',
            cursor: const Value('60'),
            updatedAt: '2026-09-11T00:04:00.000Z',
          ),
        );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(created.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    final client = _FakeSyncClient(
      pulls: [
        PullBatchResult(
          requestId: 'pull-local',
          serverTime: '2026-09-11T00:05:00.000Z',
          changes: [
            PulledChange(
              cursor: '61',
              entityType: DriftTaskRepository.entityType,
              entityId: created.id,
              operation: 'upsert',
              serverVersion: '77',
              serverModifiedAt: '2026-09-11T00:05:00.000Z',
              payload: _payload(created.id, 'Remote overwrite'),
            ),
          ],
          nextCursor: '61',
          hasMore: false,
        ),
      ],
    );

    await _coordinatorFor(database, client).syncNow();

    final task = (await database.select(database.tasks).get()).single;
    expect(task.title, 'Keep local');
    expect(task.serverVersion, null);
  });

  test('concurrent syncNow calls share one in-flight operation', () async {
    final gate = Completer<void>();
    final client = _FakeSyncClient(
      snapshots: [emptySnapshot()],
      pulls: [emptyPull('71')],
      snapshotGate: gate,
    );
    final coordinator = _coordinatorFor(database, client);

    final first = coordinator.syncNow();
    final second = coordinator.syncNow();
    expect(identical(first, second), isTrue);
    gate.complete();
    await Future.wait([first, second]);
    expect(client.snapshotCalls, 1);
  });
}

TaskSyncCoordinator _coordinatorFor(
  AppDatabase database,
  _FakeSyncClient client,
) =>
    TaskSyncCoordinator(
      database: database,
      sessionManager: _FakeSessionAccess(testSession()),
      syncClient: client,
      deviceIdLoader: () async => 'device-1',
      clientVersion: 'test',
    );

StoredCloudSession testSession() => const StoredCloudSession(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
      accessTokenExpiresAtEpochSeconds: 9999999999,
      userId: 'user-1',
      email: 'user@example.com',
      sessionId: 'session-1',
      scopes: ['sync:read', 'sync:write'],
      protocolVersion: 1,
      schemaVersion: 1,
    );

Map<String, dynamic> _payload(String id, String title) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'remote-device',
      },
      'title': title,
      'description': null,
      'projectId': null,
      'status': ExecutionTaskStatus.todo.wireValue,
      'priority': ExecutionTaskPriority.normal.wireValue,
      'dueAt': null,
      'scheduledAt': null,
      'completedAt': null,
    };

Map<String, dynamic> _calendarPayload(String id, String title) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'remote-device',
      },
      'title': title,
      'description': null,
      'location': null,
      'allDay': false,
      'startAt': '2026-09-11T06:30:00.000Z',
      'endAt': '2026-09-11T07:30:00.000Z',
    };

Map<String, dynamic> _memoPayload(String id, String content) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'remote-device',
      },
      'kind': ExecutionMemoKind.idea.wireValue,
      'title': null,
      'content': content,
      'sourceUrl': null,
      'important': false,
      'status': ExecutionMemoStatus.inbox.wireValue,
    };

Map<String, dynamic> _reviewPayload(String id, String bestThing) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'remote-device',
      },
      'reviewDate': '2026-09-11',
      'energy': 4,
      'mood': 4,
      'completionScore': 0.5,
      'bestThing': bestThing,
      'problem': null,
      'tomorrowPriority': 'Next task',
      'note': null,
      'completedTaskCount': 1,
      'totalTaskCount': 2,
    };

Map<String, dynamic> _importantDatePayload(String id, String title) => {
      'id': id,
      'userId': 'user-1',
      'title': title,
      'date': '2026-09-12',
      'repeat': 'yearly',
      'kind': 'anniversary',
      'calendar': 'solar',
      'lunarYear': null,
      'lunarMonth': null,
      'lunarDay': null,
      'lunarLeapMonth': false,
      'enabled': true,
    };

Map<String, dynamic> _reminderPayload(String id, String status) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:01:00.000Z',
        'deletedAt': null,
        'localVersion': 2,
        'serverVersion': null,
        'modifiedByDevice': 'remote-device',
      },
      'subjectType': 'task',
      'subjectId': 'task-remote',
      'triggerAt': '2026-09-12T01:30:00.000Z',
      'status': status,
      'fireKey': 'task-remote@2026-09-12T01:30:00.000Z',
      'snoozedUntil': null,
      'lastFiredAt':
          status == 'fired' ? '2026-09-11T00:01:00.000Z' : null,
      'title': 'Remote reminder',
      'body': 'Remote body',
    };

Map<String, dynamic> _filePayload(String id, String name) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'remote-device',
      },
      'originalName': name,
      'mimeType': 'image/png',
      'sizeBytes': 128,
      'sha256':
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'storageState': ExecutionFileStorageState.serverStored.wireValue,
      'createdByDevice': 'remote-device',
    };

Map<String, dynamic> _projectPayload(String id, String title) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'remote-device',
      },
      'title': title,
      'description': null,
      'status': ExecutionProjectStatus.active.wireValue,
      'startAt': null,
      'dueAt': null,
    };

SnapshotPageResult emptySnapshot() => const SnapshotPageResult(
      requestId: 'snapshot-empty',
      snapshotId: 'snapshot-empty',
      snapshotCursor: '20',
      items: [],
      completed: true,
      serverTime: '2026-09-11T00:00:00.000Z',
    );

PullBatchResult emptyPull(String cursor) => PullBatchResult(
      requestId: 'pull-empty-$cursor',
      serverTime: '2026-09-11T00:10:00.000Z',
      changes: const [],
      nextCursor: cursor,
      hasMore: false,
    );

class _FakeSessionAccess implements CloudSessionAccess {
  const _FakeSessionAccess(this.session);

  final StoredCloudSession session;

  @override
  Future<StoredCloudSession?> currentSession() async => session;

  @override
  Future<T> authorized<T>(Future<T> Function(StoredCloudSession session) block) =>
      block(session);
}

class _FakeSyncClient implements SyncClient {
  _FakeSyncClient({
    this.snapshots = const [],
    this.pulls = const [],
    this.pushHandler,
    this.pushError,
    this.acceptAllPushes = false,
    this.snapshotGate,
  });

  final List<SnapshotPageResult> snapshots;
  final List<PullBatchResult> pulls;
  final PushBatchResult Function(List<OutgoingSyncChange>)? pushHandler;
  final Object? pushError;
  final bool acceptAllPushes;
  final Completer<void>? snapshotGate;
  final List<List<OutgoingSyncChange>> pushBatches = [];

  int snapshotCalls = 0;
  int _snapshotIndex = 0;
  int _pullIndex = 0;
  int _acceptedVersion = 100;

  @override
  Future<PushBatchResult> push({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required List<OutgoingSyncChange> changes,
  }) async {
    pushBatches.add(List.unmodifiable(changes));
    final failure = pushError;
    if (failure != null) throw failure;
    final handler = pushHandler;
    if (handler != null) return handler(changes);
    if (!acceptAllPushes) {
      return const PushBatchResult(
        requestId: 'push-empty',
        serverTime: '2026-09-11T00:00:00.000Z',
        latestCursor: '0',
        results: [],
      );
    }

    final results = <PushChangeResult>[];
    for (final change in changes) {
      _acceptedVersion++;
      results.add(
        PushAccepted(
          changeId: change.changeId,
          entityType: change.entityType,
          entityId: change.entityId,
          serverVersion: '$_acceptedVersion',
          cursor: '$_acceptedVersion',
          serverModifiedAt: '2026-09-11T00:00:00.000Z',
          duplicate: false,
        ),
      );
    }
    return PushBatchResult(
      requestId: 'push-accepted',
      serverTime: '2026-09-11T00:00:00.000Z',
      latestCursor: '$_acceptedVersion',
      results: results,
    );
  }

  @override
  Future<PullBatchResult> pull({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required String? afterCursor,
    int limit = 100,
    List<String>? entityTypes,
  }) async {
    if (_pullIndex >= pulls.length) return emptyPull(afterCursor ?? '0');
    return pulls[_pullIndex++];
  }

  @override
  Future<SnapshotPageResult> snapshot({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    String? snapshotId,
    String? pageToken,
    List<String>? entityTypes,
    int pageSize = 200,
  }) async {
    snapshotCalls++;
    final gate = snapshotGate;
    if (gate != null) await gate.future;
    if (_snapshotIndex >= snapshots.length) return emptySnapshot();
    return snapshots[_snapshotIndex++];
  }
}
