import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/collection/execution_memo.dart';
import '../local/app_database.dart' as db;

abstract final class MemoDatabaseMapper {
  static db.Memo toRow(ExecutionMemo memo) => db.Memo(
        id: memo.id,
        userId: memo.userId,
        kind: memo.kind.wireValue,
        title: memo.title,
        content: memo.content,
        sourceUrl: memo.sourceUrl,
        important: memo.important,
        status: memo.status.wireValue,
        createdAt: memo.createdAt,
        updatedAt: memo.updatedAt,
        localVersion: memo.localVersion,
        serverVersion: memo.serverVersion,
        modifiedByDevice: memo.modifiedByDevice,
      );

  static ExecutionMemo fromRow(db.Memo row) => ExecutionMemo(
        id: row.id,
        userId: row.userId,
        kind: ExecutionMemoKind.fromWire(row.kind),
        title: row.title,
        content: row.content,
        sourceUrl: row.sourceUrl,
        important: row.important,
        status: ExecutionMemoStatus.fromWire(row.status),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class MemoWireMapper {
  static Map<String, dynamic> toPayload(ExecutionMemo memo) => {
        'meta': {
          'id': memo.id,
          'userId': memo.userId,
          'createdAt': memo.createdAt,
          'updatedAt': memo.updatedAt,
          'deletedAt': null,
          'localVersion': memo.localVersion,
          'serverVersion': memo.serverVersion,
          'modifiedByDevice': memo.modifiedByDevice,
        },
        'kind': memo.kind.wireValue,
        'title': memo.title,
        'content': memo.content,
        'sourceUrl': memo.sourceUrl,
        'important': memo.important,
        'status': memo.status.wireValue,
      };

  static ExecutionMemo fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta']);
    return ExecutionMemo(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      kind: ExecutionMemoKind.fromWire(
        _nullableString(payload['kind']) ?? 'text',
      ),
      title: _nullableString(payload['title']),
      content: _requiredString(payload, 'content'),
      sourceUrl: _nullableString(payload['sourceUrl']),
      important: _bool(payload['important']) ?? false,
      status: ExecutionMemoStatus.fromWire(
        _nullableString(payload['status']) ?? 'inbox',
      ),
      createdAt: _requiredString(meta, 'createdAt'),
      updatedAt: _requiredString(meta, 'updatedAt'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Memo payload meta must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) throw FormatException('Memo payload is missing $name');
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool? _bool(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    return null;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

abstract interface class MemoRepository {
  Stream<List<ExecutionMemo>> watchMemos(String userId);

  Future<ExecutionMemo> createMemo({
    required String userId,
    required String deviceId,
    required ExecutionMemoKind kind,
    required String content,
    String? title,
    String? sourceUrl,
    bool important = false,
  });

  Future<ExecutionMemo> updateMemo({
    required ExecutionMemo memo,
    required String deviceId,
    String? title,
    String? content,
    String? sourceUrl,
    bool? important,
    ExecutionMemoStatus? status,
    bool clearTitle = false,
    bool clearSourceUrl = false,
  });

  Future<void> deleteMemo({
    required String userId,
    required String memoId,
  });
}

class DriftMemoRepository implements MemoRepository {
  DriftMemoRepository(this.database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const entityType = 'execution.memo';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<ExecutionMemo>> watchMemos(String userId) {
    final query = database.select(database.memos)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) => rows.map(MemoDatabaseMapper.fromRow).toList(growable: false),
        );
  }

  @override
  Future<ExecutionMemo> createMemo({
    required String userId,
    required String deviceId,
    required ExecutionMemoKind kind,
    required String content,
    String? title,
    String? sourceUrl,
    bool important = false,
  }) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) {
      throw ArgumentError.value(content, 'content', '收集内容不能为空');
    }
    final cleanUrl = _clean(sourceUrl);
    if (kind == ExecutionMemoKind.link) _validateLink(cleanUrl);

    final now = DateTime.now().toUtc().toIso8601String();
    final memo = ExecutionMemo(
      id: _uuid.v4(),
      userId: userId,
      kind: kind,
      title: _clean(title),
      content: cleanContent,
      sourceUrl: cleanUrl,
      important: important,
      status: ExecutionMemoStatus.inbox,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    await writeLocalChange(memo);
    return memo;
  }

  @override
  Future<ExecutionMemo> updateMemo({
    required ExecutionMemo memo,
    required String deviceId,
    String? title,
    String? content,
    String? sourceUrl,
    bool? important,
    ExecutionMemoStatus? status,
    bool clearTitle = false,
    bool clearSourceUrl = false,
  }) async {
    final nextContent = (content ?? memo.content).trim();
    if (nextContent.isEmpty) {
      throw ArgumentError.value(nextContent, 'content', '收集内容不能为空');
    }
    final nextUrl =
        clearSourceUrl ? null : sourceUrl == null ? memo.sourceUrl : _clean(sourceUrl);
    if (memo.kind == ExecutionMemoKind.link) _validateLink(nextUrl);

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = memo.copyWith(
      title: title == null ? null : _clean(title),
      content: nextContent,
      sourceUrl: nextUrl,
      important: important,
      status: status,
      updatedAt: now,
      localVersion: memo.localVersion + 1,
      modifiedByDevice: deviceId,
      clearTitle: clearTitle,
      clearSourceUrl: clearSourceUrl,
    );
    await writeLocalChange(updated);
    return updated;
  }

  @override
  Future<void> deleteMemo({
    required String userId,
    required String memoId,
  }) async {
    final existing = await (database.select(database.memos)
          ..where(
            (table) => table.userId.equals(userId) & table.id.equals(memoId),
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
              entityId: memoId,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.memos)
            ..where(
              (table) => table.userId.equals(userId) & table.id.equals(memoId),
            ))
          .go();
    });
  }

  Future<void> writeLocalChange(ExecutionMemo memo) async {
    await database.transaction(() async {
      await database
          .into(database.memos)
          .insertOnConflictUpdate(MemoDatabaseMapper.toRow(memo));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: memo.userId,
              entityType: entityType,
              entityId: memo.id,
              operation: 'upsert',
              baseServerVersion: memo.serverVersion ?? '0',
              clientModifiedAt: memo.updatedAt,
              payloadJson: Value(jsonEncode(MemoWireMapper.toPayload(memo))),
              createdAt: memo.updatedAt,
            ),
          );
    });
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static void _validateLink(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !{'http', 'https'}.contains(uri.scheme)) {
      throw ArgumentError.value(value, 'sourceUrl', '链接必须是 http/https URL');
    }
  }
}

class PreviewMemoRepository implements MemoRepository {
  PreviewMemoRepository()
      : _memos = [
          _sample(
            'preview-memo-1',
            ExecutionMemoKind.link,
            'Set-membership estimation 与预测控制相关资料',
            title: 'Transformer 新论文',
            sourceUrl: 'https://example.com/paper',
            important: true,
          ),
          _sample(
            'preview-memo-2',
            ExecutionMemoKind.idea,
            '把收集箱做成真正的临时工作区，而不是一串等待清理的文本。',
            title: 'LifeTrace 设计灵感',
          ),
        ];

  final List<ExecutionMemo> _memos;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  final Uuid _uuid = const Uuid();

  static ExecutionMemo _sample(
    String id,
    ExecutionMemoKind kind,
    String content, {
    String? title,
    String? sourceUrl,
    bool important = false,
  }) =>
      ExecutionMemo(
        id: id,
        userId: 'preview-user',
        kind: kind,
        title: title,
        content: content,
        sourceUrl: sourceUrl,
        important: important,
        status: ExecutionMemoStatus.inbox,
        createdAt: '2026-09-11T00:00:00.000Z',
        updatedAt: '2026-09-11T00:00:00.000Z',
        localVersion: 1,
        modifiedByDevice: 'web-preview',
      );

  @override
  Stream<List<ExecutionMemo>> watchMemos(String userId) async* {
    List<ExecutionMemo> snapshot() => _memos
        .where((memo) => memo.userId == userId)
        .toList(growable: false);
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<ExecutionMemo> createMemo({
    required String userId,
    required String deviceId,
    required ExecutionMemoKind kind,
    required String content,
    String? title,
    String? sourceUrl,
    bool important = false,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final memo = ExecutionMemo(
      id: _uuid.v4(),
      userId: userId,
      kind: kind,
      title: DriftMemoRepository._clean(title),
      content: content.trim(),
      sourceUrl: DriftMemoRepository._clean(sourceUrl),
      important: important,
      status: ExecutionMemoStatus.inbox,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    if (memo.content.isEmpty) throw ArgumentError('收集内容不能为空');
    if (kind == ExecutionMemoKind.link) {
      DriftMemoRepository._validateLink(memo.sourceUrl);
    }
    _memos.insert(0, memo);
    _changes.add(true);
    return memo;
  }

  @override
  Future<ExecutionMemo> updateMemo({
    required ExecutionMemo memo,
    required String deviceId,
    String? title,
    String? content,
    String? sourceUrl,
    bool? important,
    ExecutionMemoStatus? status,
    bool clearTitle = false,
    bool clearSourceUrl = false,
  }) async {
    final updated = memo.copyWith(
      title: title,
      content: content,
      sourceUrl: sourceUrl,
      important: important,
      status: status,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      localVersion: memo.localVersion + 1,
      modifiedByDevice: deviceId,
      clearTitle: clearTitle,
      clearSourceUrl: clearSourceUrl,
    );
    final index = _memos.indexWhere((item) => item.id == memo.id);
    if (index >= 0) _memos[index] = updated;
    _changes.add(true);
    return updated;
  }

  @override
  Future<void> deleteMemo({
    required String userId,
    required String memoId,
  }) async {
    _memos.removeWhere((memo) => memo.userId == userId && memo.id == memoId);
    _changes.add(true);
  }
}
