import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> writePrivacyExport(Map<String, dynamic> payload) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory('${root.path}/exports');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final now = DateTime.now().toUtc();
  final stamp = [
    now.year.toString().padLeft(4, '0'),
    now.month.toString().padLeft(2, '0'),
    now.day.toString().padLeft(2, '0'),
    '-',
    now.hour.toString().padLeft(2, '0'),
    now.minute.toString().padLeft(2, '0'),
    now.second.toString().padLeft(2, '0'),
  ].join();
  final file = File('${directory.path}/lifetrace-privacy-export-$stamp.json');
  final encoded = const JsonEncoder.withIndent('  ').convert(payload);
  await file.writeAsString(encoded, flush: true);
  return file.path;
}
