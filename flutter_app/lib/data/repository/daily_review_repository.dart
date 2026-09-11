import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/review/daily_review.dart';
import '../local/app_database.dart' as db;

abstract final class DailyReviewDatabaseMapper {
  static db.DailyReview toRow(DailyReview review) => db.DailyReview(
        id: review.id,
        userId: review.userId,
        reviewDate: review.reviewDate,
        energy: review.energy,
        mood: review.mood,
        completionScore: review.completionScore,
        bestThing: review.bestThing,
        problem: review.problem,
        tomorrowPriority: review.tomorrowPriority,
        note: review.note,
        completedTaskCount: review.completedTaskCount,
        totalTaskCount: review.totalTaskCount,
        createdAt: review.createdAt,
        updatedAt: review.updatedAt,
        localVersion: review.localVersion,
        serverVersion: review.serverVersion,
        modifiedByDevice: review.modifiedByDevice,
      );

  static DailyReview fromRow(db.DailyReview row) => DailyReview(
        id: row.id,
        userId: row.userId,
        reviewDate: row.reviewDate,
        energy: row.energy,
        mood: row.mood,
        completionScore: row.completionScore,
        bestThing: row.bestThing,
        problem: row.problem,
        tomorrowPriority: row.tomorrowPriority,
        note: row.note,
        completedTaskCount: row.completedTaskCount,
        totalTaskCount: row.totalTaskCount,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class DailyReviewWireMapper {
  static Map<String, dynamic> toPayload(DailyReview review) => {
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
        'reviewDate': review.reviewDate,
        'energy': review.energy,
        'mood': review.mood,
        'completionScore': review.completionScore,
        'bestThing': review.bestThing,
        'problem': review.problem,
        'tomorrowPriority': review.tomorrowPriority,
        'note': review.note,
        'completedTaskCount': review.completedTaskCount,
        'totalTaskCount': review.totalTaskCount,
      };

  static DailyReview fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta'], 'meta');
    return DailyReview(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      reviewDate: _requiredString(payload, 'reviewDate'),
      energy: _int(payload['energy']),
      mood: _int(payload['mood']),
      completionScore: _double(payload['completionScore']),
      bestThing: _nullableString(payload['bestThing']),
      problem: _nullableString(payload['problem']),
      tomorrowPriority: _nullableString(payload['tomorrowPriority']),
      note: _nullableString(payload['note']),
      completedTaskCount: _int(payload['completedTaskCount']),
      totalTaskCount: _int(payload['totalTaskCount']),
      createdAt: _requiredString(meta, 'createdAt'),
      updatedAt: _requiredString(meta, 'updatedAt'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
  }

  static Map<String, dynamic> _map(Object? value, String name) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('DailyReview $name must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) {
      throw FormatException('DailyReview payload is missing $name');
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

abstract interface class DailyReviewRepository {
  Stream<List<DailyReview>> watchReviews(String userId);

  Stream<DailyReview?> watchReviewForDate({
    required String userId,
    required String reviewDate,
  });

  Future<DailyReview> saveReview({
    required String userId,
    required String deviceId,
    required String reviewDate,
    int? energy,
    int? mood,
    double? completionScore,
    String? bestThing,
    String? problem,
    String? tomorrowPriority,
    String? note,
    int? completedTaskCount,
    int? totalTaskCount,
  });

  Future<void> deleteReview({
    required String userId,
    required String reviewId,
  });
}

class DriftDailyReviewRepository implements DailyReviewRepository {
  DriftDailyReviewRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const entityType = 'review.daily';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<DailyReview>> watchReviews(String userId) {
    final query = database.select(database.dailyReviews)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm.desc(table.reviewDate),
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    return query.watch().map(
          (rows) => rows
              .map(DailyReviewDatabaseMapper.fromRow)
              .toList(growable: false),
        );
  }

  @override
  Stream<DailyReview?> watchReviewForDate({
    required String userId,
    required String reviewDate,
  }) {
    final query = database.select(database.dailyReviews)
      ..where(
        (table) =>
            table.userId.equals(userId) &
            table.reviewDate.equals(reviewDate),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])
      ..limit(1);
    return query.watch().map(
          (rows) =>
              rows.isEmpty ? null : DailyReviewDatabaseMapper.fromRow(rows.first),
        );
  }

  @override
  Future<DailyReview> saveReview({
    required String userId,
    required String deviceId,
    required String reviewDate,
    int? energy,
    int? mood,
    double? completionScore,
    String? bestThing,
    String? problem,
    String? tomorrowPriority,
    String? note,
    int? completedTaskCount,
    int? totalTaskCount,
  }) async {
    _validateDate(reviewDate);
    _validateScale('energy', energy);
    _validateScale('mood', mood);
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
      throw ArgumentError('完成任务数不能大于任务总数');
    }

    final existing = await (database.select(database.dailyReviews)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.reviewDate.equals(reviewDate),
          )
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    final now = DateTime.now().toUtc().toIso8601String();
    final review = DailyReview(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      reviewDate: reviewDate,
      energy: energy,
      mood: mood,
      completionScore: completionScore,
      bestThing: _clean(bestThing),
      problem: _clean(problem),
      tomorrowPriority: _clean(tomorrowPriority),
      note: _clean(note),
      completedTaskCount: completedTaskCount,
      totalTaskCount: totalTaskCount,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      localVersion: (existing?.localVersion ?? 0) + 1,
      serverVersion: existing?.serverVersion,
      modifiedByDevice: deviceId,
    );
    await writeLocalChange(review);
    return review;
  }

  @override
  Future<void> deleteReview({
    required String userId,
    required String reviewId,
  }) async {
    final existing = await (database.select(database.dailyReviews)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.id.equals(reviewId),
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
      await (database.delete(database.dailyReviews)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.id.equals(reviewId),
            ))
          .go();
    });
  }

  Future<void> writeLocalChange(DailyReview review) async {
    await database.transaction(() async {
      await database
          .into(database.dailyReviews)
          .insertOnConflictUpdate(DailyReviewDatabaseMapper.toRow(review));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: review.userId,
              entityType: entityType,
              entityId: review.id,
              operation: 'upsert',
              baseServerVersion: review.serverVersion ?? '0',
              clientModifiedAt: review.updatedAt,
              payloadJson: Value(
                jsonEncode(DailyReviewWireMapper.toPayload(review)),
              ),
              createdAt: review.updatedAt,
            ),
          );
    });
  }

  static void _validateDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        DateTime.tryParse('${value}T00:00:00Z') == null) {
      throw ArgumentError.value(value, 'reviewDate', '复盘日期必须是 YYYY-MM-DD');
    }
  }

  static void _validateScale(String name, int? value) {
    if (value != null && (value < 1 || value > 5)) {
      throw ArgumentError.value(value, name, '$name 必须在 1..5 之间');
    }
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

class PreviewDailyReviewRepository implements DailyReviewRepository {
  final List<DailyReview> _reviews = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<DailyReview>> watchReviews(String userId) async* {
    List<DailyReview> snapshot() {
      final result = _reviews
          .where((review) => review.userId == userId)
          .toList(growable: false);
      result.sort((a, b) => b.reviewDate.compareTo(a.reviewDate));
      return result;
    }

    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Stream<DailyReview?> watchReviewForDate({
    required String userId,
    required String reviewDate,
  }) async* {
    DailyReview? current() {
      final matches = _reviews
          .where(
            (review) =>
                review.userId == userId &&
                review.reviewDate == reviewDate,
          )
          .toList(growable: false);
      if (matches.isEmpty) return null;
      matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return matches.first;
    }

    yield current();
    await for (final _ in _changes.stream) {
      yield current();
    }
  }

  @override
  Future<DailyReview> saveReview({
    required String userId,
    required String deviceId,
    required String reviewDate,
    int? energy,
    int? mood,
    double? completionScore,
    String? bestThing,
    String? problem,
    String? tomorrowPriority,
    String? note,
    int? completedTaskCount,
    int? totalTaskCount,
  }) async {
    final index = _reviews.indexWhere(
      (review) =>
          review.userId == userId &&
          review.reviewDate == reviewDate,
    );
    final existing = index < 0 ? null : _reviews[index];
    final now = DateTime.now().toUtc().toIso8601String();
    final review = DailyReview(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      reviewDate: reviewDate,
      energy: energy,
      mood: mood,
      completionScore: completionScore,
      bestThing: DriftDailyReviewRepository._clean(bestThing),
      problem: DriftDailyReviewRepository._clean(problem),
      tomorrowPriority:
          DriftDailyReviewRepository._clean(tomorrowPriority),
      note: DriftDailyReviewRepository._clean(note),
      completedTaskCount: completedTaskCount,
      totalTaskCount: totalTaskCount,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      localVersion: (existing?.localVersion ?? 0) + 1,
      serverVersion: existing?.serverVersion,
      modifiedByDevice: deviceId,
    );
    if (index < 0) {
      _reviews.add(review);
    } else {
      _reviews[index] = review;
    }
    _changes.add(null);
    return review;
  }

  @override
  Future<void> deleteReview({
    required String userId,
    required String reviewId,
  }) async {
    _reviews.removeWhere(
      (review) => review.userId == userId && review.id == reviewId,
    );
    _changes.add(null);
  }
}
