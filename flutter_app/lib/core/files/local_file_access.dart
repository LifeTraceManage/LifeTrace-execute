import 'local_file_access_stub.dart'
    if (dart.library.io) 'local_file_access_io.dart' as platform;

Future<String> persistPickedFile({
  required String sourcePath,
  required String directoryPath,
  required String uploadId,
  required String originalName,
}) =>
    platform.persistPickedFile(
      sourcePath: sourcePath,
      directoryPath: directoryPath,
      uploadId: uploadId,
      originalName: originalName,
    );

Future<int> localFileLength(String path) => platform.localFileLength(path);

Future<String> localFileSha256(String path) => platform.localFileSha256(path);

Stream<List<int>> openLocalFileStream(String path) =>
    platform.openLocalFileStream(path);

Future<void> deleteLocalFile(String path) => platform.deleteLocalFile(path);
