import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

const conflictCenterSupportedEntityTypes = <String>{
  'execution.task',
  'execution.project',
  'execution.goal',
  'execution.calendar_event',
  'execution.important_date',
  'execution.focus_session',
  'execution.weekly_review',
  'execution.memo',
  'execution.reminder',
  'review.daily',
  'habit.activity',
  'habit.log',
  'file.metadata',
  'entity.link',
};

class ProfileConflictItem {
  const ProfileConflictItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.serverDeleted,
    required this.createdAt,
    this.changeId,
    this.serverVersion,
    this.localSummary,
    this.serverSummary,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String reason;
  final bool serverDeleted;
  final String createdAt;
  final String? changeId;
  final String? serverVersion;
  final String? localSummary;
  final String? serverSummary;
}

final syncConflictCenterProvider =
    StreamProvider<List<ProfileConflictItem>>((ref) async* {
  if (kIsWeb) {
    yield const <ProfileConflictItem>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <ProfileConflictItem>[];
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
              (row) => ProfileConflictItem(
                id: row.id,
                entityType: row.entityType,
                entityId: row.entityId,
                reason: row.reason,
                serverDeleted: row.serverDeleted,
                createdAt: row.createdAt,
                changeId: row.changeId,
                serverVersion: row.serverVersion,
                localSummary: _payloadSummary(row.localPayloadJson),
                serverSummary:
                    row.serverDeleted ? null : _payloadSummary(row.serverPayloadJson),
              ),
            )
            .toList(growable: false),
      );
});

final profileConflictCommandsProvider =
    Provider<ProfileConflictCommands>(ProfileConflictCommands.new);

class ProfileConflictCommands {
  ProfileConflictCommands(this.ref);

  final Ref ref;

  Future<void> keepServer(ProfileConflictItem conflict) async {
    switch (conflict.entityType) {
      case 'execution.task':
        await ref
            .read(taskSyncControllerProvider.notifier)
            .keepServer(conflict.id);
      case 'execution.project':
        await ref.read(projectCommandsProvider).keepServer(conflict.id);
      case 'execution.goal':
        await ref.read(goalCommandsProvider).keepServer(conflict.id);
      case 'execution.calendar_event':
        await ref.read(calendarCommandsProvider).keepServer(conflict.id);
      case 'execution.important_date':
        await ref.read(importantDateCommandsProvider).keepServer(
              ImportantDateConflictUi(
                conflictId: conflict.id,
                importantDateId: conflict.entityId,
                reason: conflict.reason,
                serverDeleted: conflict.serverDeleted,
              ),
            );
      case 'execution.focus_session':
        await ref.read(focusCommandsProvider).keepServer(conflict.id);
      case 'execution.weekly_review':
        await ref.read(weeklyReviewCommandsProvider).keepServer(conflict.id);
      case 'execution.memo':
      case 'file.metadata':
      case 'entity.link':
        await ref.read(collectionCommandsProvider).keepServer(conflict.id);
      case 'execution.reminder':
        await ref.read(reminderCommandsProvider).keepServer(conflict.id);
      case 'review.daily':
        await ref.read(dailyReviewCommandsProvider).keepServer(conflict.id);
      case 'habit.activity':
      case 'habit.log':
        await ref.read(habitCommandsProvider).keepServer(conflict.id);
      default:
        throw StateError('暂不支持处理冲突类型：${conflict.entityType}');
    }
  }

  Future<void> keepLocal(ProfileConflictItem conflict) async {
    switch (conflict.entityType) {
      case 'execution.task':
        await ref
            .read(taskSyncControllerProvider.notifier)
            .keepLocal(conflict.id);
      case 'execution.project':
        await ref.read(projectCommandsProvider).keepLocal(conflict.id);
      case 'execution.goal':
        await ref.read(goalCommandsProvider).keepLocal(conflict.id);
      case 'execution.calendar_event':
        await ref.read(calendarCommandsProvider).keepLocal(conflict.id);
      case 'execution.important_date':
        await ref.read(importantDateCommandsProvider).keepLocal(conflict.id);
      case 'execution.focus_session':
        await ref.read(focusCommandsProvider).keepLocal(conflict.id);
      case 'execution.weekly_review':
        await ref.read(weeklyReviewCommandsProvider).keepLocal(conflict.id);
      case 'execution.memo':
      case 'file.metadata':
      case 'entity.link':
        await ref.read(collectionCommandsProvider).keepLocal(conflict.id);
      case 'execution.reminder':
        await ref.read(reminderCommandsProvider).keepLocal(conflict.id);
      case 'review.daily':
        await ref.read(dailyReviewCommandsProvider).keepLocal(conflict.id);
      case 'habit.activity':
      case 'habit.log':
        await ref.read(habitCommandsProvider).keepLocal(conflict.id);
      default:
        throw StateError('暂不支持处理冲突类型：${conflict.entityType}');
    }
  }
}

String conflictEntityLabel(String entityType) => switch (entityType) {
      'execution.task' => '任务',
      'execution.project' => '项目',
      'execution.goal' => '目标',
      'execution.calendar_event' => '日程',
      'execution.important_date' => '重要日期',
      'execution.focus_session' => '专注记录',
      'execution.weekly_review' => '周复盘',
      'execution.memo' => '收集内容',
      'execution.reminder' => '提醒',
      'review.daily' => '每日复盘',
      'habit.activity' => '习惯',
      'habit.log' => '习惯记录',
      'file.metadata' => '文件',
      'entity.link' => '实体关联',
      _ => entityType,
    };

String? _payloadSummary(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    for (final key in [
      'title',
      'name',
      'content',
      'reviewDate',
      'weekStart',
      'date',
      'subjectType',
    ]) {
      final value = decoded[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value.length > 80 ? '${value.substring(0, 80)}…' : value;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}
