import 'dart:typed_data';
import 'package:image/image.dart' as im;
import '../core/models.dart';

Features thumbnailQuality(
  Uint8List? bytes, {
  required String hash,
  required int size,
  bool video = false,
  bool screenshot = false,
}) {
  var phash = '';
  double? blur;
  final decoded = bytes == null ? null : im.decodeImage(bytes);
  if (decoded != null && !video) {
    final gray = im.grayscale(im.copyResize(decoded, width: 128, height: 128));
    final small = im.copyResize(gray, width: 9, height: 8);
    final bits = StringBuffer();
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        bits.write(
          small.getPixel(x, y).r > small.getPixel(x + 1, y).r ? '1' : '0',
        );
      }
    }
    phash = bits.toString();
    var sum = 0.0, squared = 0.0, n = 0;
    for (var y = 1; y < 127; y++) {
      for (var x = 1; x < 127; x++) {
        final v =
            (4 * gray.getPixel(x, y).r -
                    gray.getPixel(x - 1, y).r -
                    gray.getPixel(x + 1, y).r -
                    gray.getPixel(x, y - 1).r -
                    gray.getPixel(x, y + 1).r)
                .toDouble();
        sum += v;
        squared += v * v;
        n++;
      }
    }
    blur = squared / n - (sum / n) * (sum / n);
  }
  return Features(
    hash: hash,
    phash: phash,
    blur: blur,
    bytes: size,
    screenshot: screenshot,
  );
}
