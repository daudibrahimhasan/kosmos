import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../core/models.dart';
import '../ml/quality.dart';

Future<Features> analyzeFile(Map<String, dynamic> job) async {
  final file = File(job['path'] as String);
  final hash = (await sha256.bind(file.openRead()).first).toString();
  return thumbnailQuality(
    job['thumbnail'] as Uint8List?,
    hash: hash,
    size: await file.length(),
    video: job['video'] as bool,
    screenshot: job['screenshot'] as bool,
  );
}
