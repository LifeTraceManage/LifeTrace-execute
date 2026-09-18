import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/focus/execution_focus_session.dart';
import '../../domain/focus/focus_timer_state.dart';
import '../local/app_database.dart' as db;

abstract final class FocusSessionDatabaseMapper {
  static db.FocusSession toRow(ExecutionFocusSession session) => db.FocusSession(
        id: session.id,
        userId: session.userId,
        taskId: session.taskId,
        mode: session.mode.wireValue,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        focusSeconds: session.focusSeconds,
        completed: session.completed,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
        localVersion: session.localVersion,
        serverVersion: session.serverVersion,
        modifiedByDevice: session.modifiedByDevice,
      );

  static ExecutionFocusSession fromRow(db.FocusSession row) =>
      ExecutionFocusSession(
        id: row.id,
        userId: row.userId,
        taskId: row.taskId,
        mode: FocusMode.fromWire(row.mode),
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        focusSeconds: row.focusSeconds,
        completed: row.completed,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class FocusTimerStateDatabaseMapper {
  static db.FocusTimerState toRow(FocusTimerState state) => db.FocusTimerState(
        userId: state.userId,
        mode: state.mode.wireValue,
        focusSeconds: state.focusSeconds,
        breakSeconds: state.breakSeconds,
        phase: state.phase.wireValue,
        status: state.status.wireValue,
        startedAt: state.startedAt,
        expectedEndAt: state.expectedEndAt,
        pausedAt: state.pausedAt,
        remainingSecondsWhenPaused: state.remainingSecondsWhenPaused,
        linkedTaskId: state.linkedTaskId,
        round: state.round,
        focusSessionId: state.focusSessionId,
        updatedAt: state.updatedAt,
      );

  static FocusTimerState fromRow(db.FocusTimerState row) => FocusTimerState(
        userId: row.userId,
        mode: FocusMode.fromWire(row.mode),
        focusSeconds: row.focusSeconds,
        breakSeconds: row.breakSeconds,
        phase: FocusPhase.fromWire(row.phase),
        status: FocusTimerStatus.fromWire(row.status),
        startedAt: row.startedAt,
        expectedEndAt: row.expectedEndAt,
        pausedAt: row.pausedAt,
        remainingSecondsWhenPaused: row.remainingSecondsWhenPaused,
        linkedTaskId: row.linkedTaskId,
        round: row.round,
        focusSessionId: row.focusSessionId,
        updatedAt: row.updatedAt,
      );
}

abstract final class FocusSessionWireMapper {
  static Map<String, dynamic> toPayload(ExecutionFocusSession session) => {
        'id': session.id,
        'userId': session.userId,
        'taskId': session.taskId,
        'mode': session.mode.wireValue,
        'startedAt': session.startedAt,
        'endedAt': session.endedAt,
        'focusSeconds': session.focusSeconds,
        'completed': session.completed,
      };

  static ExecutionFocusSession fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
    required String serverModifiedAt,
  }) {
    final focusSeconds = _requiredInt(payload, 'focusSeconds');
    if (focusSeconds < 0) {
      throw const FormatException('focusSeconds must be non-negative');
    }
    final startedAt = _requiredUtc(payload, 'startedAt');
    final endedAt = _requiredUtc(payload, 'endedAt');
    if (endedAt.isBefore(startedAt)) {
      throw const FormatException('FocusSession endedAt is before startedAt');
    }

    return ExecutionFocusSession(
      id: _requiredString(payload, 'id'),
      userId: _requiredString(payload, 'userId'),
      taskId: _nullableString(payload['taskId']),
      mode: FocusMode.fromWire(_requiredString(payload, 'mode')),
      startedAt: startedAt.toIso8601String(),
      endedAt: endedAt.toIso8601String(),
      focusSeconds: focusSeconds,
      completed: _requiredBool(payload, 'completed'),
      createdAt: serverModifiedAt,
      updatedAt: serverModifiedAt,
      localVersion: 1,
      serverVersion: serverVersion,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = json[name]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw FormatException('FocusSession payload missing $name');
    }
    return value;
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _requiredInt(Map<String, dynamic> json, String name) {
    final value = json[name];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('FocusSession payload invalid $name');
    }
    return parsed;
  }

  static bool _requiredBool(Map<String, dynamic> json, String name) {
    final value = json[name];
    if (value is bool) return value;
    if (value?.toString() == 'true') return true;
    if (value?.toString() == 'false') return false;
    throw FormatException('FocusSession payload invalid $name');
  }

  static DateTime _requiredUtc(Map<String, dynamic> json, String name) {
    final value = DateTime.tryParse(_requiredString(json, name))?.toUtc();
    if (value == null) {
      throw FormatException('FocusSession payload invalid $name');
    }
    return value;
  }
}

abstract interface class FocusRepository {
  Stream<FocusTimerState?> watchTimerState(String userId);
  Future<FocusTimerState?> getTimerState(String userId);
  Future<void> saveTimerState(FocusTimerState state);

  Stream<List<ExecutionFocusSession>> watchSessions(String userId);
  Future<List<ExecutionFocusSession>> listSessions(String userId);

  Future<void> recordSessionAndSaveState({
    required ExecutionFocusSession session,
    required FocusTimerState nextState,
  });
}

class DriftFocusRepository implements FocusRepository {
  DriftFocusRepository(this.database);

  static const entityType = 'execution.focus_session';

  final db.AppDatabase database;

  @override
  Stream<FocusTimerState?> watchTimerState(String userId) {
    final query = database.select(database.focusTimerStates)
      ..where((table) => table.userId.equals(userId));
    return query.watchSingleOrNull().map(
          (row) =>
              row == null ? null : FocusTimerStateDatabaseMapper.fromRow(row),
        );
  }

  @override
  Future<FocusTimerState?> getTimerState(String userId) async {
    final row = await (database.select(database.focusTimerStates)
          ..where((table) => table.userId.equals(userId)))
        .getSingleOrNull();
    return row == null ? null : FocusTimerStateDatabaseMapper.fromRow(row);
  }

  @override
  Future<void> saveTimerState(FocusTimerState state) async {
    await database.into(database.focusTimerStates).insertOnConflictUpdate(
          FocusTimerStateDatabaseMapper.toRow(state),
        );
  }

  @override
  Stream<List<ExecutionFocusSession>> watchSessions(String userId) {
    final query = database.select(database.focusSessions)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.endedAt)]);
    return query.watch().map(
          (rows) =>
              rows.map(FocusSessionDatabaseMapper.fromRow).toList(growable: false),
        );
  }

  @override
  Future<List<ExecutionFocusSession>> listSessions(String userId) async {
    final query = database.select(database.focusSessions)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.endedAt)]);
    return (await query.get())
        .map(FocusSessionDatabaseMapper.fromRow)
        .toList(growable: false);
  }

  @override
  Future<void> recordSessionAndSaveState({
    required ExecutionFocusSession session,
    required FocusTimerState nextState,
  }) async {
    await database.transaction(() async {
      final existing = await (database.select(database.focusSessions)
            ..where((table) => table.id.equals(session.id)))
          .getSingleOrNull();

      if (existing == null) {
        await database.into(database.focusSessions).insert(
              FocusSessionDatabaseMapper.toRow(session),
            );
        await database.into(database.syncOutbox).insert(
              db.SyncOutboxCompanion.insert(
                changeId: '${session.id}:create',
                userId: session.userId,
                entityType: entityType,
                entityId: session.id,
                operation: 'upsert',
                baseServerVersion: session.serverVersion ?? '0',
                clientModifiedAt: session.updatedAt,
                payloadJson: Value(
                  jsonEncode(FocusSessionWireMapper.toPayload(session)),
                ),
                createdAt: session.updatedAt,
              ),
            );
      }

      await database.into(database.focusTimerStates).insertOnConflictUpdate(
            FocusTimerStateDatabaseMapper.toRow(nextState),
          );
    });
  }
}

class PreviewFocusRepository implements FocusRepository {
  final Map<String, FocusTimerState> _states = {};
  final List<ExecutionFocusSession> _sessions = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<FocusTimerState?> watchTimerState(String userId) async* {
    yield _states[userId];
    await for (final _ in _changes.stream) {
      yield _states[userId];
    }
  }

  @override
  Future<FocusTimerState?> getTimerState(String userId) async => _states[userId];

  @override
  Future<void> saveTimerState(FocusTimerState state) async {
    _states[state.userId] = state;
    _changes.add(null);
  }

  @override
  Stream<List<ExecutionFocusSession>> watchSessions(String userId) async* {
    List<ExecutionFocusSession> snapshot() => _sessions
        .where((session) => session.userId == userId)
        .toList(growable: false)
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<List<ExecutionFocusSession>> listSessions(String userId) async =>
      _sessions.where((session) => session.userId == userId).toList(growable: false);

  @override
  Future<void> recordSessionAndSaveState({
    required ExecutionFocusSession session,
    required FocusTimerState nextState,
  }) async {
    if (!_sessions.any((candidate) => candidate.id == session.id)) {
      _sessions.add(session);
    }
    _states[nextState.userId] = nextState;
    _changes.add(null);
  }
}
