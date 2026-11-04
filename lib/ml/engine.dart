import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import '../core/models.dart';
import '../core/vectors.dart';
import 'vision.dart';

class AiEngine {
  static const version = 'tinyclip-vit8m-v1';
  static const faceVersion = 'yunet320-sface-v1';
  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _image, _detector, _face;
  Future<void>? _loading;
  Map<String, List<double>> _categories = {};
  String? lastError;
  String _modelAsset(String filename) =>
      kIsWeb ? 'assets/assets/models/$filename' : 'assets/models/$filename';
  Future<void> load() => _loading ??= _load().catchError((Object e) {
    _loading = null;
    lastError = e.toString();
    throw e;
  });
  Future<void> _load() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/models/categories.json'))
            as Map<String, dynamic>;
    _categories = (data['vectors'] as Map).map(
      (k, v) => MapEntry(k.toString(), unitVector(List<num>.from(v))),
    );
    _image = await _runtime.createSessionFromAsset(
      _modelAsset('tinyclip-image.onnx'),
      options: OrtSessionOptions(intraOpNumThreads: 2, interOpNumThreads: 1),
    );
    lastError = null;
  }

  Future<Map<String, List<double>>> _run(
    OrtSession session,
    Float32List pixels,
    List<int> shape,
  ) async {
    final input = await OrtValue.fromList(pixels, shape);
    Map<String, OrtValue> outputs = {};
    try {
      outputs = await session.run({session.inputNames.first: input});
      final result = <String, List<double>>{};
      for (final entry in outputs.entries) {
        result[entry.key] = List<double>.from(
          (await entry.value.asFlattenedList()).map(
            (v) => (v as num).toDouble(),
          ),
        );
      }
      return result;
    } finally {
      await input.dispose();
      for (final output in outputs.values) {
        await output.dispose();
      }
    }
  }

  Future<Features> analyze(
    Uint8List bytes,
    Features base, {
    bool people = false,
    bool video = false,
  }) async {
    await load();
    final image = decodePhoto(bytes);
    final embedding = base.version == version && base.embedding.length == 512
        ? base.embedding
        : unitVector(
            (await _run(_image!, clipPixels(image), [
              1,
              3,
              224,
              224,
            ])).values.first,
          );
    if (embedding.length != 512) throw StateError('Invalid TinyCLIP output.');
    final scores = _categories.map((k, v) => MapEntry(k, cosine(embedding, v)));
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final category =
        ranked.first.value < .18 || ranked.first.value - ranked[1].value < .005
        ? 'Other'
        : ranked.first.key;
    List<FaceSample> faces = [];
    if (people && !video) {
      if (base.faceVersion == faceVersion) {
        faces = base.faces;
      } else {
        _detector ??= await _runtime.createSessionFromAsset(
          _modelAsset('yunet.onnx'),
        );
        final detections = decodeYuNet(
          await _run(_detector!, detectorPixels(image), [1, 3, 320, 320]),
          image.width,
          image.height,
        );
        // Never load or run SFace on a photo without an accepted face detection.
        for (final detection in detections) {
          final aligned = alignedFace(image, detection.landmarks);
          final sharpness = faceSharpness(aligned);
          if (sharpness < 20) continue;
          _face ??= await _runtime.createSessionFromAsset(
            _modelAsset('sface.onnx'),
          );
          final vector = unitVector(
            (await _run(_face!, aligned, [1, 3, 112, 112])).values.first,
          );
          if (vector.length != 128) continue;
          final box = detection.box;
          faces.add(
            FaceSample(
              [
                box[0] / image.width,
                box[1] / image.height,
                box[2] / image.width,
                box[3] / image.height,
              ],
              vector,
              detection.score * (sharpness / 300).clamp(0.0, 1.0),
            ),
          );
        }
      }
    }
    return base.withAi(
      embedding: embedding,
      scores: scores,
      category: category,
      faces: faces,
      faceVersion: people ? faceVersion : null,
      clearFaces: !people,
      version: version,
    );
  }

  Future<void> closeFaces() async {
    await _detector?.close();
    await _face?.close();
    _detector = null;
    _face = null;
  }
}
