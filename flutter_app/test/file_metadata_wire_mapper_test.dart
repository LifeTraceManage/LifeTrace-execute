import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/file_metadata_repository.dart';
import 'package:lifetrace_execute/domain/collection/execution_file_metadata.dart';

void main() {
  test('file metadata wire mapper matches Cloud FileMetadata schema', () {
    const file = ExecutionFileMetadata(
      id: 'file-1',
      userId: 'user-1',
      originalName: 'diagram.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
      sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      storageState: ExecutionFileStorageState.serverStored,
      createdByDevice: 'device-1',
      createdAt: '2026-09-11T00:00:00.000Z',
      updatedAt: '2026-09-11T00:00:00.000Z',
      localVersion: 1,
      serverVersion: '5',
      modifiedByDevice: 'device-1',
    );

    final payload = FileMetadataWireMapper.toPayload(file);
    expect(payload['originalName'], 'diagram.png');
    expect(payload['mimeType'], 'image/png');
    expect(payload['sizeBytes'], 1024);
    expect(payload['storageState'], 'server_stored');
    expect(payload['createdByDevice'], 'device-1');

    final decoded = FileMetadataWireMapper.fromPayload(
      payload,
      serverVersion: '6',
    );
    expect(decoded.id, 'file-1');
    expect(decoded.sha256, file.sha256);
    expect(decoded.storageState, ExecutionFileStorageState.serverStored);
    expect(decoded.serverVersion, '6');
  });
}
