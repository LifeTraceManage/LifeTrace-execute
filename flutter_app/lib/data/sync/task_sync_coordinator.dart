import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/cloud/cloud_contract.dart';
import '../../core/cloud/cloud_session_manager.dart';
import '../../core/cloud/lifetrace_sync_client.dart';
import '../../core/cloud/sync_models.dart';
import '../../core/identity/device_identity_store.dart';
import '../../domain/collection/entity_link.dart';
import '../local/app_database.dart' as db;
import '../repository/calendar_event_database_mapper.dart';
import '../repository/calendar_event_repository.dart';
import '../repository/calendar_event_wire_mapper.dart';
import '../repository/daily_review_repository.dart';
import '../repository/entity_link_repository.dart';
import '../repository/file_metadata_repository.dart';
import '../repository/important_date_repository.dart';
import '../repository/memo_repository.dart';
import '../repository/project_database_mapper.dart';
import '../repository/project_repository.dart';
import '../repository/project_wire_mapper.dart';
import '../repository/reminder_repository.dart';
import '../repository/task_database_mapper.dart';
import '../repository/task_repository.dart';
import '../repository/task_wire_mapper.dart';

typedef DeviceIdLoader = Future<String> Function();

class TaskSyncSummary {
  const TaskSyncSummary({
    required this.snapshotItems,
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    required this.rejected,
  });

  final int snapshotItems;
  final int pushed;
  final int pulled;
  final int conflicts;
  final int rejected;
}

class TaskSyncCoordinator {
  TaskSyncCoordinator({
    required this.database,
    CloudSessionAccess? sessionManager,
    SyncClient? syncClient,
    DeviceIdLoader? deviceIdLoader,
    this.clientVersion = '0.3.0',
  })  : _sessionManager = sessionManager ?? CloudSessionManager(),
        _syncClient = syncClient ?? LifeTraceSyncClient(),
        _deviceIdLoader = deviceIdLoader ?? DeviceIdentityStore().getOrCreate;

  static const taskScopeKey =
      'entities:execution.task,execution.project,execution.calendar_event,execution.important_date,execution.memo,execution.reminder,review.daily,file.metadata,entity.link';
  static const syncEntityTypes = <String>[
    DriftTaskRepository.entityType,
    DriftProjectRepository.entityType,
    DriftCalendarEventRepository.entityType,
    DriftImportantDateRepository.entityType,
    DriftMemoRepository.entityType,
    DriftReminderRepository.entityType,
    DriftDailyReviewRepository.entityType,
    DriftFileMetadataRepository.entityType,
    DriftEntityLinkRepository.entityType,
  ];
  static const _pushBatchSize = 100;
  static const _pullBatchSize = 100;
  static const _snapshotPageSize = 100;
  static const _maxPushRounds = 20;

  final db.AppDatabase database;
  final CloudSessionAccess _sessionManager;
  final SyncClient _syncClient;
  final DeviceIdLoader _deviceIdLoader;
  final String clientVersion;

  Future<TaskSyncSummary>? _activeSync;

  Future<TaskSyncSummary> syncNow() {
    final active = _activeSync;
    if (active != null) return active;

    late final Future<TaskSyncSummary> tracked;
    tracked = _syncInternal().whenComplete(() {
      if (identical(_activeSync, tracked)) _activeSync = null;
    });
    _activeSync = tracked;
    return tracked;
  }

  Future<TaskSyncSummary> _syncInternal() {
    return _sessionManager.authorized((session) async {
      final client = SyncClientContext(
        clientVersion: clientVersion,
        deviceId: await _deviceIdLoader(),
        schemaVersion: session.schemaVersion,
      );

      var snapshotItems = 0;
      var pushed = 0;
      var conflicts = 0;
      var rejected = 0;

      var state = await _getSyncState(session.userId);
      if (state?.cursor == null) {
        snapshotItems = await _restoreTaskSnapshot(
          userId: session.userId,
          baseUrl: session.baseUrl,
          accessToken: session.accessToken,
          client: client,
        );
        state = await _getSyncState(session.userId);
      }

      for (var round = 0; round < _maxPushRounds; round++) {
        final result = await _pushOneRound(
          userId: session.userId,
          baseUrl: session.baseUrl,
          accessToken: session.accessToken,
          client: client,
        );
        if (!result.hadWork) break;
        pushed += result.accepted;
        conflicts += result.conflicts;
        rejected += result.rejected;
      }

      final pulled = await _pullUntilCurrent(
        userId: session.userId,
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
        client: client,
        afterCursor: state?.cursor,
      );

      return TaskSyncSummary(
        snapshotItems: snapshotItems,
        pushed: pushed,
        pulled: pulled,
        conflicts: conflicts,
        rejected: rejected,
      );
    });
  }

  Future<int> _restoreTaskSnapshot({
    required String userId,
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
  }) async {
    var state = await _getSyncState(userId);
    var snapshotId = state?.snapshotId;
    var pageToken = state?.snapshotPageToken;
    var total = 0;

    while (true) {
      final page = await _syncClient.snapshot(
        baseUrl: baseUrl,
        accessToken: accessToken,
        client: client,
        snapshotId: snapshotId,
        pageToken: pageToken,
        entityTypes: syncEntityTypes,
        pageSize: _snapshotPageSize,
      );

      await database.transaction(() async {
        for (final item in page.items) {
          if (!syncEntityTypes.contains(item.entityType)) continue;
          final localChange = await _firstOutboxForEntity(
            userId,
            item.entityType,
            item.entityId,
          );
          if (localChange != null) continue;

          switch (item.entityType) {
            case DriftTaskRepository.entityType:
              final task = TaskWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
              );
              await database
                  .into(database.tasks)
                  .insertOnConflictUpdate(TaskDatabaseMapper.toRow(task));
            case DriftProjectRepository.entityType:
              final project = ProjectWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
              );
              await database
                  .into(database.projects)
                  .insertOnConflictUpdate(ProjectDatabaseMapper.toRow(project));
            case DriftCalendarEventRepository.entityType:
              final event = CalendarEventWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
              );
              await database
                  .into(database.calendarEvents)
                  .insertOnConflictUpdate(
                    CalendarEventDatabaseMapper.toRow(event),
                  );
            case DriftImportantDateRepository.entityType:
              final importantDate = ImportantDateWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
                serverModifiedAt: page.serverTime,
              );
              await database
                  .into(database.importantDates)
                  .insertOnConflictUpdate(
                    ImportantDateDatabaseMapper.toRow(importantDate),
                  );
            case DriftMemoRepository.entityType:
              final memo = MemoWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
              );
              await database
                  .into(database.memos)
                  .insertOnConflictUpdate(MemoDatabaseMapper.toRow(memo));
            case DriftReminderRepository.entityType:
              final reminder = ReminderWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
              );
              await database
                  .into(database.reminders)
                  .insertOnConflictUpdate(ReminderDatabaseMapper.toRow(reminder));
            case DriftDailyReviewRepository.entityType:
              final review = DailyReviewWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
              );
              await database
                  .into(database.dailyReviews)
                  .insertOnConflictUpdate(
                    DailyReviewDatabaseMapper.toRow(review),
                  );
            case DriftFileMetadataRepository.entityType:
              final file = FileMetadataWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
              );
              await database
                  .into(database.fileRecords)
                  .insertOnConflictUpdate(FileMetadataDatabaseMapper.toRow(file));
            case DriftEntityLinkRepository.entityType:
              final link = EntityLinkWireMapper.fromPayload(
                item.payload,
                serverVersion: item.serverVersion,
              );
              await database.into(database.entityLinks).insertOnConflictUpdate(
                    EntityLinkDatabaseMapper.toRow(link),
                  );
          }
        }

        await database.into(database.syncState).insertOnConflictUpdate(
              db.SyncStateCompanion.insert(
                scope: taskScopeKey,
                userId: userId,
                cursor: Value(page.completed ? page.snapshotCursor : null),
                updatedAt: page.serverTime,
                snapshotId: Value(page.completed ? null : page.snapshotId),
                snapshotPageToken:
                    Value(page.completed ? null : page.nextPageToken),
                snapshotCursor:
                    Value(page.completed ? null : page.snapshotCursor),
              ),
            );
      });

      total += page.items.length;
      if (page.completed) return total;
      if (page.nextPageToken == null || page.nextPageToken!.isEmpty) {
        throw const FormatException(
          'LifeTrace Cloud snapshot 未完成但缺少 nextPageToken',
        );
      }
      snapshotId = page.snapshotId;
      pageToken = page.nextPageToken;
      state = await _getSyncState(userId);
      snapshotId = state?.snapshotId ?? snapshotId;
      pageToken = state?.snapshotPageToken ?? pageToken;
    }
  }

  Future<_PushRoundResult> _pushOneRound({
    required String userId,
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
  }) async {
    final pending = await (database.select(database.syncOutbox)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.entityType.isIn(syncEntityTypes) &
                table.blocked.equals(false),
          )
          ..orderBy([
            (table) => OrderingTerm.asc(table.createdAt),
            (table) => OrderingTerm.asc(table.changeId),
          ]))
        .get();

    final seen = <String>{};
    final heads = pending
        .where((row) => seen.add('${row.entityType}:${row.entityId}'))
        .take(_pushBatchSize)
        .toList(growable: false);
    if (heads.isEmpty) return const _PushRoundResult(hadWork: false);

    await database.transaction(() async {
      for (final item in heads) {
        await database.customUpdate(
          'UPDATE sync_outbox '
          'SET attempt_count = attempt_count + 1, error_code = NULL, error_message = NULL '
          'WHERE change_id = ?',
          variables: [Variable.withString(item.changeId)],
          updates: {database.syncOutbox},
        );
      }
    });

    PushBatchResult response;
    try {
      response = await _syncClient.push(
        baseUrl: baseUrl,
        accessToken: accessToken,
        client: client,
        changes: heads
            .map(
              (item) => OutgoingSyncChange(
                changeId: item.changeId,
                entityType: item.entityType,
                entityId: item.entityId,
                operation: item.operation,
                baseServerVersion: item.baseServerVersion,
                entitySchemaVersion: item.entitySchemaVersion,
                clientModifiedAt: item.clientModifiedAt,
                payload: _decodeObject(item.payloadJson),
                atomicGroupId: item.atomicGroupId,
                dependencies: _decodeDependencies(item.dependenciesJson),
              ),
            )
            .toList(growable: false),
      );
    } catch (error) {
      final code = error is CloudApiException ? error.code : null;
      await database.transaction(() async {
        for (final item in heads) {
          await (database.update(database.syncOutbox)
                ..where((table) => table.changeId.equals(item.changeId)))
              .write(
            db.SyncOutboxCompanion(
              errorCode: Value(code),
              errorMessage: Value(error.toString()),
            ),
          );
        }
      });
      rethrow;
    }

    var accepted = 0;
    var conflicts = 0;
    var rejected = 0;
    for (final result in response.results) {
      switch (result) {
        case PushAccepted():
          accepted++;
          await _handleAccepted(userId, result);
        case PushConflict():
          conflicts++;
          await _handleConflict(userId, result);
        case PushRejected():
          rejected++;
          await (database.update(database.syncOutbox)
                ..where((table) => table.changeId.equals(result.changeId)))
              .write(
            db.SyncOutboxCompanion(
              blocked: const Value(true),
              errorCode: Value(result.code),
              errorMessage: Value(result.message),
            ),
          );
      }
    }

    return _PushRoundResult(
      hadWork: true,
      accepted: accepted,
      conflicts: conflicts,
      rejected: rejected,
    );
  }

  Future<void> _handleAccepted(String userId, PushAccepted result) async {
    await database.transaction(() async {
      switch (result.entityType) {
        case DriftTaskRepository.entityType:
          await (database.update(database.tasks)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.TasksCompanion(serverVersion: Value(result.serverVersion)),
          );
        case DriftProjectRepository.entityType:
          await (database.update(database.projects)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.ProjectsCompanion(serverVersion: Value(result.serverVersion)),
          );
        case DriftCalendarEventRepository.entityType:
          await (database.update(database.calendarEvents)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.CalendarEventsCompanion(
              serverVersion: Value(result.serverVersion),
            ),
          );
        case DriftImportantDateRepository.entityType:
          await (database.update(database.importantDates)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.ImportantDatesCompanion(
              serverVersion: Value(result.serverVersion),
            ),
          );
        case DriftMemoRepository.entityType:
          await (database.update(database.memos)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.MemosCompanion(serverVersion: Value(result.serverVersion)),
          );
        case DriftReminderRepository.entityType:
          await (database.update(database.reminders)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.RemindersCompanion(serverVersion: Value(result.serverVersion)),
          );
        case DriftDailyReviewRepository.entityType:
          await (database.update(database.dailyReviews)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.DailyReviewsCompanion(
              serverVersion: Value(result.serverVersion),
            ),
          );
        case DriftFileMetadataRepository.entityType:
          await (database.update(database.fileRecords)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.FileRecordsCompanion(
              serverVersion: Value(result.serverVersion),
            ),
          );
        case DriftEntityLinkRepository.entityType:
          await (database.update(database.entityLinks)
                ..where(
                  (table) =>
                      table.userId.equals(userId) &
                      table.id.equals(result.entityId),
                ))
              .write(
            db.EntityLinksCompanion(serverVersion: Value(result.serverVersion)),
          );
      }
      await (database.delete(database.syncOutbox)
            ..where((table) => table.changeId.equals(result.changeId)))
          .go();

      final next = await _firstOutboxForEntity(
        userId,
        result.entityType,
        result.entityId,
      );
      if (next == null || next.blocked || next.attemptCount != 0) return;

      String? payloadJson = next.payloadJson;
      if (next.operation == 'upsert') {
        switch (next.entityType) {
          case DriftTaskRepository.entityType:
            final row = await (database.select(database.tasks)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = TaskDatabaseMapper.fromRow(row).copyWith(
                serverVersion: result.serverVersion,
              );
              payloadJson = jsonEncode(TaskWireMapper.toPayload(current));
            }
          case DriftProjectRepository.entityType:
            final row = await (database.select(database.projects)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = ProjectDatabaseMapper.fromRow(row).copyWith(
                serverVersion: result.serverVersion,
              );
              payloadJson = jsonEncode(ProjectWireMapper.toPayload(current));
            }
          case DriftCalendarEventRepository.entityType:
            final row = await (database.select(database.calendarEvents)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = CalendarEventDatabaseMapper.fromRow(row).copyWith(
                serverVersion: result.serverVersion,
              );
              payloadJson = jsonEncode(
                CalendarEventWireMapper.toPayload(current),
              );
            }
          case DriftImportantDateRepository.entityType:
            final row = await (database.select(database.importantDates)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = ImportantDateDatabaseMapper.fromRow(row).copyWith(
                serverVersion: result.serverVersion,
              );
              payloadJson =
                  jsonEncode(ImportantDateWireMapper.toPayload(current));
            }
          case DriftMemoRepository.entityType:
            final row = await (database.select(database.memos)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = MemoDatabaseMapper.fromRow(row).copyWith(
                serverVersion: result.serverVersion,
              );
              payloadJson = jsonEncode(MemoWireMapper.toPayload(current));
            }
          case DriftReminderRepository.entityType:
            final row = await (database.select(database.reminders)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = ReminderDatabaseMapper.fromRow(row).copyWith(
                serverVersion: result.serverVersion,
              );
              payloadJson = jsonEncode(ReminderWireMapper.toPayload(current));
            }
          case DriftDailyReviewRepository.entityType:
            final row = await (database.select(database.dailyReviews)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = DailyReviewDatabaseMapper.fromRow(row).copyWith(
                serverVersion: result.serverVersion,
              );
              payloadJson =
                  jsonEncode(DailyReviewWireMapper.toPayload(current));
            }
          case DriftFileMetadataRepository.entityType:
            final row = await (database.select(database.fileRecords)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = FileMetadataDatabaseMapper.fromRow(row).copyWith(
                serverVersion: result.serverVersion,
              );
              payloadJson = jsonEncode(
                FileMetadataWireMapper.toPayload(current),
              );
            }
          case DriftEntityLinkRepository.entityType:
            final row = await (database.select(database.entityLinks)
                  ..where(
                    (table) =>
                        table.userId.equals(userId) &
                        table.id.equals(result.entityId),
                  ))
                .getSingleOrNull();
            if (row != null) {
              final current = EntityLinkDatabaseMapper.fromRow(row);
              final rebased = ExecutionEntityLink(
                id: current.id,
                userId: current.userId,
                sourceType: current.sourceType,
                sourceId: current.sourceId,
                targetType: current.targetType,
                targetId: current.targetId,
                relationType: current.relationType,
                metadata: current.metadata,
                createdAt: current.createdAt,
                updatedAt: current.updatedAt,
                localVersion: current.localVersion,
                serverVersion: result.serverVersion,
                modifiedByDevice: current.modifiedByDevice,
              );
              payloadJson = jsonEncode(EntityLinkWireMapper.toPayload(rebased));
            }
        }
      }

      await (database.update(database.syncOutbox)
            ..where(
              (table) =>
                  table.changeId.equals(next.changeId) &
                  table.attemptCount.equals(0),
            ))
          .write(
        db.SyncOutboxCompanion(
          baseServerVersion: Value(result.serverVersion),
          payloadJson: Value(payloadJson),
        ),
      );
    });
  }

  Future<void> _handleConflict(String userId, PushConflict result) async {
    final matchingOutbox = await (database.select(database.syncOutbox)
          ..where((table) => table.changeId.equals(result.changeId)))
        .getSingleOrNull();
    final now = DateTime.now().toUtc().toIso8601String();

    await database.transaction(() async {
      await database.into(database.syncConflicts).insertOnConflictUpdate(
            db.SyncConflictsCompanion.insert(
              id: result.conflictId,
              userId: userId,
              entityType: result.entityType,
              entityId: result.entityId,
              createdAt: now,
              changeId: Value(result.changeId),
              clientBaseServerVersion:
                  Value(result.clientBaseServerVersion),
              localPayloadJson: Value(matchingOutbox?.payloadJson),
              serverPayloadJson: Value(
                result.serverEntity == null
                    ? null
                    : jsonEncode(result.serverEntity),
              ),
              serverVersion: Value(result.currentServerVersion),
              serverDeleted: Value(result.serverDeleted),
              reason: Value(result.reason),
              resolved: const Value(false),
            ),
          );

      await (database.update(database.syncOutbox)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.entityType.equals(result.entityType) &
                  table.entityId.equals(result.entityId),
            ))
          .write(
        db.SyncOutboxCompanion(
          blocked: const Value(true),
          errorCode: const Value('SYNC_CONFLICT'),
          errorMessage: Value(result.reason),
        ),
      );
    });
  }

  Future<int> _pullUntilCurrent({
    required String userId,
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required String? afterCursor,
  }) async {
    var cursor = (await _getSyncState(userId))?.cursor ?? afterCursor;
    var total = 0;

    while (true) {
      final batch = await _syncClient.pull(
        baseUrl: baseUrl,
        accessToken: accessToken,
        client: client,
        afterCursor: cursor,
        limit: _pullBatchSize,
        entityTypes: syncEntityTypes,
      );

      await database.transaction(() async {
        for (final change in batch.changes) {
          if (!syncEntityTypes.contains(change.entityType)) continue;
          final localChange = await _firstOutboxForEntity(
            userId,
            change.entityType,
            change.entityId,
          );
          if (localChange != null) continue;

          switch (change.operation) {
            case 'upsert':
              final payload = change.payload;
              if (payload == null) {
                throw FormatException(
                  '${change.entityType} upsert pull 缺少 payload',
                );
              }
              switch (change.entityType) {
                case DriftTaskRepository.entityType:
                  final task = TaskWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                  );
                  await database
                      .into(database.tasks)
                      .insertOnConflictUpdate(TaskDatabaseMapper.toRow(task));
                case DriftProjectRepository.entityType:
                  final project = ProjectWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                  );
                  await database.into(database.projects).insertOnConflictUpdate(
                        ProjectDatabaseMapper.toRow(project),
                      );
                case DriftCalendarEventRepository.entityType:
                  final event = CalendarEventWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                  );
                  await database
                      .into(database.calendarEvents)
                      .insertOnConflictUpdate(
                        CalendarEventDatabaseMapper.toRow(event),
                      );
                case DriftImportantDateRepository.entityType:
                  final importantDate = ImportantDateWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                    serverModifiedAt: change.serverModifiedAt,
                  );
                  await database
                      .into(database.importantDates)
                      .insertOnConflictUpdate(
                        ImportantDateDatabaseMapper.toRow(importantDate),
                      );
                case DriftMemoRepository.entityType:
                  final memo = MemoWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                  );
                  await database.into(database.memos).insertOnConflictUpdate(
                        MemoDatabaseMapper.toRow(memo),
                      );
                case DriftReminderRepository.entityType:
                  final reminder = ReminderWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                  );
                  await database.into(database.reminders).insertOnConflictUpdate(
                        ReminderDatabaseMapper.toRow(reminder),
                      );
                case DriftDailyReviewRepository.entityType:
                  final review = DailyReviewWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                  );
                  await database
                      .into(database.dailyReviews)
                      .insertOnConflictUpdate(
                        DailyReviewDatabaseMapper.toRow(review),
                      );
                case DriftFileMetadataRepository.entityType:
                  final file = FileMetadataWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                  );
                  await database
                      .into(database.fileRecords)
                      .insertOnConflictUpdate(
                        FileMetadataDatabaseMapper.toRow(file),
                      );
                case DriftEntityLinkRepository.entityType:
                  final link = EntityLinkWireMapper.fromPayload(
                    payload,
                    serverVersion: change.serverVersion,
                  );
                  await database.into(database.entityLinks).insertOnConflictUpdate(
                        EntityLinkDatabaseMapper.toRow(link),
                      );
              }
            case 'delete':
              switch (change.entityType) {
                case DriftTaskRepository.entityType:
                  await (database.delete(database.tasks)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
                case DriftProjectRepository.entityType:
                  await (database.delete(database.projects)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
                case DriftCalendarEventRepository.entityType:
                  await (database.delete(database.calendarEvents)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
                case DriftImportantDateRepository.entityType:
                  await (database.delete(database.importantDates)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
                case DriftMemoRepository.entityType:
                  await (database.delete(database.memos)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
                case DriftReminderRepository.entityType:
                  await (database.delete(database.reminders)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
                case DriftDailyReviewRepository.entityType:
                  await (database.delete(database.dailyReviews)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
                case DriftFileMetadataRepository.entityType:
                  await (database.delete(database.fileRecords)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
                case DriftEntityLinkRepository.entityType:
                  await (database.delete(database.entityLinks)
                        ..where(
                          (table) =>
                              table.userId.equals(userId) &
                              table.id.equals(change.entityId),
                        ))
                      .go();
              }
            default:
              throw FormatException(
                'Unsupported execution pull operation: ${change.operation}',
              );
          }
        }

        await database.into(database.syncState).insertOnConflictUpdate(
              db.SyncStateCompanion.insert(
                scope: taskScopeKey,
                userId: userId,
                cursor: Value(batch.nextCursor),
                updatedAt: batch.serverTime,
                snapshotId: const Value(null),
                snapshotPageToken: const Value(null),
                snapshotCursor: const Value(null),
              ),
            );
      });

      total += batch.changes.length;
      if (!batch.hasMore) return total;
      if (batch.nextCursor == cursor) {
        throw const FormatException(
          'LifeTrace Cloud pull hasMore=true 但 cursor 未推进',
        );
      }
      cursor = batch.nextCursor;
    }
  }

  Future<db.SyncStateData?> _getSyncState(String userId) {
    return (database.select(database.syncState)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.scope.equals(taskScopeKey),
          ))
        .getSingleOrNull();
  }

  Future<db.SyncOutboxData?> _firstOutboxForEntity(
    String userId,
    String entityType,
    String entityId,
  ) {
    return (database.select(database.syncOutbox)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.entityType.equals(entityType) &
                table.entityId.equals(entityId),
          )
          ..orderBy([
            (table) => OrderingTerm.asc(table.createdAt),
            (table) => OrderingTerm.asc(table.changeId),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  static List<SyncEntityRef> _decodeDependencies(String raw) {
    final value = jsonDecode(raw);
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => SyncEntityRef(
            entityType: item['entityType']?.toString() ?? '',
            entityId: item['entityId']?.toString() ?? '',
          ),
        )
        .where((item) => item.entityType.isNotEmpty && item.entityId.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic>? _decodeObject(String? raw) {
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('sync payload must be a JSON object');
  }
}

class _PushRoundResult {
  const _PushRoundResult({
    required this.hadWork,
    this.accepted = 0,
    this.conflicts = 0,
    this.rejected = 0,
  });

  final bool hadWork;
  final int accepted;
  final int conflicts;
  final int rejected;
}
