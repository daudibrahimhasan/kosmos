import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as im;

class Detection {
  final List<double> box, landmarks;
  final double score;
  const Detection(this.box, this.landmarks, this.score);
}

im.Image decodePhoto(Uint8List bytes) {
  final image = im.decodeImage(bytes);
  if (image == null) throw FormatException('Unsupported image.');
  return im.bakeOrientation(image);
}

Float32List clipPixels(im.Image image) {
  final scale = 224 / math.min(image.width, image.height);
  final resized = im.copyResize(
    image,
    width: (image.width * scale).floor(),
    height: (image.height * scale).floor(),
    interpolation: im.Interpolation.cubic,
  );
  final x0 = (resized.width - 224) ~/ 2, y0 = (resized.height - 224) ~/ 2;
  const mean = [0.48145466, 0.4578275, 0.40821073],
      std = [0.26862954, 0.26130258, 0.27577711];
  final data = Float32List(3 * 224 * 224);
  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final p = resized.getPixel(x + x0, y + y0);
      final rgb = [p.r, p.g, p.b];
      for (var c = 0; c < 3; c++) {
        data[c * 224 * 224 + y * 224 + x] = (rgb[c] / 255 - mean[c]) / std[c];
      }
    }
  }
  return data;
}

Float32List detectorPixels(im.Image image) {
  final scale = 320 / math.max(image.width, image.height);
  final resized = im.copyResize(
    image,
    width: math.max(1, (image.width * scale).round()),
    height: math.max(1, (image.height * scale).round()),
    interpolation: im.Interpolation.linear,
  );
  final data = Float32List(3 * 320 * 320);
  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final p = resized.getPixel(x, y), index = y * 320 + x;
      data[index] = p.b.toDouble();
      data[320 * 320 + index] = p.g.toDouble();
      data[2 * 320 * 320 + index] = p.r.toDouble();
    }
  }
  return data;
}

List<Detection> decodeYuNet(
  Map<String, List<double>> outputs,
  int width,
  int height, {
  double threshold = .85,
}) {
  final scale = 320 / math.max(width, height), found = <Detection>[];
  for (final stride in [8, 16, 32]) {
    final cls = outputs['cls_$stride']!,
        obj = outputs['obj_$stride']!,
        boxes = outputs['bbox_$stride']!,
        points = outputs['kps_$stride']!;
    final columns = 320 ~/ stride;
    for (var i = 0; i < cls.length; i++) {
      final score = math.sqrt(cls[i].clamp(0, 1) * obj[i].clamp(0, 1));
      if (score < threshold) continue;
      final x = i % columns, y = i ~/ columns;
      final cx = (x + boxes[4 * i]) * stride / scale,
          cy = (y + boxes[4 * i + 1]) * stride / scale;
      final w = math.exp(boxes[4 * i + 2]) * stride / scale,
          h = math.exp(boxes[4 * i + 3]) * stride / scale;
      final left = (cx - w / 2).clamp(0, width.toDouble()),
          top = (cy - h / 2).clamp(0, height.toDouble());
      final right = (cx + w / 2).clamp(0, width.toDouble()),
          bottom = (cy + h / 2).clamp(0, height.toDouble());
      if (right - left < 28 || bottom - top < 28) continue;
      final landmarks = List<double>.generate(
        10,
        (j) => ((j.isEven ? x : y) + points[10 * i + j]) * stride / scale,
      );
      if (landmarks.any((v) => !v.isFinite)) continue;
      if (List.generate(5, (j) => j).any(
        (j) =>
            landmarks[j * 2] < 0 ||
            landmarks[j * 2] >= width ||
            landmarks[j * 2 + 1] < 0 ||
            landmarks[j * 2 + 1] >= height,
      )) {
        continue;
      }
      if (math.sqrt(
            math.pow(landmarks[0] - landmarks[2], 2) +
                math.pow(landmarks[1] - landmarks[3], 2),
          ) <
          8) {
        continue;
      }
      found.add(
        Detection(
          [
            left.toDouble(),
            top.toDouble(),
            (right - left).toDouble(),
            (bottom - top).toDouble(),
          ],
          landmarks,
          score,
        ),
      );
    }
  }
  found.sort((a, b) => b.score.compareTo(a.score));
  final result = <Detection>[];
  for (final face in found) {
    if (result.any((kept) => boxIou(face.box, kept.box) > .3)) continue;
    result.add(face);
    if (result.length >= 40) break;
  }
  result.sort((a, b) => a.box[0].compareTo(b.box[0]));
  return result;
}

double boxIou(List<double> a, List<double> b) {
  final w = math.max(
    0,
    math.min(a[0] + a[2], b[0] + b[2]) - math.max(a[0], b[0]),
  );
  final h = math.max(
    0,
    math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1]),
  );
  return w * h / (a[2] * a[3] + b[2] * b[3] - w * h + 1e-9);
}

// Least-squares orientation-preserving similarity transform, source -> SFace template.
List<double> alignment(List<double> source) {
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
  var sx = 0.0, sy = 0.0, tx = 0.0, ty = 0.0;
  for (var i = 0; i < 5; i++) {
    sx += source[i * 2] / 5;
    sy += source[i * 2 + 1] / 5;
    tx += target[i * 2] / 5;
    ty += target[i * 2 + 1] / 5;
  }
  var denom = 0.0, a = 0.0, b = 0.0;
  for (var i = 0; i < 5; i++) {
    final x = source[i * 2] - sx,
        y = source[i * 2 + 1] - sy,
        u = target[i * 2] - tx,
        v = target[i * 2 + 1] - ty;
    denom += x * x + y * y;
    a += x * u + y * v;
    b += x * v - y * u;
  }
  if (denom < 1e-9) throw FormatException('Degenerate face landmarks.');
  a /= denom;
  b /= denom;
  return [a, -b, tx - a * sx + b * sy, b, a, ty - b * sx - a * sy];
}

Float32List alignedFace(im.Image image, List<double> landmarks) {
  final m = alignment(landmarks), a = m[0], b = m[3], det = a * a + b * b;
  final data = Float32List(3 * 112 * 112);
  for (var y = 0; y < 112; y++) {
    for (var x = 0; x < 112; x++) {
      final u = x - m[2],
          v = y - m[5],
          sx = (a * u + b * v) / det,
          sy = (-b * u + a * v) / det;
      // Bilinear sampling with constant-zero border, matching warpAffine's convention.
      final x0 = sx.floor(), y0 = sy.floor(), dx = sx - x0, dy = sy - y0;
      for (var c = 0; c < 3; c++) {
        var value = 0.0;
        for (var oy = 0; oy <= 1; oy++) {
          for (var ox = 0; ox <= 1; ox++) {
            final xx = x0 + ox, yy = y0 + oy;
            if (xx < 0 || yy < 0 || xx >= image.width || yy >= image.height) {
              continue;
            }
            final p = image.getPixel(xx, yy);
            value +=
                (c == 0
                    ? p.r
                    : c == 1
                    ? p.g
                    : p.b) *
                (ox == 0 ? 1 - dx : dx) *
                (oy == 0 ? 1 - dy : dy);
          }
        }
        data[c * 112 * 112 + y * 112 + x] = value.roundToDouble();
      }
    }
  }
  return data;
}

double faceSharpness(Float32List rgb) {
  double gray(int x, int y) =>
      .299 * rgb[y * 112 + x] +
      .587 * rgb[112 * 112 + y * 112 + x] +
      .114 * rgb[2 * 112 * 112 + y * 112 + x];
  var sum = 0.0, square = 0.0, n = 0;
  for (var y = 1; y < 111; y += 2) {
    for (var x = 1; x < 111; x += 2) {
      final v =
          4 * gray(x, y) -
          gray(x - 1, y) -
          gray(x + 1, y) -
          gray(x, y - 1) -
          gray(x, y + 1);
      sum += v;
      square += v * v;
      n++;
    }
  }
  return square / n - (sum / n) * (sum / n);
}
