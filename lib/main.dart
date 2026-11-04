// THESIS: A quiet gallery with the dot-matrix character of the supplied mockup.
// OWN-WORLD: Black, chalk white, muted rust; pixel headings, mono labels, square/circle vault.
// STORY: Browse locally, inspect a reason, review a selection, explicitly approve deletion.
// FIRST VIEWPORT: Large Gallery title, two vault tiles, tight photographic grid, four tabs.
// FORM: User-pinned gallery reference overrides seed 473858c9. Native navigation stays familiar.
import 'package:flutter/material.dart';
import 'core/controller.dart';
import 'data/factory.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('DEMO');
  final controller = GalleryController(
    createGallery(demo: demo),
    createStore(demo: demo),
  );
  runApp(MikroApp(controller: controller));
  await controller.init();
}
