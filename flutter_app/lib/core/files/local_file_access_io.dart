import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

Future<String> persistPickedFile({
  required String sourcePath,
  required String directoryPath,
  required String uploadId,
  required String originalName,
}) async {
  final directory = Directory(directoryPath);
  await directory.create(recursive: true);
  final extension = p.extension(originalName);
  final destination = p.join(directory.path, '$uploadId$extension');
  await File(sourcePath).copy(destination);
  return destination;
}

Future<int> localFileLength(String path) => File(path).length();

Future<String> localFileSha256(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

Stream<List<int>> openLocalFileStream(String path) => File(path).openRead();

Future<void> deleteLocalFile(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
