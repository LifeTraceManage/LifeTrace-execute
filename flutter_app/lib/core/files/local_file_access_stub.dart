Future<String> persistPickedFile({
  required String sourcePath,
  required String directoryPath,
  required String uploadId,
  required String originalName,
}) {
  throw UnsupportedError('Local media files are only supported on Android');
}

Future<int> localFileLength(String path) {
  throw UnsupportedError('Local media files are only supported on Android');
}

Future<String> localFileSha256(String path) {
  throw UnsupportedError('Local media files are only supported on Android');
}

Stream<List<int>> openLocalFileStream(String path) {
  throw UnsupportedError('Local media files are only supported on Android');
}

Future<void> deleteLocalFile(String path) async {}
