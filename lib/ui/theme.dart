import 'package:flutter/material.dart';

const rust = Color(0xFFC05040);
const cream = Color(0xFFF6F1E9);
ThemeData mikroTheme(bool dark) {
  final base = dark ? ThemeData.dark() : ThemeData.light();
  final fg = dark ? const Color(0xFFF5F2ED) : const Color(0xFF1A1816);
  final bg = dark ? const Color(0xFF080808) : cream;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: rust,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: dark ? const Color(0xFFE58979) : const Color(0xFFAD392B),
        surface: bg,
        onSurface: fg,
        surfaceContainer: dark
            ? const Color(0xFF1A1A19)
            : const Color(0xFFFFFFFF),
      );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: base.textTheme.apply(
      fontFamily: 'SpaceMono',
      bodyColor: fg,
      displayColor: fg,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'DotGothic16',
        fontSize: 23,
        color: fg,
      ),
    ),
    dividerColor: dark ? const Color(0xFF30302E) : const Color(0xFFDED8CE),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'SpaceMono',
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? cream : const Color(0xFF222220),
      contentTextStyle: TextStyle(
        fontFamily: 'SpaceMono',
        color: dark ? Colors.black : Colors.white,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class PixelTitle extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  const PixelTitle(this.text, {super.key, this.size = 28, this.color});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'DotGothic16',
      fontSize: size,
      height: 1.2,
      color: color,
    ),
  );
}

class DotIcon extends StatelessWidget {
  final int kind;
  final Color color;
  final double size;
  const DotIcon(this.kind, {super.key, required this.color, this.size = 26});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _Dots(kind, color)),
  );
}

class _Dots extends CustomPainter {
  final int kind;
  final Color color;
  _Dots(this.kind, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 0; y < 9; y++) {
      for (var x = 0; x < 9; x++) {
        final dx = x - 4, dy = y - 4;
        final r = dx * dx + dy * dy;
        final draw = switch (kind) {
          0 => (r >= 12 && r <= 20) || r <= 2,
          1 =>
            x == 4 ||
                y == 4 ||
                (x == y && x > 1 && x < 7) ||
                (x + y == 8 && x > 1 && x < 7),
          2 =>
            x >= 2 &&
                x <= 6 &&
                y >= 1 &&
                y <= 7 &&
                (x == 2 || x == 6 || y == 1 || y == 7),
          _ =>
            y == 7 ||
                (x == 1 && y >= 4) ||
                (x == 4 && y >= 1) ||
                (x == 7 && y >= 3),
        };
        if (draw) {
          canvas.drawCircle(
            Offset((x + 0.5) * size.width / 9, (y + 0.5) * size.height / 9),
            size.width / 25,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.kind != kind || old.color != color;
}
