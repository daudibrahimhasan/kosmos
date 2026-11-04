import 'package:flutter/material.dart';
import '../core/models.dart';

class LocalVideo extends StatelessWidget {
  final GalleryRepository repository;
  final MediaItem item;
  const LocalVideo({super.key, required this.repository, required this.item});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Sample videos use photo stand-ins.\nPlay local videos in the mobile app.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, height: 1.8),
      ),
    ),
  );
}
