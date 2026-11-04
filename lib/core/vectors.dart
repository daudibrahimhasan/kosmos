import 'dart:math' as math;

List<double> unitVector(List<num> vector) {
  if (vector.isEmpty || vector.any((v) => !v.isFinite)) return [];
  final norm = math.sqrt(vector.fold(0.0, (n, v) => n + v * v));
  if (norm < 1e-12) return [];
  return List<double>.unmodifiable(vector.map((v) => v / norm));
}

double cosine(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return -1;
  var score = 0.0;
  for (var i = 0; i < a.length; i++) {
    score += a[i] * b[i];
  }
  return score.clamp(-1, 1);
}

Iterable<String> embeddingBands(List<double> v) sync* {
  if (v.length < 32) return;
  for (var band = 0; band < 4; band++) {
    var key = 0;
    for (var i = 0; i < 8; i++) {
      if (v[band * 8 + i] >= 0) key |= 1 << i;
    }
    yield '$band:$key';
  }
}
