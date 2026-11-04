part of 'app.dart';

class DeviceAlbumsScreen extends StatefulWidget {
  final GalleryController c;
  const DeviceAlbumsScreen({super.key, required this.c});
  @override
  State<DeviceAlbumsScreen> createState() => _DeviceAlbumsScreenState();
}

class _DeviceAlbumsScreenState extends State<DeviceAlbumsScreen> {
  late Future<Map<String, List<MediaItem>>> albums;
  @override
  void initState() {
    super.initState();
    albums = widget.c.repository.albums();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Albums')),
    body: FutureBuilder<Map<String, List<MediaItem>>>(
      future: albums,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            title: 'Albums unavailable.',
            body: 'Check photo access, then reopen this screen to try again.',
            icon: CupertinoIcons.folder,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        final groups = snapshot.data!;
        if (groups.isEmpty) {
          return const EmptyState(
            title: 'No albums yet.',
            body: 'Albums from your permitted library will appear here.',
            icon: CupertinoIcons.folder,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final entry in groups.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: InkWell(
                  onTap: () => push(
                    context,
                    AlbumPhotos(
                      c: widget.c,
                      title: entry.key,
                      items: entry.value,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1.9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PhotoTile(c: widget.c, item: entry.value.first),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PixelTitle(
                                  entry.key,
                                  size: 26,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${entry.value.length} items',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class AlbumPhotos extends StatelessWidget {
  final GalleryController c;
  final String title;
  final List<MediaItem> items;
  const AlbumPhotos({
    super.key,
    required this.c,
    required this.title,
    required this.items,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        PhotoGrid(
          sliver: true,
          items: items,
          c: c,
          onTap: (a) => push(context, PhotoDetail(c: c, item: a)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    ),
  );
}
