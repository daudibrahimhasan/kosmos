import 'package:flutter/foundation.dart';
import 'dart:async';
import 'vectors.dart';
import '../ml/engine.dart';
import 'models.dart';

class GalleryController extends ChangeNotifier {
  final GalleryRepository repository;
  final LocalStore store;
  GalleryController(this.repository, this.store);
  List<MediaItem> items = [];
  Map<String, Features> features = {};
  Map<String, String> decisions = {};
  Map<String, int> stamps = {};
  List<Map<String, dynamic>> audit = [];
  Set<String> pending = {};
  Set<String> removedSamples = {};
  Map<String, String> faceGroups = {}, personNames = {};
  Set<String> excludedFaces = {};
  bool peopleEnabled = false, changingPeople = false;
  int nextPerson = 1;
  Completer<void>? _scanDone;
  final Map<String, Features> _encodedObjects = {};
  final Map<String, Map<String, dynamic>> _encodedFeatures = {};
  PreferenceModel model = PreferenceModel();
  bool ready = false,
      allowed = false,
      busy = false,
      scanning = false,
      deleting = false;
  bool dark = true;
  int scanned = 0, scanFailures = 0, saved = 0;
  String? error;
  Future<void> _writes = Future.value();
  bool _pause = false;
  bool get demo => repository.demo;
  int sizeOf(MediaItem a) => features[a.id]?.bytes ?? a.bytes;
  int get totalBytes => items.fold(0, (n, a) => n + sizeOf(a));
  int get reviewed => decisions.length;

  Future<void> init() async {
    try {
      final s = await store.read();
      dark = s['dark'] ?? true;
      saved = s['saved'] ?? 0;
      features = (s['features'] as Map? ?? {}).map(
        (k, v) => MapEntry(
          k.toString(),
          Features.fromJson(Map<String, dynamic>.from(v)),
        ),
      );
      stamps = Map<String, int>.from(s['stamps'] ?? {});
      decisions = Map<String, String>.from(s['decisions'] ?? {});
      pending = Set<String>.from(s['pending'] ?? []);
      peopleEnabled = s['peopleEnabled'] ?? false;
      repository.peopleEnabled = peopleEnabled;
      faceGroups = Map<String, String>.from(s['faceGroups'] ?? {});
      personNames = Map<String, String>.from(s['personNames'] ?? {});
      excludedFaces = Set<String>.from(s['excludedFaces'] ?? []);
      nextPerson = s['nextPerson'] ?? 1;
      if (!peopleEnabled) _stripFaces();
      removedSamples = Set<String>.from(s['removedSamples'] ?? []);
      audit = (s['audit'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final compatible = s['modelVersion'] == PreferenceModel.version;
      final w = compatible ? s['weights'] as List? : null;
      model = PreferenceModel(
        weights: w?.map((e) => (e as num).toDouble()).toList(),
        labels: compatible ? s['labels'] ?? 0 : 0,
      );
      if (!peopleEnabled) await persist();
      if (demo) await connect();
    } catch (_) {
      error = 'Could not open local data. Restart the app to try again.';
    }
    ready = true;
    notifyListeners();
  }

  Future<void> persist() {
    _encodedObjects.removeWhere((id, _) => !features.containsKey(id));
    _encodedFeatures.removeWhere((id, _) => !features.containsKey(id));
    for (final e in features.entries) {
      if (!identical(_encodedObjects[e.key], e.value)) {
        _encodedObjects[e.key] = e.value;
        _encodedFeatures[e.key] = e.value.toJson();
      }
    }
    final snapshot = <String, dynamic>{
      'dark': dark,
      'saved': saved,
      'features': Map<String, dynamic>.of(_encodedFeatures),
      'peopleEnabled': peopleEnabled,
      'faceGroups': Map.of(faceGroups),
      'personNames': Map.of(personNames),
      'excludedFaces': excludedFaces.toList(),
      'nextPerson': nextPerson,
      'stamps': Map.of(stamps),
      'decisions': Map.of(decisions),
      'pending': pending.toList(),
      'removedSamples': removedSamples.toList(),
      'audit': audit.map((a) => Map.of(a)).toList(),
      'weights': List.of(model.weights),
      'labels': model.labels,
      'modelVersion': PreferenceModel.version,
    };
    // Serialize snapshots so older writes can never overwrite a newer decision.
    final write = _writes.then((_) => store.save(snapshot));
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<void> connect() async {
    if (busy || scanning || deleting) return;
    busy = true;
    error = null;
    notifyListeners();
    var resumePeopleScan = false;
    try {
      allowed = await repository.requestAccess();
      if (allowed) {
        final found = await repository.load();
        items = demo
            ? found.where((a) => !removedSamples.contains(a.id)).toList()
            : found;
        final ids = items.map((a) => a.id).toSet();
        features.removeWhere((k, v) => !ids.contains(k));
        stamps.removeWhere((k, v) => !ids.contains(k));
        decisions.removeWhere((k, v) => !ids.contains(k));
        pending.removeWhere((id) => !ids.contains(id));
        _rebuildPeople();
        _retrain();
        await persist();
        resumePeopleScan =
            peopleEnabled &&
            items.any(
              (a) => features[a.id]?.faceVersion != AiEngine.faceVersion,
            );
      }
    } catch (_) {
      error =
          'The library could not be loaded. Check photo access and try again.';
    }
    busy = false;
    notifyListeners();
    if (resumePeopleScan) await scan();
  }

  Future<void> scan() async {
    if (scanning || !allowed || deleting || busy) return;
    scanning = true;
    _pause = false;
    scanFailures = 0;
    error = null;
    scanned = 0;
    _scanDone = Completer<void>();
    notifyListeners();
    try {
      for (final a in List<MediaItem>.of(items)) {
        if (_pause) break;
        final sameAsset = stamps[a.id] == a.modified.millisecondsSinceEpoch;
        final old = features[a.id];
        if (!sameAsset ||
            old?.version != repository.analysisVersion ||
            (peopleEnabled && old?.faceVersion != AiEngine.faceVersion)) {
          try {
            var result = await repository.analyze(
              a,
              cached: sameAsset ? old : null,
            );
            if (!peopleEnabled) result = result.withAi(clearFaces: true);
            features[a.id] = result;
            stamps[a.id] = a.modified.millisecondsSinceEpoch;
          } catch (e) {
            scanFailures++;
            error = 'Analysis failed for $scanFailures items. ${e.toString()}';
          }
        }
        scanned++;
        await persist();
        notifyListeners();
      }
      _rebuildPeople();
      _retrain();
      await persist();
    } catch (_) {
      error = 'Scan paused because local data could not be saved. Try again.';
    } finally {
      scanning = false;
      _scanDone?.complete();
      _scanDone = null;
      notifyListeners();
    }
  }

  void pause() {
    _pause = true;
  }

  List<ReviewGroup> groups(CleanKind kind) {
    final out = <ReviewGroup>[];
    if (kind == CleanKind.personal) {
      final queued = items.where((a) => pending.contains(a.id)).toList();
      final predicted = items
          .where(
            (a) =>
                !pending.contains(a.id) &&
                decisions[a.id] != 'keep' &&
                features[a.id] != null &&
                model.eligible(a, features[a.id]!),
          )
          .toList();
      if (queued.isNotEmpty) {
        out.add(
          ReviewGroup(
            'Your choices',
            'You added these items to the deletion queue. Check them again before approving.',
            queued,
          ),
        );
      }
      if (predicted.isNotEmpty) {
        out.add(
          ReviewGroup(
            'Personal suggestions',
            'Local model suggestions after 100 explicit labels. Probabilities are not calibrated; these are not deletion decisions.',
            predicted,
          ),
        );
      }
      return out;
    }
    if (kind == CleanKind.duplicates) {
      final buckets = <String, List<MediaItem>>{};
      for (final a in items) {
        final f = features[a.id];
        if (f != null && f.hash.isNotEmpty) (buckets[f.hash] ??= []).add(a);
      }
      for (final group in buckets.values.where((g) => g.length > 1)) {
        group.sort(
          (a, b) => (b.favorite ? 1 : 0).compareTo(a.favorite ? 1 : 0),
        );
        out.add(
          ReviewGroup(
            'Identical files',
            'Same SHA-256 file hash. Keep at least one copy.',
            group,
            bestId: group.first.id,
          ),
        );
      }
      return out;
    }
    if (kind == CleanKind.similar &&
        features.values.any((f) => f.embedding.length == 512)) {
      final buckets = <String, List<MediaItem>>{},
          groups = <List<MediaItem>>[],
          membership = <String, int>{};
      final photos = items
          .where((a) => !a.video && features[a.id]?.embedding.length == 512)
          .toList();
      for (final item in photos) {
        final vector = features[item.id]!.embedding;
        final candidates = <MediaItem>{};
        for (final band in embeddingBands(vector)) {
          candidates.addAll((buckets[band] ?? const []).reversed.take(100));
        }
        MediaItem? best;
        var similarity = .94;
        for (final anchor in candidates) {
          final score = cosine(vector, features[anchor.id]!.embedding);
          if (score >= similarity) {
            best = anchor;
            similarity = score;
          }
        }
        if (best != null) {
          groups[membership[best.id]!].add(item);
        } else {
          membership[item.id] = groups.length;
          groups.add([item]);
          for (final band in embeddingBands(vector)) {
            (buckets[band] ??= []).add(item);
          }
        }
      }
      for (final group in groups.where((g) => g.length > 1)) {
        group.sort((a, b) {
          final fav = (b.favorite ? 1 : 0).compareTo(a.favorite ? 1 : 0);
          return fav != 0
              ? fav
              : (features[b.id]?.blur ?? 0).compareTo(
                  features[a.id]?.blur ?? 0,
                );
        });
        out.add(
          ReviewGroup(
            'Visually similar',
            'High TinyCLIP similarity, with candidate prefiltering. Similarity can group different scenes. Best shot uses favorite state and sharpness.',
            group,
            bestId: group.first.id,
          ),
        );
      }
      return out;
    }
    if (kind == CleanKind.similar) {
      // ponytail: compare within a 30-second burst, not the entire gallery.
      // Embedding-based cross-session similarity waits for licensed model weights.
      final photos =
          items
              .where(
                (a) => !a.video && (features[a.id]?.phash.isNotEmpty ?? false),
              )
              .toList()
            ..sort((a, b) => a.created.compareTo(b.created));
      final used = <String>{};
      for (var i = 0; i < photos.length; i++) {
        final a = photos[i];
        if (used.contains(a.id)) continue;
        final group = [a];
        for (var j = i + 1; j < photos.length; j++) {
          final b = photos[j];
          if (b.created.difference(a.created).inSeconds > 30) break;
          if (!used.contains(b.id) &&
              hamming(features[a.id]!.phash, features[b.id]!.phash) <= 6) {
            group.add(b);
          }
        }
        if (group.length > 1) {
          group.sort((a, b) {
            final fav = (b.favorite ? 1 : 0).compareTo(a.favorite ? 1 : 0);
            return fav != 0
                ? fav
                : (features[b.id]?.blur ?? 0).compareTo(
                    features[a.id]?.blur ?? 0,
                  );
          });
          used.addAll(group.map((e) => e.id));
          out.add(
            ReviewGroup(
              'Similar moments',
              'Similar perceptual hash, captured within 30 seconds. Best shot is a quality heuristic.',
              group,
              bestId: group.first.id,
            ),
          );
        }
      }
      return out;
    }
    final matches = items.where((a) {
      final f = features[a.id];
      return switch (kind) {
        CleanKind.screenshots => a.screenshot || (f?.screenshot ?? false),
        CleanKind.blurry => !a.video && f?.blur != null && f!.blur! < 60,
        CleanKind.videos => a.video && sizeOf(a) >= 50 * 1048576,
        CleanKind.personal =>
          pending.contains(a.id) || (f != null && model.eligible(a, f)),
        _ => false,
      };
    }).toList()..sort((a, b) => sizeOf(b).compareTo(sizeOf(a)));
    if (matches.isNotEmpty) {
      out.add(
        ReviewGroup(kind.name, switch (kind) {
          CleanKind.screenshots =>
            'Screenshot metadata or filename hint. Review anything you still need.',
          CleanKind.blurry =>
            'Low thumbnail Laplacian variance. Intentional soft focus may be worth keeping.',
          CleanKind.videos => 'Videos larger than 50 MB, largest first.',
          _ =>
            'Items you marked for review. Nothing is deleted by a prediction.',
        }, matches),
      );
    }
    return out;
  }

  Future<void> decide(MediaItem a, Decision d) async {
    if (!items.any((item) => item.id == a.id)) {
      throw ArgumentError('Item is no longer in the library.');
    }
    final before = decisions[a.id];
    final wasPending = pending.contains(a.id);
    final previousModel = model;
    decisions[a.id] = d.name;
    if (d == Decision.delete) {
      pending.add(a.id);
    } else {
      pending.remove(a.id);
    }
    if (before != d.name) _retrain();
    try {
      await persist();
    } catch (_) {
      if (before == null) {
        decisions.remove(a.id);
      } else {
        decisions[a.id] = before;
      }
      if (wasPending) {
        pending.add(a.id);
      } else {
        pending.remove(a.id);
      }
      model = previousModel;
      rethrow;
    }
    notifyListeners();
  }

  void _retrain() {
    // Rebuild latest labels; repeated decisions cannot inflate training count.
    model = PreferenceModel();
    for (final item in items) {
      final label = decisions[item.id];
      final f = features[item.id];
      if (f != null && (label == 'keep' || label == 'delete')) {
        model.update(model.vector(item, f), label == 'delete');
      }
    }
  }

  Future<DeleteResult> deleteReviewed(Set<String> selected) async {
    if (deleting || scanning) {
      throw StateError('Wait for the current operation to finish.');
    }
    final ids = items.map((a) => a.id).toSet();
    if (selected.isEmpty || !ids.containsAll(selected)) {
      throw ArgumentError('Review valid items before deleting.');
    }
    deleting = true;
    notifyListeners();
    try {
      // Durable intent is written BEFORE any destructive OS call.
      final entry = <String, dynamic>{
        'at': DateTime.now().toIso8601String(),
        'requested': selected.length,
        'deleted': 0,
        'failed': 0,
        'bytes': 0,
        'status': 'requested',
      };
      audit.add(entry);
      await persist();
      final result = await repository.delete(Set.of(selected));
      final successful = result.deleted.intersection(selected);
      if (demo) removedSamples.addAll(successful);
      final bytes = items
          .where((a) => successful.contains(a.id))
          .fold(0, (n, a) => n + sizeOf(a));
      items.removeWhere((a) => successful.contains(a.id));
      for (final id in successful) {
        features.remove(id);
        stamps.remove(id);
        decisions.remove(id);
        pending.remove(id);
      }
      _rebuildPeople();
      _retrain();
      saved += bytes;
      entry.addAll({
        'deleted': successful.length,
        'failed': selected.length - successful.length,
        'bytes': bytes,
        'status': successful.length == selected.length
            ? 'completed'
            : 'partial',
      });
      await persist();
      return DeleteResult(successful, selected.difference(successful));
    } finally {
      deleting = false;
      notifyListeners();
    }
  }

  Map<String, PersonFace> get allFaces {
    final result = <String, PersonFace>{};
    if (!peopleEnabled) return result;
    for (final item in items) {
      for (final face in features[item.id]?.faces ?? const <FaceSample>[]) {
        final key = face.key(item.id);
        result[key] = PersonFace(key, item, face);
      }
    }
    return result;
  }

  Map<String, List<PersonFace>> get peopleGroups {
    final groups = <String, List<PersonFace>>{};
    for (final face in allFaces.values) {
      final group = faceGroups[face.key];
      if (group != null && !excludedFaces.contains(face.key)) {
        (groups[group] ??= []).add(face);
      }
    }
    return groups;
  }

  String personName(String id) =>
      personNames[id] ?? 'Person ${id.split('-').last}';
  void _stripFaces() {
    features = features.map(
      (id, f) => MapEntry(id, f.withAi(clearFaces: true)),
    );
    faceGroups.clear();
    personNames.clear();
    excludedFaces.clear();
    nextPerson = 1;
  }

  void _rebuildPeople() {
    if (!peopleEnabled) {
      _stripFaces();
      return;
    }
    final faces = allFaces;
    faceGroups.removeWhere((key, _) => !faces.containsKey(key));
    excludedFaces.removeWhere((key) => !faces.containsKey(key));
    final anchors = <String, List<PersonFace>>{};
    for (final entry in faceGroups.entries) {
      if (!excludedFaces.contains(entry.key)) {
        (anchors[entry.value] ??= []).add(faces[entry.key]!);
      }
    }
    for (final values in anchors.values) {
      values.sort((a, b) => b.face.quality.compareTo(a.face.quality));
    }
    for (final face in faces.values) {
      if (faceGroups.containsKey(face.key) ||
          excludedFaces.contains(face.key)) {
        continue;
      }
      var best = -1.0, second = -1.0;
      String? candidate;
      for (final entry in anchors.entries) {
        var score = -1.0;
        for (final anchor in entry.value.take(3)) {
          final value = cosine(face.face.embedding, anchor.face.embedding);
          if (value > score) score = value;
        }
        if (score > best) {
          second = best;
          best = score;
          candidate = entry.key;
        } else if (score > second) {
          second = score;
        }
      }
      final group = best >= .55 && best - second >= .08
          ? candidate!
          : 'person-${nextPerson++}';
      faceGroups[face.key] = group;
      (anchors[group] ??= []).add(face);
    }
    final used = faceGroups.values.toSet();
    personNames.removeWhere((id, _) => !used.contains(id));
  }

  Future<void> setPeopleEnabled(bool value) async {
    if (changingPeople) return;
    changingPeople = true;
    peopleEnabled = value;
    repository.peopleEnabled = value;
    if (!value) {
      _pause = true;
      _stripFaces();
    }
    notifyListeners();
    try {
      await persist();
      if (!value) {
        await _scanDone?.future;
        await repository.clearFaceModels();
        _stripFaces();
        await persist();
        await store.compact();
      } else {
        await scan();
      }
    } catch (_) {
      error = value
          ? 'Could not save the people setting. Try again.'
          : 'Face erasure could not be saved. Keep grouping off and retry Erase face data.';
      rethrow;
    } finally {
      changingPeople = false;
      notifyListeners();
    }
  }

  Future<void> _editPeople(void Function() edit) async {
    final oldGroups = Map<String, String>.of(faceGroups),
        oldNames = Map<String, String>.of(personNames),
        oldExcluded = Set<String>.of(excludedFaces),
        oldNext = nextPerson;
    try {
      edit();
      _rebuildPeople();
      await persist();
    } catch (_) {
      faceGroups = oldGroups;
      personNames = oldNames;
      excludedFaces = oldExcluded;
      nextPerson = oldNext;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> renamePerson(String group, String name) => _editPeople(() {
    if (!peopleGroups.containsKey(group)) {
      throw ArgumentError('Group no longer exists.');
    }
    final clean = name.trim();
    if (clean.length > 40) throw ArgumentError('Use at most 40 characters.');
    if (clean.isEmpty) {
      personNames.remove(group);
    } else {
      personNames[group] = clean;
    }
  });
  Future<void> mergePeople(String source, String target) => _editPeople(() {
    if (source == target ||
        !peopleGroups.containsKey(source) ||
        !peopleGroups.containsKey(target)) {
      throw ArgumentError('Choose two different groups.');
    }
    faceGroups.updateAll((key, group) => group == source ? target : group);
    personNames.remove(source);
  });
  Future<void> splitFaces(Set<String> keys) => _editPeople(() {
    if (keys.isEmpty || !allFaces.keys.toSet().containsAll(keys)) {
      throw ArgumentError('Select current faces.');
    }
    final group = 'person-${nextPerson++}';
    for (final key in keys) {
      excludedFaces.remove(key);
      faceGroups[key] = group;
    }
  });
  Future<void> removeFaces(Set<String> keys) => _editPeople(() {
    for (final key in keys) {
      faceGroups.remove(key);
      excludedFaces.add(key);
    }
  });
  Future<void> importPhotos() async {
    if (scanning || deleting || busy) return;
    final wasDemo = demo;
    try {
      if (!await repository.importPhotos()) return;
      if (wasDemo && !demo) {
        items = [];
        features = {};
        stamps = {};
        decisions = {};
        pending = {};
        removedSamples = {};
        audit = [];
        saved = 0;
        peopleEnabled = false;
        repository.peopleEnabled = false;
        _stripFaces();
        model = PreferenceModel();
        await persist();
      }
      await connect();
    } catch (e) {
      error = 'Could not import photos. $e';
      notifyListeners();
    }
  }

  List<MediaItem> reviewCandidates() {
    final candidates = List<MediaItem>.of(items);
    double score(MediaItem a) {
      final f = features[a.id];
      if (f == null) return 0;
      final p = model.predict(model.vector(a, f));
      return (f.screenshot ? 2 : 0) +
          (f.blur != null && f.blur! < 60 ? 2 : 0) +
          sizeOf(a) / 1073741824 +
          (model.labels >= 25 ? 1 - (p - .5).abs() * 2 : 0);
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    final buckets = <String, List<MediaItem>>{};
    for (final a in candidates) {
      (buckets[features[a.id]?.category ?? 'Other'] ??= []).add(a);
    }
    final result = <MediaItem>[];
    var index = 0;
    while (result.length < candidates.length) {
      for (final bucket in buckets.values) {
        if (index < bucket.length) result.add(bucket[index]);
      }
      index++;
    }
    return result;
  }

  Future<void> toggleTheme(bool value) async {
    dark = value;
    await persist();
    notifyListeners();
  }

  Future<void> resetLearning() async {
    model = PreferenceModel();
    decisions.clear();
    pending.clear();
    await persist();
    notifyListeners();
  }
}

class PersonFace {
  final String key;
  final MediaItem item;
  final FaceSample face;
  const PersonFace(this.key, this.item, this.face);
}
