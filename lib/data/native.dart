import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';
import 'analysis.dart';
import 'demo.dart';
import '../ml/engine.dart';

GalleryRepository createGallery({bool demo = false}) =>
    demo ? DemoGallery(neural: true) : DeviceGallery();
LocalStore createStore({bool demo = false}) => DeviceStore(demo);

class DeviceGallery extends GalleryRepository {
  final AiEngine ai = AiEngine();
  @override
  bool get neural => true;
  @override
  String get analysisVersion => AiEngine.version;
  @override
  Future<void> clearFaceModels() => ai.closeFaces();
  @override
  bool get demo => false;
  final Map<String, AssetEntity> _assets = {};
  final Map<String, MediaItem> _items = {};
  @override
  Future<bool> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  @override
  Future<List<MediaItem>> load() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      _assets.clear();
      _items.clear();
      return [];
    }
    final result = <MediaItem>[];
    final assets = <String, AssetEntity>{};
    final total = await paths.first.assetCountAsync;
    for (var page = 0; page * 200 < total; page++) {
      final batch = await paths.first.getAssetListPaged(page: page, size: 200);
      for (final a in batch) {
        assets[a.id] = a;
        result.add(
          MediaItem(
            id: a.id,
            video: a.type == AssetType.video,
            width: a.width,
            height: a.height,
            duration: a.duration,
            created: a.createDateTime,
            modified: a.modifiedDateTime,
            favorite: a.isFavorite,
            screenshot:
                a.type == AssetType.image &&
                screenshotHint(a.title, appleSubtype: a.subtype),
          ),
        );
      }
    }
    _assets
      ..clear()
      ..addAll(assets);
    _items
      ..clear()
      ..addEntries(result.map((item) => MapEntry(item.id, item)));
    return result;
  }

  @override
  Future<Map<String, List<MediaItem>>> albums() async {
    final paths = await PhotoManager.getAssetPathList(type: RequestType.common);
    final result = <String, List<MediaItem>>{};
    for (final path in paths.where((p) => !p.isAll)) {
      final items = <MediaItem>[];
      final count = await path.assetCountAsync;
      for (var page = 0; page * 200 < count; page++) {
        for (final a in await path.getAssetListPaged(page: page, size: 200)) {
          final item = _items[a.id];
          if (item != null) items.add(item);
        }
      }
      var name = path.name;
      var suffix = 2;
      while (result.containsKey(name)) {
        name = '${path.name} (${suffix++})';
      }
      if (items.isNotEmpty) result[name] = items;
    }
    return result;
  }

  @override
  Future<Uint8List?> thumbnail(MediaItem item, {int size = 500}) async {
    final a = _assets[item.id];
    if (a == null || !await a.isLocallyAvailable()) return null;
    return a.thumbnailDataWithSize(ThumbnailSize(size, size));
  }

  @override
  Future<Features> analyze(MediaItem item, {Features? cached}) async {
    final a = _assets[item.id];
    if (a == null || !await a.isLocallyAvailable(isOrigin: true)) {
      throw StateError('Original is not on this device.');
    }
    final thumb = await thumbnail(item, size: 1024);
    if (thumb == null) throw StateError('Thumbnail is unavailable.');
    Features base;
    if (cached != null) {
      base = cached;
    } else {
      final file = await a.originFile;
      if (file == null) throw StateError('Original is unavailable.');
      base = await compute(analyzeFile, {
        'path': file.path,
        'video': item.video,
        'thumbnail': thumb,
        'screenshot': item.screenshot,
      });
    }
    return ai.analyze(thumb, base, people: peopleEnabled, video: item.video);
  }

  @override
  Future<String?> localVideoPath(MediaItem item) async {
    final a = _assets[item.id];
    if (a == null || !await a.isLocallyAvailable(isOrigin: true)) return null;
    return (await a.originFile)?.path;
  }

  @override
  Future<DeleteResult> delete(Set<String> reviewedIds) async {
    final valid = <String>[];
    for (final id in reviewedIds) {
      if (await AssetEntity.fromId(id) != null) valid.add(id);
    }
    final deleted = valid.isEmpty
        ? <String>[]
        : await PhotoManager.editor.deleteWithIds(valid);
    final confirmed = deleted.toSet().intersection(reviewedIds);
    for (final id in confirmed) {
      _assets.remove(id);
      _items.remove(id);
    }
    return DeleteResult(confirmed, reviewedIds.difference(confirmed));
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();
}

class DeviceStore extends LocalStore {
  final bool demo;
  DeviceStore(this.demo);
  Database? _db;
  Map<String, dynamic> _last = {};
  static const featureTable =
      'CREATE TABLE local_features (id TEXT PRIMARY KEY, data TEXT NOT NULL)';
  Future<Database> get db async {
    if (_db != null) return _db!;
    final directory = await getApplicationSupportDirectory();
    _db = await openDatabase(
      p.join(directory.path, demo ? 'demo-v1.db' : 'mikro-v1.db'),
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA secure_delete=ON');
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE local_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(featureTable);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(featureTable);
          final rows = await db.query(
            'local_state',
            where: 'key = ?',
            whereArgs: ['features'],
          );
          if (rows.isNotEmpty) {
            final values = jsonDecode(rows.first['value'] as String) as Map;
            final batch = db.batch();
            for (final entry in values.entries) {
              batch.insert('local_features', {
                'id': entry.key,
                'data': jsonEncode(entry.value),
              });
            }
            await batch.commit(noResult: true);
          }
          await db.delete(
            'local_state',
            where: 'key = ?',
            whereArgs: ['features'],
          );
        }
      },
    );
    return _db!;
  }

  @override
  Future<Map<String, dynamic>> read() async {
    final database = await db,
        rows = await database.query('local_state'),
        featureRows = await database.query('local_features');
    final features = {
      for (final row in featureRows)
        row['id'] as String: jsonDecode(row['data'] as String),
    };
    _last = Map.of(features);
    return {
      for (final row in rows)
        row['key'] as String: jsonDecode(row['value'] as String),
      'features': features,
    };
  }

  @override
  Future<void> save(Map<String, dynamic> state) async {
    final features = Map<String, dynamic>.from(state['features'] ?? {});
    await (await db).transaction((tx) async {
      final batch = tx.batch();
      for (final e in state.entries) {
        if (e.key != 'features') {
          batch.insert('local_state', {
            'key': e.key,
            'value': jsonEncode(e.value),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final e in features.entries) {
        if (!identical(_last[e.key], e.value)) {
          batch.insert('local_features', {
            'id': e.key,
            'data': jsonEncode(e.value),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final id in _last.keys.where((id) => !features.containsKey(id))) {
        batch.delete('local_features', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });
    _last = features;
  }

  @override
  Future<void> compact() async {
    final database = await db;
    await database.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    await database.execute('VACUUM');
  }
}
