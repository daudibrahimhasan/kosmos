import 'package:flutter/services.dart';
import '../core/models.dart';
import 'package:crypto/crypto.dart';
import '../ml/engine.dart';
import '../ml/quality.dart';

// Explicit fixtures, never model output. Photos are bundled, not fetched at runtime.
class DemoGallery extends GalleryRepository {
  @override
  String get analysisVersion => neural ? AiEngine.version : 'demo-fixture-v1';
  @override
  final bool neural;
  final AiEngine ai = AiEngine();
  @override
  String get libraryLabel =>
      neural ? 'SAMPLE PHOTOS · REAL LOCAL AI' : super.libraryLabel;
  @override
  Future<void> clearFaceModels() => ai.closeFaces();
  @override
  bool get demo => true;
  final List<MediaItem> _items = [];
  DemoGallery({this.neural = false}) {
    final now = DateTime(2026, 11, 3, 16);
    const names = [
      'coast',
      'mountain',
      'lake',
      'forest',
      'desert',
      'ocean',
      'flower',
      'city',
      'coffee',
      'dog',
      'portrait',
      'woman',
    ];
    for (var i = 0; i < 30; i++) {
      final n = i % names.length;
      _items.add(
        MediaItem(
          id: 'sample-$i',
          demoPath: 'assets/demo/${names[n]}.jpg',
          width: 3024,
          height: 4032,
          bytes: i >= 27 ? 95000000 + i * 1000000 : 2400000 + i * 340000,
          video: i >= 27,
          duration: i >= 27 ? 64 + i : 0,
          created: now.subtract(Duration(days: i ~/ 6, seconds: i % 3)),
          modified: now,
          favorite: i == 0 || i == 7,
          screenshot: i >= 20 && i <= 23,
          album: n < 8 ? 'Outdoors' : 'Everyday',
        ),
      );
    }
  }
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<MediaItem>> load() async => List.of(_items);
  @override
  Future<Uint8List?> thumbnail(MediaItem item, {int size = 500}) async =>
      (await rootBundle.load(item.demoPath!)).buffer.asUint8List();
  @override
  Future<Features> analyze(MediaItem item, {Features? cached}) async {
    if (neural) {
      final bytes = (await rootBundle.load(
        item.demoPath!,
      )).buffer.asUint8List();
      final base =
          cached ??
          thumbnailQuality(
            bytes,
            hash: sha256.convert(bytes).toString(),
            size: item.bytes,
            video: item.video,
            screenshot: item.screenshot,
          );
      return ai.analyze(bytes, base, people: peopleEnabled, video: item.video);
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final n = int.parse(item.id.split('-').last);
    const categories = [
      'Travel',
      'Nature',
      'Travel',
      'Nature',
      'Travel',
      'Nature',
      'Nature',
      'Travel',
      'Food',
      'Pet',
      'People',
      'People',
    ];
    return Features(
      hash: item.video ? 'video-$n' : 'fixture-${n % 12}',
      phash: List.generate(64, (j) => (j + n % 3) % 4 == 0 ? '1' : '0').join(),
      category: categories[n % 12],
      blur: n % 9 == 0 ? 28 : 180 + n.toDouble(),
      bytes: item.bytes,
      screenshot: item.screenshot,
      version: 'demo-fixture-v1',
    );
  }

  @override
  Future<DeleteResult> delete(Set<String> reviewedIds) async {
    _items.removeWhere((a) => reviewedIds.contains(a.id));
    return DeleteResult(Set.of(reviewedIds), {});
  }

  @override
  Future<void> openSettings() async {}
}
