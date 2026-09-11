import '../../core/files/local_file_access.dart';
import '../../domain/collection/execution_file_metadata.dart';
import '../local/app_database.dart' as db;

abstract final class MediaUploadDatabaseMapper {
  static PendingMediaUpload fromRow(db.MediaUpload row) => PendingMediaUpload(
        id: row.id,
        userId: row.userId,
        memoId: row.memoId,
        kind: row.kind,
        localPath: row.localPath,
        originalName: row.originalName,
        mimeType: row.mimeType,
        sizeBytes: row.sizeBytes,
        sha256: row.sha256,
        status: MediaUploadStatus.fromWire(row.status),
        attemptCount: row.attemptCount,
        serverFileId: row.serverFileId,
        errorMessage: row.errorMessage,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}

class MediaUploadRepository {
  MediaUploadRepository(this.database);

  final db.AppDatabase database;

  Stream<List<PendingMediaUpload>> watchUploads(String userId) {
    final query = database.select(database.mediaUploads)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) =>
              rows.map(MediaUploadDatabaseMapper.fromRow).toList(growable: false),
        );
  }

  Future<PendingMediaUpload?> findById(String id) async {
    final row = await (database.select(database.mediaUploads)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : MediaUploadDatabaseMapper.fromRow(row);
  }

  Future<List<PendingMediaUpload>> pendingForUser(String userId) async {
    final rows = await (database.select(database.mediaUploads)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.status.isIn(const [
                  'local_only',
                  'pending_upload',
                  'uploading',
                  'failed',
                ]),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .get();
    return rows.map(MediaUploadDatabaseMapper.fromRow).toList(growable: false);
  }

  Future<void> removeForMemo(String userId, String memoId) async {
    final rows = await (database.select(database.mediaUploads)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.memoId.equals(memoId),
          ))
        .get();
    for (final row in rows) {
      await deleteLocalFile(row.localPath);
    }
    await (database.delete(database.mediaUploads)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.memoId.equals(memoId),
          ))
        .go();
  }
}
