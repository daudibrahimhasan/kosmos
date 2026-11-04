import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/controller.dart';
import 'package:mikro/core/models.dart';
import 'package:mikro/core/vectors.dart';
import 'package:mikro/ml/engine.dart';
import 'package:mikro/ml/vision.dart';
import 'safety_test.dart' show FakeGallery, MemoryStore;

List<double> axis(int size, int index) =>
    List.generate(size, (i) => i == index ? 1.0 : 0.0);

class FaceGallery extends FakeGallery {
  int released = 0;
  @override
  bool get neural => true;
  @override
  Future<Features> analyze(MediaItem a, {Features? cached}) async {
    analyses++;
    final same = a.id != 'c';
    return Features(
      hash: a.id,
      bytes: 100,
      blur: 200,
      embedding: axis(512, same ? 0 : 1),
      faceVersion: peopleEnabled ? AiEngine.faceVersion : null,
      faces: peopleEnabled
          ? [
              FaceSample(const [.2, .2, .3, .3], axis(128, same ? 0 : 1), .95),
            ]
          : const [],
    );
  }

  @override
  Future<void> clearFaceModels() async {
    released++;
  }
}

void main() {
  test(
    'connect resumes an opted-in face scan after the library loads',
    () async {
      final gallery = FaceGallery(),
          store = MemoryStore()..value = {'peopleEnabled': true};
      final c = GalleryController(gallery, store);
      await c.init();
      await c.connect();
      expect(c.peopleEnabled, true);
      expect(
        c.features.values.every((f) => f.faceVersion == AiEngine.faceVersion),
        true,
      );
      expect(c.peopleGroups.length, 2);
    },
  );
  test(
    'people grouping, corrections, restart and complete face erasure',
    () async {
      final gallery = FaceGallery(),
          store = MemoryStore(),
          c = GalleryController(gallery, store);
      await c.init();
      await c.connect();
      await c.scan();
      expect(c.allFaces, isEmpty);
      await c.setPeopleEnabled(true);
      expect(c.peopleGroups.length, 2);
      final first = c.peopleGroups.entries.first;
      await c.renamePerson(first.key, 'Friend');
      final other = c.peopleGroups.keys.firstWhere((id) => id != first.key);
      await c.mergePeople(other, first.key);
      expect(c.peopleGroups.length, 1);
      expect(c.personName(first.key), 'Friend');
      final key = c.peopleGroups[first.key]!.first.key;
      await c.splitFaces({key});
      expect(c.peopleGroups.length, 2);
      await c.removeFaces({key});
      expect(c.peopleGroups.length, 1);
      expect(c.excludedFaces, contains(key));
      await c.scan();
      expect(c.faceGroups.containsKey(key), false);
      final restored = GalleryController(FaceGallery(), store);
      await restored.init();
      await restored.connect();
      expect(restored.excludedFaces, contains(key));
      expect(restored.peopleGroups.length, 1);
      await restored.setPeopleEnabled(false);
      expect(
        restored.features.values.every(
          (f) => f.faces.isEmpty && f.faceVersion == null,
        ),
        true,
      );
      expect(
        restored.features.values.every((f) => f.embedding.length == 512),
        true,
      );
      expect(store.value['faceGroups'], isEmpty);
      expect(store.value['personNames'], isEmpty);
      expect(store.value['excludedFaces'], isEmpty);
      final again = GalleryController(FaceGallery(), store);
      await again.init();
      await again.connect();
      expect(again.peopleEnabled, false);
      expect(again.allFaces, isEmpty);
    },
  );
  test(
    'semantic similarity and confirmed deletion remove corresponding face records',
    () async {
      final c = GalleryController(FaceGallery(), MemoryStore());
      await c.init();
      await c.connect();
      await c.setPeopleEnabled(true);
      final group = c.groups(CleanKind.similar).single;
      expect(group.items.map((a) => a.id).toSet(), {'a', 'b'});
      await c.deleteReviewed({'a', 'b'});
      expect(c.allFaces.values.any((f) => f.item.id == 'a'), false);
      expect(c.faceGroups.keys.any((key) => key.startsWith('a/')), false);
      expect(c.allFaces.values.any((f) => f.item.id == 'b'), true);
    },
  );
  test(
    'personal model learns distinct TinyCLIP vectors, with cold-start and keep override',
    () async {
      final g = FaceGallery(), c = GalleryController(g, MemoryStore());
      await c.init();
      await c.connect();
      await c.scan();
      final a = c.items.first,
          b = c.items.last,
          fa = c.features[a.id]!,
          fb = c.features[b.id]!;
      final model = PreferenceModel();
      expect(model.vector(a, fa).length, 518);
      expect(model.eligible(a, fa), false);
      for (var i = 0; i < 300; i++) {
        model.update(model.vector(a, fa), true);
        model.update(model.vector(b, fb), false);
      }
      expect(model.predict(model.vector(a, fa)), greaterThan(.9));
      expect(model.predict(model.vector(b, fb)), lessThan(.1));
      c.model = model;
      c.decisions[a.id] = 'keep';
      expect(
        c
            .groups(CleanKind.personal)
            .expand((g) => g.items)
            .any((i) => i.id == a.id),
        false,
      );
    },
  );
  test('alignment inverts a known transformed SFace template', () {
    const target = [
      38.2946,
      51.6963,
      73.5318,
      51.5014,
      56.0252,
      71.7366,
      41.5493,
      92.3655,
      70.7299,
      92.2041,
    ];
    final m = alignment(target.map((v) => v * 2 + 10).toList());
    expect(m[0], closeTo(.5, 1e-7));
    expect(m[4], closeTo(.5, 1e-7));
    expect(m[2], closeTo(-5, 1e-7));
    expect(m[5], closeTo(-5, 1e-7));
  });
  test(
    'YuNet decoding suppresses overlapping detections and rejects empty results',
    () {
      final outputs = <String, List<double>>{};
      for (final stride in [8, 16, 32]) {
        final cells = (320 ~/ stride) * (320 ~/ stride);
        outputs['cls_$stride'] = List.filled(cells, 0);
        outputs['obj_$stride'] = List.filled(cells, 0);
        outputs['bbox_$stride'] = List.filled(cells * 4, 0);
        outputs['kps_$stride'] = List.filled(cells * 10, 0);
      }
      expect(decodeYuNet(outputs, 320, 320), isEmpty);
      for (final index in [820, 821]) {
        outputs['cls_8']![index] = .99;
        outputs['obj_8']![index] = .99;
        outputs['bbox_8']![index * 4] = 20 - index % 40;
        outputs['bbox_8']![index * 4 + 1] = 0;
        outputs['bbox_8']![index * 4 + 2] = math.log(8);
        outputs['bbox_8']![index * 4 + 3] = math.log(8);
        for (var j = 0; j < 10; j++) {
          outputs['kps_8']![index * 10 + j] = j.isEven
              ? (j == 0 ? -1.5 : 1.5) - (index % 40 - 20)
              : 0;
        }
      }
      expect(decodeYuNet(outputs, 320, 320).length, 1);
      expect(unitVector([double.nan, 0]), isEmpty);
      expect(cosine(axis(128, 0), axis(128, 1)), 0);
      expect(faceSharpness(Float32List(3 * 112 * 112)), 0);
    },
  );
}
