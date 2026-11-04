import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/controller.dart';
import 'package:mikro/data/demo.dart';
import 'package:mikro/ui/app.dart';
import 'safety_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'card follows drag, short drag snaps back, long slow swipes persist once',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = GalleryController(DemoGallery(), MemoryStore());
      await c.init();
      await tester.pumpWidget(MikroApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review').last);
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('swipe-surface'));
      final origin = tester.getCenter(card);
      final gesture = await tester.startGesture(origin);
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(tester.getCenter(card).dx, greaterThan(origin.dx + 20));
      expect(find.text('KEEP'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.decisions, isEmpty);
      expect(tester.getCenter(card).dx, closeTo(origin.dx, 1));
      await tester.timedDrag(
        card,
        const Offset(180, 0),
        const Duration(milliseconds: 900),
      );
      await tester.pumpAndSettle();
      expect(c.decisions.length, 1);
      expect(c.decisions.values.single, 'keep');
      expect(c.pending, isEmpty);
      expect(c.items.length, 30);
      await tester.timedDrag(
        card,
        const Offset(-180, 0),
        const Duration(milliseconds: 900),
      );
      await tester.pumpAndSettle();
      expect(c.decisions.length, 2);
      expect(c.pending.length, 1);
      expect(c.items.length, 30);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed save restores the card and reduced motion still supports buttons',
    (tester) async {
      final store = MemoryStore();
      final c = GalleryController(DemoGallery(), store);
      await c.init();
      await tester.pumpWidget(MikroApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review').last);
      await tester.pumpAndSettle();
      store.fail = true;
      await tester.ensureVisible(find.byTooltip('Keep'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Keep'));
      await tester.pumpAndSettle();
      expect(c.decisions, isEmpty);
      expect(c.items.length, 30);
      store.fail = false;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.tap(find.byTooltip('Keep'));
      await tester.pumpAndSettle();
      expect(c.decisions.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
