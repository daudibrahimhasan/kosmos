import 'dart:math' as math;
import 'dart:typed_data';

enum Decision { keep, delete, skip }

enum CleanKind { duplicates, similar, screenshots, blurry, videos, personal }

class MediaItem {
  final String id;
  final String? demoPath;
  final bool video;
  final int width, height, bytes, duration;
  final DateTime created, modified;
  final bool favorite, screenshot;
  final String album;
  const MediaItem({
    required this.id,
    this.demoPath,
    this.video = false,
    this.width = 0,
    this.height = 0,
    this.bytes = 0,
    this.duration = 0,
    required this.created,
    required this.modified,
    this.favorite = false,
    this.screenshot = false,
    this.album = 'Library',
  });
}

class Features {
  final List<double> embedding;
  final Map<String, double> categoryScores;
  final List<FaceSample> faces;
  final String? faceVersion;
  final String hash, phash, category;
  final double? blur;
  final int bytes;
  final bool screenshot;
  final String version;
  const Features({
    this.embedding = const [],
    this.categoryScores = const {},
    this.faces = const [],
    this.faceVersion,
    this.hash = '',
    this.phash = '',
    this.category = 'Other',
    this.blur,
    this.bytes = 0,
    this.screenshot = false,
    this.version = 'deterministic-v1',
  });
  Map<String, dynamic> toJson() => {
    'embedding': embedding,
    'categoryScores': categoryScores,
    'faces': faces.map((f) => f.toJson()).toList(),
    'faceVersion': faceVersion,
    'hash': hash,
    'phash': phash,
    'category': category,
    'blur': blur,
    'bytes': bytes,
    'screenshot': screenshot,
    'version': version,
  };
  factory Features.fromJson(Map<String, dynamic> j) => Features(
    embedding: List<double>.from(
      (j['embedding'] as List? ?? []).map((e) => (e as num).toDouble()),
    ),
    categoryScores: (j['categoryScores'] as Map? ?? {}).map(
      (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
    ),
    faces: (j['faces'] as List? ?? [])
        .map((f) => FaceSample.fromJson(Map<String, dynamic>.from(f)))
        .toList(),
    faceVersion: j['faceVersion'],
    hash: j['hash'] ?? '',
    phash: j['phash'] ?? '',
    category: j['category'] ?? 'Other',
    blur: (j['blur'] as num?)?.toDouble(),
    bytes: j['bytes'] ?? 0,
    screenshot: j['screenshot'] ?? false,
    version: j['version'] ?? 'deterministic-v1',
  );

  Features withAi({
    List<double>? embedding,
    Map<String, double>? scores,
    String? category,
    List<FaceSample>? faces,
    String? faceVersion,
    String? version,
    bool clearFaces = false,
  }) => Features(
    hash: hash,
    phash: phash,
    blur: blur,
    bytes: bytes,
    screenshot: screenshot,
    embedding: embedding ?? this.embedding,
    categoryScores: scores ?? categoryScores,
    category: category ?? this.category,
    faces: clearFaces ? const [] : faces ?? this.faces,
    faceVersion: clearFaces ? null : faceVersion ?? this.faceVersion,
    version: version ?? this.version,
  );
}

class FaceSample {
  final List<double> rect, embedding;
  final double quality;
  const FaceSample(this.rect, this.embedding, this.quality);
  String key(String assetId) =>
      '$assetId/${rect.map((v) => (v * 1000).round()).join(',')}';
  Map<String, dynamic> toJson() => {
    'rect': rect,
    'embedding': embedding,
    'quality': quality,
  };
  factory FaceSample.fromJson(Map<String, dynamic> j) => FaceSample(
    List<double>.from((j['rect'] as List).map((e) => (e as num).toDouble())),
    List<double>.from(
      (j['embedding'] as List).map((e) => (e as num).toDouble()),
    ),
    (j['quality'] as num).toDouble(),
  );
}

class ReviewGroup {
  final String title, reason;
  final List<MediaItem> items;
  final String? bestId;
  const ReviewGroup(this.title, this.reason, this.items, {this.bestId});
}

class DeleteResult {
  final Set<String> deleted;
  final Set<String> failed;
  const DeleteResult(this.deleted, this.failed);
}

abstract class GalleryRepository {
  bool get canImport => false;
  bool peopleEnabled = false;
  bool get neural => false;
  String get libraryLabel =>
      demo ? 'SAMPLE LIBRARY · LOCAL PREVIEW' : 'DEVICE LIBRARY';
  String get deletionExplanation =>
      'The system may ask you to confirm. Recently Deleted availability depends on your device.';
  Future<void> clearFaceModels() async {}
  Future<bool> importPhotos() async => false;
  bool get demo;
  String get analysisVersion => 'deterministic-v1';
  Future<bool> requestAccess();
  Future<List<MediaItem>> load();
  Future<Map<String, List<MediaItem>>> albums() async {
    final groups = <String, List<MediaItem>>{};
    for (final item in await load()) {
      (groups[item.album] ??= []).add(item);
    }
    return groups;
  }

  Future<Uint8List?> thumbnail(MediaItem item, {int size = 500});
  Future<Features> analyze(MediaItem item, {Features? cached});
  Future<String?> localVideoPath(MediaItem item) async => null;
  Future<DeleteResult> delete(Set<String> reviewedIds);
  Future<void> openSettings();
}

abstract class LocalStore {
  Future<void> compact() async {}
  Future<Map<String, dynamic>> read();
  Future<void> save(Map<String, dynamic> state);
}

// Local logistic regression. No identifiers, filenames or personal labels in features.
class PreferenceModel {
  static const version = 'logistic-tinyclip-v1';
  final List<double> weights;
  int labels;
  PreferenceModel({List<double>? weights, this.labels = 0})
    : weights = weights != null && weights.length == 518
          ? weights
          : List.filled(518, 0);
  List<double> vector(MediaItem a, Features f) => [
    1,
    (math.log(1 + f.bytes / 1048576) / 8).clamp(0, 1),
    f.screenshot ? 1 : 0,
    f.blur == null ? 0 : (1 - f.blur! / 300).clamp(0, 1),
    a.video ? 1 : 0,
    a.favorite ? 1 : 0,
    ...List.generate(512, (i) => i < f.embedding.length ? f.embedding[i] : 0.0),
  ];
  double predict(List<double> x) {
    var z = 0.0;
    for (var i = 0; i < weights.length; i++) {
      z += weights[i] * x[i];
    }
    return 1 / (1 + math.exp(-z.clamp(-30, 30)));
  }

  void update(List<double> x, bool delete) {
    final error = (delete ? 1 : 0) - predict(x);
    for (var i = 0; i < weights.length; i++) {
      weights[i] += 0.15 * (error * x[i] - 0.001 * weights[i]);
    }
    labels++;
  }

  bool get canRank => labels >= 100;
  bool eligible(MediaItem a, Features f) =>
      !a.favorite && canRank && predict(vector(a, f)) >= 0.9;
}

int hamming(String a, String b) {
  if (a.length != b.length || a.isEmpty) return 64;
  var n = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) n++;
  }
  return n;
}

bool screenshotHint(String? title, {int appleSubtype = 0}) =>
    (appleSubtype & 4) != 0 ||
    RegExp(r'screen[ _-]?shot', caseSensitive: false).hasMatch(title ?? '');

String formatBytes(num bytes) {
  if (bytes >= 1073741824) {
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
