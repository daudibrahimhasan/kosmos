import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/controller.dart';
import 'package:mikro/data/demo.dart';
import 'package:mikro/ui/app.dart';
import 'safety_test.dart' show MemoryStore;

void main() {
  for (final spec in [
    (390.0, 1.0),
    (768.0, 1.0),
    (1440.0, 1.0),
    (390.0, 1.5),
  ]) {
    final (width, scale) = spec;
    testWidgets('gallery, theme and navigation at $width, text $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = GalleryController(DemoGallery(), MemoryStore());
      await c.init();
      await tester.pumpWidget(MikroApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Vault'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cleaner').last);
      await tester.pumpAndSettle();
      expect(find.text('Keep the good stuff.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await c.toggleTheme(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Review').last);
      await tester.pumpAndSettle();
      expect(find.text('One photo at a time.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Delete'));
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(c.pending.length, 1);
      expect(c.items.length, 30);
      expect(tester.takeException(), isNull);
    });
  }
}
