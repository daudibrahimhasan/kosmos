import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/controller.dart';
import 'package:mikro/core/models.dart';
import 'package:mikro/data/demo.dart';

class MemoryStore extends LocalStore {
  Map<String, dynamic> value = {};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read() async => value;
  @override
  Future<void> save(Map<String, dynamic> state) async {
    if (fail) throw StateError('Disk full');
    value = jsonDecode(jsonEncode(state));
  }
}

class FakeGallery extends GalleryRepository {
  @override
  bool get demo => false;
  int calls = 0, analyses = 0;
  final now = DateTime(2026, 11, 3);
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<MediaItem>> load() async => [
    for (final id in ['a', 'b', 'c'])
      MediaItem(id: id, created: now, modified: now, bytes: 100),
  ];
  @override
  Future<Uint8List?> thumbnail(MediaItem a, {int size = 500}) async => null;
  @override
  Future<Features> analyze(MediaItem a, {Features? cached}) async {
    analyses++;
    return const Features(
      hash: 'identical',
      phash: '0000',
      bytes: 100,
      blur: 200,
    );
  }

  @override
  Future<DeleteResult> delete(Set<String> ids) async {
    calls++;
    return DeleteResult(ids.contains('a') ? {'a'} : {}, ids.difference({'a'}));
  }

  @override
  Future<void> openSettings() async {}
}

void main() {
  late FakeGallery gallery;
  late MemoryStore store;
  late GalleryController c;
  setUp(() async {
    gallery = FakeGallery();
    store = MemoryStore();
    c = GalleryController(gallery, store);
    await c.init();
    await c.connect();
  });
  test(
    'swipe delete only queues; partial deletion cleans only confirmed IDs',
    () async {
      await c.scan();
      await c.decide(c.items.first, Decision.delete);
      expect(gallery.calls, 0);
      expect(c.pending, {'a'});
      expect(c.items.length, 3);
      final result = await c.deleteReviewed({'a', 'b'});
      expect(result.deleted, {'a'});
      expect(result.failed, {'b'});
      expect(c.items.map((a) => a.id), ['b', 'c']);
      expect(c.features.keys, contains('b'));
      expect(c.features.keys, isNot(contains('a')));
      expect(c.decisions.keys, isNot(contains('a')));
      expect(c.saved, 100);
      expect(c.audit.single['status'], 'partial');
      final restored = GalleryController(gallery, store);
      await restored.init();
      expect(restored.saved, 100);
      expect(restored.features.keys, isNot(contains('a')));
    },
  );
  test(
    'empty or stale review cannot reach destructive platform call',
    () async {
      await expectLater(c.deleteReviewed({}), throwsArgumentError);
      await expectLater(c.deleteReviewed({'missing'}), throwsArgumentError);
      expect(gallery.calls, 0);
    },
  );
  test('failed durable intent prevents OS deletion', () async {
    store.fail = true;
    await expectLater(c.deleteReviewed({'a'}), throwsStateError);
    expect(gallery.calls, 0);
    expect(c.saved, 0);
    expect(c.deleting, false);
  });
  test(
    'scan caches unchanged assets and finds exact duplicate group',
    () async {
      await c.scan();
      expect(gallery.analyses, 3);
      expect(c.groups(CleanKind.duplicates).single.items.length, 3);
      await c.scan();
      expect(gallery.analyses, 3);
    },
  );
  test(
    'skip is not training data, repeated decisions cannot inflate labels',
    () async {
      await c.scan();
      await c.decide(c.items.first, Decision.skip);
      expect(c.model.labels, 0);
      await c.decide(c.items.first, Decision.delete);
      await c.decide(c.items.first, Decision.delete);
      expect(c.model.labels, 1);
      expect(c.model.canRank, false);
      await c.resetLearning();
      expect(c.pending, isEmpty);
      expect(c.model.labels, 0);
    },
  );
  test('model learns locally and cold-start blocks predictions', () {
    final m = PreferenceModel();
    final a = c.items.first;
    const f = Features(bytes: 100, screenshot: true);
    expect(m.eligible(a, f), false);
    for (var i = 0; i < 200; i++) {
      m.update(m.vector(a, f), true);
    }
    expect(m.predict(m.vector(a, f)), greaterThan(.9));
    expect(m.eligible(a, f), true);
    final favorite = MediaItem(
      id: 'fav',
      created: a.created,
      modified: a.modified,
      favorite: true,
    );
    expect(m.eligible(favorite, f), false);
  });
  test('hamming rejects missing hashes and checks threshold', () {
    expect(hamming('', ''), 64);
    expect(hamming('0000', '0011'), 2);
  });
  test(
    'screenshot metadata and filename fallback do not classify arbitrary photos',
    () {
      expect(screenshotHint(null, appleSubtype: 4), true);
      expect(screenshotHint('Screen_Shot_2026.png'), true);
      expect(screenshotHint('Screenshot_2026.jpg'), true);
      expect(screenshotHint('IMG_2026.jpg'), false);
    },
  );
  test('sample deletions stay removed after restart', () async {
    final s = MemoryStore();
    final first = GalleryController(DemoGallery(), s);
    await first.init();
    final id = first.items.first.id;
    await first.deleteReviewed({id});
    final restored = GalleryController(DemoGallery(), s);
    await restored.init();
    expect(restored.items.length, 29);
    expect(restored.items.any((a) => a.id == id), false);
  });
  test('failed review persistence rolls back queue and decision', () async {
    await c.scan();
    store.fail = true;
    await expectLater(
      c.decide(c.items.first, Decision.delete),
      throwsStateError,
    );
    expect(c.pending, isEmpty);
    expect(c.decisions, isEmpty);
    expect(c.model.labels, 0);
  });
  test(
    'changing an explicit decision to skip removes it from training',
    () async {
      await c.scan();
      await c.decide(c.items.first, Decision.delete);
      await c.decide(c.items.first, Decision.skip);
      expect(c.model.labels, 0);
      expect(c.pending, isEmpty);
    },
  );
}
