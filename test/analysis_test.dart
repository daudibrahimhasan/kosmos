import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:mikro/data/analysis.dart';

void main() {
  test('file worker hashes bytes and measures real image sharpness', () async {
    final dir = await Directory.systemTemp.createTemp('mikro-analysis-');
    addTearDown(() => dir.delete(recursive: true));
    final sharp = im.Image(width: 128, height: 128);
    for (final p in sharp) {
      final v = ((p.x ~/ 4 + p.y ~/ 4) % 2) * 255;
      p.setRgb(v, v, v);
    }
    final crisp = im.encodePng(sharp);
    final soft = im.encodePng(im.gaussianBlur(sharp, radius: 10));
    final a = File('${dir.path}/a.png');
    final b = File('${dir.path}/b.png');
    final copy = File('${dir.path}/copy.png');
    await a.writeAsBytes(crisp);
    await b.writeAsBytes(soft);
    await copy.writeAsBytes(crisp);
    final fa = await analyzeFile({
      'path': a.path,
      'thumbnail': crisp,
      'video': false,
      'screenshot': false,
    });
    final fb = await analyzeFile({
      'path': b.path,
      'thumbnail': soft,
      'video': false,
      'screenshot': false,
    });
    final fc = await analyzeFile({
      'path': copy.path,
      'thumbnail': crisp,
      'video': false,
      'screenshot': false,
    });
    expect(fa.hash, fc.hash);
    expect(fa.hash, isNot(fb.hash));
    expect(fa.blur!, greaterThan(fb.blur!));
    expect(fa.phash.length, 64);
    expect(fa.bytes, await a.length());
  });
}
