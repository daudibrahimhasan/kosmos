import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/models.dart';

class LocalVideo extends StatefulWidget {
  final GalleryRepository repository;
  final MediaItem item;
  const LocalVideo({super.key, required this.repository, required this.item});
  @override
  State<LocalVideo> createState() => _LocalVideoState();
}

class _LocalVideoState extends State<LocalVideo> with WidgetsBindingObserver {
  VideoPlayerController? player;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    try {
      final path = await widget.repository.localVideoPath(widget.item);
      if (!mounted) return;
      if (path == null) {
        setState(() => error = 'Video is not available on this device.');
        return;
      }
      final p = VideoPlayerController.file(File(path));
      player = p;
      await p.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'This video could not be opened. Its format may be unsupported.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) player?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error!,
            style: const TextStyle(fontSize: 12, height: 1.8),
          ),
        ),
      );
    }
    final p = player;
    if (p == null || !p.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: p.value.aspectRatio,
              child: VideoPlayer(p),
            ),
          ),
        ),
        VideoProgressIndicator(
          p,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: p,
          builder: (context, value, _) => IconButton(
            tooltip: value.isPlaying ? 'Pause video' : 'Play video',
            icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () => value.isPlaying ? p.pause() : p.play(),
          ),
        ),
      ],
    );
  }
}
