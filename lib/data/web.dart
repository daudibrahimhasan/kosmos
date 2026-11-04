import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';
import '../ml/quality.dart';
import 'demo.dart';

@JS('mikroReadState')
external JSPromise<JSString> _readState();
@JS('mikroWriteState')
external JSPromise<JSAny?> _writeState(
  JSString state,
  JSString patch,
  JSString removed,
);
@JS('mikroMedia')
external JSPromise<JSString> _media();
@JS('mikroThumbnail')
external JSPromise<JSUint8Array> _thumbnail(JSString id);
@JS('mikroImport')
external JSPromise<JSString> _import();
@JS('mikroDelete')
external JSPromise<JSString> _delete(JSString ids);

GalleryRepository createGallery({bool demo = false}) => BrowserGallery();
LocalStore createStore({bool demo = false}) => BrowserStore();

class BrowserGallery extends DemoGallery {
  BrowserGallery() : super(neural: true);
  bool _imported = false;
  final Map<String, Map<String, dynamic>> _files = {};
  @override
  bool get demo => !_imported;
  @override
  bool get canImport => true;
  @override
  String get libraryLabel =>
      demo ? 'SAMPLE PHOTOS · REAL LOCAL AI' : 'BROWSER LIBRARY · LOCAL AI';
  @override
  String get deletionExplanation =>
      'Only copies imported into this browser are removed. Original files on your device are untouched.';
  @override
  Future<bool> importPhotos() async {
    final result = jsonDecode((await _import().toDart).toDart) as Map;
    if (result['added'] == 0 && result['skipped'] > 0) {
      throw StateError(
        'No supported photos imported. Use JPEG, PNG or WebP files under 32 MB and check available browser storage.',
      );
    }
    if (result['added'] > 0) _imported = true;
    return result['added'] > 0;
  }

  @override
  Future<List<MediaItem>> load() async {
    final data = jsonDecode((await _media().toDart).toDart) as Map;
    _imported = data['imported'];
    if (!_imported) return super.load();
    _files
      ..clear()
      ..addEntries(
        (data['items'] as List).map(
          (e) => MapEntry(e['id'] as String, Map<String, dynamic>.from(e)),
        ),
      );
    return _files.values
        .map(
          (e) => MediaItem(
            id: e['id'],
            created: DateTime.fromMillisecondsSinceEpoch(e['created']),
            modified: DateTime.fromMillisecondsSinceEpoch(e['created']),
            width: e['width'],
            height: e['height'],
            bytes: e['bytes'],
            album: 'Imported photos',
          ),
        )
        .toList();
  }

  @override
  Future<Uint8List?> thumbnail(MediaItem item, {int size = 500}) async => demo
      ? super.thumbnail(item, size: size)
      : (await _thumbnail(item.id.toJS).toDart).toDart;
  @override
  Future<Features> analyze(MediaItem item, {Features? cached}) async {
    if (demo) return super.analyze(item, cached: cached);
    final bytes = await thumbnail(item);
    if (bytes == null) throw StateError('Imported photo is missing.');
    final base =
        cached ??
        thumbnailQuality(
          bytes,
          hash: _files[item.id]!['hash'],
          size: item.bytes,
        );
    return ai.analyze(bytes, base, people: peopleEnabled);
  }

  @override
  Future<DeleteResult> delete(Set<String> reviewedIds) async {
    if (demo) return super.delete(reviewedIds);
    final deleted = Set<String>.from(
      jsonDecode(
        (await _delete(jsonEncode(reviewedIds.toList()).toJS).toDart).toDart,
      ),
    );
    for (final id in deleted) {
      _files.remove(id);
    }
    return DeleteResult(deleted, reviewedIds.difference(deleted));
  }
}

class BrowserStore extends LocalStore {
  Map<String, dynamic> _last = {};
  @override
  Future<Map<String, dynamic>> read() async {
    final raw = (await _readState().toDart).toDart;
    if (raw.isNotEmpty) {
      final state = jsonDecode(raw) as Map<String, dynamic>;
      _last = Map<String, dynamic>.from(state['features'] ?? {});
      return state;
    }
    final prefs = await SharedPreferences.getInstance(),
        legacy = prefs.getString('mikro-demo-v1');
    if (legacy == null) return {};
    final state = jsonDecode(legacy) as Map<String, dynamic>;
    await save(state);
    await prefs.remove('mikro-demo-v1');
    return state;
  }

  @override
  Future<void> save(Map<String, dynamic> state) async {
    final features = Map<String, dynamic>.from(state['features'] ?? {}),
        patch = <String, String>{};
    for (final e in features.entries) {
      if (!identical(_last[e.key], e.value)) patch[e.key] = jsonEncode(e.value);
    }
    final removed = _last.keys
        .where((id) => !features.containsKey(id))
        .toList();
    final meta = Map<String, dynamic>.of(state)..remove('features');
    await _writeState(
      jsonEncode(meta).toJS,
      jsonEncode(patch).toJS,
      jsonEncode(removed).toJS,
    ).toDart;
    _last = features;
  }
}
