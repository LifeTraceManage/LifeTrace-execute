import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/review/weekly_review.dart';
import '../local/app_database.dart' as db;

abstract final class WeeklyReviewDatabaseMapper {
  static db.WeeklyReview toRow(WeeklyReview review) => db.WeeklyReview(
        id: review.id,
        userId: review.userId,
        weekStart: review.weekStart,
        weekEnd: review.weekEnd,
        completionScore: review.completionScore,
        completedTaskCount: review.completedTaskCount,
        totalTaskCount: review.totalTaskCount,
        focusSeconds: review.focusSeconds,
        completionSummary: review.completionSummary,
        bestThing: review.bestThing,
        problem: review.problem,
        improvement: review.improvement,
        nextWeekPriority: review.nextWeekPriority,
        note: review.note,
        createdAt: review.createdAt,
        updatedAt: review.updatedAt,
        localVersion: review.localVersion,
        serverVersion: review.serverVersion,
        modifiedByDevice: review.modifiedByDevice,
      );

  static WeeklyReview fromRow(db.WeeklyReview row) => WeeklyReview(
        id: row.id,
        userId: row.userId,
        weekStart: row.weekStart,
        weekEnd: row.weekEnd,
        completionScore: row.completionScore,
        completedTaskCount: row.completedTaskCount,
        totalTaskCount: row.totalTaskCount,
        focusSeconds: row.focusSeconds,
        completionSummary: row.completionSummary,
        bestThing: row.bestThing,
        problem: row.problem,
        improvement: row.improvement,
        nextWeekPriority: row.nextWeekPriority,
        note: row.note,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class WeeklyReviewWireMapper {
  static Map<String, dynamic> toPayload(WeeklyReview review) => {
        'meta': {
          'id': review.id,
          'userId': review.userId,
          'createdAt': review.createdAt,
          'updatedAt': review.updatedAt,
          'deletedAt': null,
          'localVersion': review.localVersion,
          'serverVersion': review.serverVersion,
          'modifiedByDevice': review.modifiedByDevice,
        },
        'weekStart': review.weekStart,
        'weekEnd': review.weekEnd,
        'completionScore': review.completionScore,
        'completedTaskCount': review.completedTaskCount,
        'totalTaskCount': review.totalTaskCount,
        'focusSeconds': review.focusSeconds,
        'completionSummary': review.completionSummary,
        'bestThing': review.bestThing,
        'problem': review.problem,
        'improvement': review.improvement,
        'nextWeekPriority': review.nextWeekPriority,
        'note': review.note,
      };

  static WeeklyReview fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta'], 'meta');
    final review = WeeklyReview(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      weekStart: _requiredString(payload, 'weekStart'),
      weekEnd: _requiredString(payload, 'weekEnd'),
      completionScore: _double(payload['completionScore']),
      completedTaskCount: _int(payload['completedTaskCount']),
      totalTaskCount: _int(payload['totalTaskCount']),
      focusSeconds: _int(payload['focusSeconds']),
      completionSummary: _nullableString(payload['completionSummary']),
      bestThing: _nullableString(payload['bestThing']),
      problem: _nullableString(payload['problem']),
      improvement: _nullableString(payload['improvement']),
      nextWeekPriority: _nullableString(payload['nextWeekPriority']),
      note: _nullableString(payload['note']),
      createdAt: _requiredString(meta, 'createdAt'),
      updatedAt: _requiredString(meta, 'updatedAt'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
    _validateWeeklyReview(review);
    return review;
  }

  static Map<String, dynamic> _map(Object? value, String name) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('WeeklyReview $name must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) {
      throw FormatException('WeeklyReview payload is missing $name');
    }
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

abstract interface class WeeklyReviewRepository {
  Stream<List<WeeklyReview>> watchReviews(String userId);

  Stream<WeeklyReview?> watchReviewForWeek({
    required String userId,
    required String weekStart,
  });

  Future<WeeklyReview> saveReview({
    required String userId,
    required String deviceId,
    required String weekStart,
    required String weekEnd,
    double? completionScore,
    int? completedTaskCount,
    int? totalTaskCount,
    int? focusSeconds,
    String? completionSummary,
    String? bestThing,
    String? problem,
    String? improvement,
    String? nextWeekPriority,
    String? note,
  });

  Future<void> deleteReview({
    required String userId,
    required String reviewId,
  });
}

class DriftWeeklyReviewRepository implements WeeklyReviewRepository {
  DriftWeeklyReviewRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const entityType = 'execution.weekly_review';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<WeeklyReview>> watchReviews(String userId) {
    final query = database.select(database.weeklyReviews)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm.desc(table.weekStart),
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    return query.watch().map(
          (rows) => rows
              .map(WeeklyReviewDatabaseMapper.fromRow)
              .toList(growable: false),
        );
  }

  @override
  Stream<WeeklyReview?> watchReviewForWeek({
    required String userId,
    required String weekStart,
  }) {
    final query = database.select(database.weeklyReviews)
      ..where(
        (table) =>
            table.userId.equals(userId) &
            table.weekStart.equals(weekStart),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])
      ..limit(1);
    return query.watch().map(
          (rows) => rows.isEmpty
              ? null
              : WeeklyReviewDatabaseMapper.fromRow(rows.first),
        );
  }

  @override
  Future<WeeklyReview> saveReview({
    required String userId,
    required String deviceId,
    required String weekStart,
    required String weekEnd,
    double? completionScore,
    int? completedTaskCount,
    int? totalTaskCount,
    int? focusSeconds,
    String? completionSummary,
    String? bestThing,
    String? problem,
    String? improvement,
    String? nextWeekPriority,
    String? note,
  }) async {
    _validateWeek(weekStart, weekEnd);
    _validateStats(
      completionScore: completionScore,
      completedTaskCount: completedTaskCount,
      totalTaskCount: totalTaskCount,
      focusSeconds: focusSeconds,
    );

    final existing = await (database.select(database.weeklyReviews)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.weekStart.equals(weekStart),
          )
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])
          ..limit(1))
        .getSingleOrNull();

    final now = DateTime.now().toUtc().toIso8601String();
    final review = WeeklyReview(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      weekStart: weekStart,
      weekEnd: weekEnd,
      completionScore: completionScore,
      completedTaskCount: completedTaskCount,
      totalTaskCount: totalTaskCount,
      focusSeconds: focusSeconds,
      completionSummary: _clean(completionSummary),
      bestThing: _clean(bestThing),
      problem: _clean(problem),
      improvement: _clean(improvement),
      nextWeekPriority: _clean(nextWeekPriority),
      note: _clean(note),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      localVersion: (existing?.localVersion ?? 0) + 1,
      serverVersion: existing?.serverVersion,
      modifiedByDevice: deviceId,
    );

    _validateWeeklyReview(review);
    await database.transaction(() async {
      await database
          .into(database.weeklyReviews)
          .insertOnConflictUpdate(WeeklyReviewDatabaseMapper.toRow(review));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: userId,
              entityType: entityType,
              entityId: review.id,
              operation: 'upsert',
              baseServerVersion: review.serverVersion ?? '0',
              clientModifiedAt: review.updatedAt,
              payloadJson: Value(
                jsonEncode(WeeklyReviewWireMapper.toPayload(review)),
              ),
              createdAt: review.updatedAt,
            ),
          );
    });
    return review;
  }

  @override
  Future<void> deleteReview({
    required String userId,
    required String reviewId,
  }) async {
    final existing = await (database.select(database.weeklyReviews)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.id.equals(reviewId),
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
              entityId: reviewId,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.weeklyReviews)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.id.equals(reviewId),
            ))
          .go();
    });
  }
}

class PreviewWeeklyReviewRepository implements WeeklyReviewRepository {
  final List<WeeklyReview> _items = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<WeeklyReview>> watchReviews(String userId) async* {
    List<WeeklyReview> snapshot() => _items
        .where((item) => item.userId == userId)
        .toList(growable: false)
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Stream<WeeklyReview?> watchReviewForWeek({
    required String userId,
    required String weekStart,
  }) async* {
    WeeklyReview? snapshot() {
      for (final item in _items.reversed) {
        if (item.userId == userId && item.weekStart == weekStart) return item;
      }
      return null;
    }

    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<WeeklyReview> saveReview({
    required String userId,
    required String deviceId,
    required String weekStart,
    required String weekEnd,
    double? completionScore,
    int? completedTaskCount,
    int? totalTaskCount,
    int? focusSeconds,
    String? completionSummary,
    String? bestThing,
    String? problem,
    String? improvement,
    String? nextWeekPriority,
    String? note,
  }) async {
    _validateWeek(weekStart, weekEnd);
    _validateStats(
      completionScore: completionScore,
      completedTaskCount: completedTaskCount,
      totalTaskCount: totalTaskCount,
      focusSeconds: focusSeconds,
    );

    WeeklyReview? existing;
    for (final item in _items.reversed) {
      if (item.userId == userId && item.weekStart == weekStart) {
        existing = item;
        break;
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final review = WeeklyReview(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      weekStart: weekStart,
      weekEnd: weekEnd,
      completionScore: completionScore,
      completedTaskCount: completedTaskCount,
      totalTaskCount: totalTaskCount,
      focusSeconds: focusSeconds,
      completionSummary: _clean(completionSummary),
      bestThing: _clean(bestThing),
      problem: _clean(problem),
      improvement: _clean(improvement),
      nextWeekPriority: _clean(nextWeekPriority),
      note: _clean(note),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      localVersion: (existing?.localVersion ?? 0) + 1,
      serverVersion: existing?.serverVersion,
      modifiedByDevice: deviceId,
    );
    _items.removeWhere((item) => item.id == review.id);
    _items.add(review);
    _changes.add(null);
    return review;
  }

  @override
  Future<void> deleteReview({
    required String userId,
    required String reviewId,
  }) async {
    _items.removeWhere(
      (item) => item.userId == userId && item.id == reviewId,
    );
    _changes.add(null);
  }
}

void _validateWeeklyReview(WeeklyReview review) {
  _validateWeek(review.weekStart, review.weekEnd);
  _validateStats(
    completionScore: review.completionScore,
    completedTaskCount: review.completedTaskCount,
    totalTaskCount: review.totalTaskCount,
    focusSeconds: review.focusSeconds,
  );
}

void _validateWeek(String weekStart, String weekEnd) {
  final start = _parseDate(weekStart, 'weekStart');
  final end = _parseDate(weekEnd, 'weekEnd');
  if (end.difference(start).inDays != 6) {
    throw ArgumentError('Weekly Review 必须覆盖连续 7 个自然日');
  }
}

void _validateStats({
  required double? completionScore,
  required int? completedTaskCount,
  required int? totalTaskCount,
  required int? focusSeconds,
}) {
  if (completionScore != null &&
      (!completionScore.isFinite ||
          completionScore < 0 ||
          completionScore > 1)) {
    throw ArgumentError.value(
      completionScore,
      'completionScore',
      '完成率必须在 0..1 之间',
    );
  }
  if (completedTaskCount != null && completedTaskCount < 0) {
    throw ArgumentError.value(
      completedTaskCount,
      'completedTaskCount',
      '完成任务数不能为负数',
    );
  }
  if (totalTaskCount != null && totalTaskCount < 0) {
    throw ArgumentError.value(
      totalTaskCount,
      'totalTaskCount',
      '任务总数不能为负数',
    );
  }
  if (completedTaskCount != null &&
      totalTaskCount != null &&
      completedTaskCount > totalTaskCount) {
    throw ArgumentError('完成任务数不能超过任务总数');
  }
  if (focusSeconds != null && focusSeconds < 0) {
    throw ArgumentError.value(
      focusSeconds,
      'focusSeconds',
      '专注秒数不能为负数',
    );
  }
}

DateTime _parseDate(String raw, String name) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) {
    throw ArgumentError.value(raw, name, '必须是 YYYY-MM-DD');
  }
  final value = DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  if (_dateKey(value) != raw) {
    throw ArgumentError.value(raw, name, '日期不存在');
  }
  return value;
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String? _clean(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}
