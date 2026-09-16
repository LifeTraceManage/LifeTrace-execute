import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/calendar_event_repository.dart';
import '../../data/repository/daily_review_repository.dart';
import '../../data/repository/entity_link_repository.dart';
import '../../data/repository/file_metadata_repository.dart';
import '../../data/repository/focus_repository.dart';
import '../../data/repository/goal_repository.dart';
import '../../data/repository/habit_repository.dart';
import '../../data/repository/important_date_repository.dart';
import '../../data/repository/memo_repository.dart';
import '../../data/repository/project_repository.dart';
import '../../data/repository/reminder_repository.dart';
import '../../data/repository/task_repository.dart';
import '../../data/repository/weekly_review_repository.dart';
import '../../data/sync/task_sync_coordinator.dart';
import '../calendar/calendar_providers.dart';
import '../collection/collection_providers.dart';
import '../focus/focus_providers.dart';
import '../goals/goal_providers.dart';
import '../habits/habit_providers.dart';
import '../important_dates/important_date_providers.dart';
import '../projects/project_providers.dart';
import '../reminders/reminder_providers.dart';
import '../review/review_providers.dart';
import '../tasks/task_providers.dart';

class SyncConflictCenterItem {
  const SyncConflictCenterItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.serverDeleted,
    required this.createdAt,
    this.localTitle,
    this.serverTitle,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String reason;
  final bool serverDeleted;
  final String createdAt;
  final String? localTitle;
  final String? serverTitle;
}

final syncConflictCenterProvider =
    StreamProvider<List<SyncConflictCenterItem>>((ref) async* {
  if (kIsWeb) {
    yield const <SyncConflictCenterItem>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <SyncConflictCenterItem>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) & table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => SyncConflictCenterItem(
                id: row.id,
                entityType: row.entityType,
                entityId: row.entityId,
                reason: row.reason,
                serverDeleted: row.serverDeleted,
                createdAt: row.createdAt,
                localTitle: _payloadLabel(row.localPayloadJson),
                serverTitle: _payloadLabel(row.serverPayloadJson),
              ),
            )
            .toList(growable: false),
      );
});

final syncHealthCommandsProvider =
    Provider<SyncHealthCommands>(SyncHealthCommands.new);

class SyncHealthCommands {
  SyncHealthCommands(this.ref);

  final Ref ref;

  Future<void> resolve(
    SyncConflictCenterItem item, {
    required bool keepLocal,
  }) async {
    switch (item.entityType) {
      case DriftTaskRepository.entityType:
        final controller = ref.read(taskSyncControllerProvider.notifier);
        if (keepLocal) {
          await controller.keepLocal(item.id);
        } else {
          await controller.keepServer(item.id);
        }
      case DriftProjectRepository.entityType:
        final commands = ref.read(projectCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      case DriftGoalRepository.entityType:
        final commands = ref.read(goalCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      case DriftCalendarEventRepository.entityType:
        final commands = ref.read(calendarCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      case DriftImportantDateRepository.entityType:
        final commands = ref.read(importantDateCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(
            ImportantDateConflictUi(
              conflictId: item.id,
              importantDateId: item.entityId,
              reason: item.reason,
              serverDeleted: item.serverDeleted,
            ),
          );
        }
      case DriftFocusRepository.entityType:
        final commands = ref.read(focusCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      case DriftMemoRepository.entityType:
      case DriftFileMetadataRepository.entityType:
      case DriftEntityLinkRepository.entityType:
        final commands = ref.read(collectionCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      case DriftReminderRepository.entityType:
        final commands = ref.read(reminderCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      case DriftDailyReviewRepository.entityType:
        final commands = ref.read(dailyReviewCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      case DriftWeeklyReviewRepository.entityType:
        final commands = ref.read(weeklyReviewCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      case DriftHabitRepository.activityEntityType:
      case DriftHabitRepository.logEntityType:
        final commands = ref.read(habitCommandsProvider);
        if (keepLocal) {
          await commands.keepLocal(item.id);
        } else {
          await commands.keepServer(item.id);
        }
      default:
        throw StateError('暂不支持该冲突类型：${item.entityType}');
    }
  }

  Future<TaskSyncSummary?> syncNow() =>
      ref.read(taskSyncControllerProvider.notifier).syncNow();

  Future<TaskSyncSummary?> rebuildSnapshotBaseline() =>
      ref.read(taskSyncControllerProvider.notifier).rebuildSnapshotBaseline();
}

String? _payloadLabel(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    for (final key in const [
      'title',
      'name',
      'content',
      'reviewDate',
      'weekStart',
    ]) {
      final text = value[key]?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text.length <= 72 ? text : '${text.substring(0, 72)}…';
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

String syncEntityLabel(String entityType) => switch (entityType) {
      DriftTaskRepository.entityType => '任务',
      DriftProjectRepository.entityType => '项目',
      DriftGoalRepository.entityType => '目标',
      DriftCalendarEventRepository.entityType => '日程',
      DriftImportantDateRepository.entityType => '重要日期',
      DriftFocusRepository.entityType => '专注记录',
      DriftMemoRepository.entityType => '收集',
      DriftFileMetadataRepository.entityType => '文件',
      DriftEntityLinkRepository.entityType => '关联',
      DriftReminderRepository.entityType => '提醒',
      DriftDailyReviewRepository.entityType => '每日复盘',
      DriftWeeklyReviewRepository.entityType => '每周复盘',
      DriftHabitRepository.activityEntityType => '习惯',
      DriftHabitRepository.logEntityType => '习惯记录',
      _ => entityType,
    };
