import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;

import '../core/controller.dart';
import '../core/models.dart';
import 'theme.dart';
import 'video.dart';
part 'albums.dart';
part 'swipe_deck.dart';
part 'people.dart';

class MikroApp extends StatelessWidget {
  final GalleryController controller;
  const MikroApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mikro',
      theme: mikroTheme(false),
      darkTheme: mikroTheme(true),
      themeMode: switch (controller.appearance) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: Home(c: controller),
    ),
  );
}

class Home extends StatefulWidget {
  final GalleryController c;
  const Home({super.key, required this.c});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab = 0;
  GalleryController get c => widget.c;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && c.allowed) c.connect();
    if (state == AppLifecycleState.paused) c.pause();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 950;
    final content = !c.ready
        ? const Center(child: CircularProgressIndicator())
        : !c.allowed
        ? Welcome(c: c)
        : switch (tab) {
            0 => GalleryScreen(c: c),
            1 => CleanerScreen(c: c),
            2 => ReviewScreen(c: c),
            _ => InsightsScreen(c: c),
          };
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: 220,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PixelTitle('mikro', size: 44),
                      const SizedBox(height: 8),
                      Text(
                        'A little less clutter.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 56),
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextButton(
                            onPressed: () => setState(() => tab = i),
                            style: TextButton.styleFrom(
                              foregroundColor: tab == i
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              backgroundColor: tab == i
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer
                                  : null,
                              minimumSize: const Size.fromHeight(52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                DotIcon(
                                  i,
                                  color: tab == i
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    [
                                      'Gallery',
                                      'Cleaner',
                                      'Review',
                                      'Insights',
                                    ][i],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      const Icon(CupertinoIcons.lock_shield, size: 22),
                      const SizedBox(height: 12),
                      const Text(
                        'Your gallery stays\non your device.',
                        style: TextStyle(fontSize: 11, height: 1.8),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => push(context, SettingsScreen(c: c)),
                        icon: const Icon(CupertinoIcons.settings, size: 18),
                        label: const Text('Settings'),
                      ),
                    ],
                  ),
                ),
              ),
            if (wide)
              VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
            Expanded(child: content),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: .5,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: List.generate(4, (i) {
                    final color = tab == i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface;
                    return Expanded(
                      child: Semantics(
                        selected: tab == i,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => tab = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DotIcon(i, color: color),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    'Gallery',
                                    'Cleaner',
                                    'Review',
                                    'Insights',
                                  ][i],
                                  style: TextStyle(fontSize: 11, color: color),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
    );
  }
}

void push(BuildContext context, Widget page) =>
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class PageBody extends StatelessWidget {
  final String title;
  final GalleryController c;
  final List<Widget> children;
  final List<Widget> actions;
  final Widget? grid;
  final List<Widget> footer;
  const PageBody({
    super.key,
    required this.title,
    required this.c,
    required this.children,
    this.actions = const [],
    this.grid,
    this.footer = const [],
  });
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: PixelTitle(title, size: 38)),
              ...actions,
              IconButton(
                tooltip: 'Settings',
                onPressed: () => push(context, SettingsScreen(c: c)),
                icon: const Icon(CupertinoIcons.slider_horizontal_3),
              ),
            ],
          ),
        ),
      ),
      if (c.demo || c.repository.canImport)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: rust,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.repository.libraryLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (c.error != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              c.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(24, 22, 24, grid == null ? 36 : 0),
        sliver: SliverList.list(children: children),
      ),
      ?grid,
      if (footer.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          sliver: SliverList.list(children: footer),
        ),
    ],
  );
}

class Welcome extends StatelessWidget {
  final GalleryController c;
  const Welcome({super.key, required this.c});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DotIcon(0, color: Theme.of(context).colorScheme.primary, size: 72),
            const SizedBox(height: 40),
            const PixelTitle('More space.\nSame memories.', size: 44),
            const SizedBox(height: 24),
            const Text(
              'A calmer place for your photos. Find the extras, keep the good ones, and make a little room.',
              style: TextStyle(height: 1.8, fontSize: 13),
            ),
            const SizedBox(height: 32),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(CupertinoIcons.lock_shield),
              title: Text(
                'Only on your device',
                style: TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                'No uploads. You approve every deletion.',
                style: TextStyle(fontSize: 11, height: 1.7),
              ),
            ),
            const SizedBox(height: 24),
            if (c.error != null) Text(c.error!),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: c.busy ? null : c.connect,
                child: c.busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Open my photo library'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: c.repository.openSettings,
              child: const Text('Manage photo permissions'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Limited photo access works too. You can change access in system settings.',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
          ],
        ),
      ),
    ),
  );
}

class GalleryScreen extends StatefulWidget {
  final GalleryController c;
  const GalleryScreen({super.key, required this.c});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String filter = 'All';
  String query = '';
  bool search = false;
  GalleryController get c => widget.c;
  @override
  Widget build(BuildContext context) {
    final all = c.items
        .where(
          (a) => switch (filter) {
            'Favorites' => a.favorite,
            'Videos' => a.video,
            'Screenshots' =>
              a.screenshot || (c.features[a.id]?.screenshot ?? false),
            'All' => true,
            _ => c.features[a.id]?.category == filter,
          },
        )
        .where(
          (a) =>
              query.isEmpty ||
              '${a.created.year}-${a.created.month.toString().padLeft(2, '0')}-${a.created.day.toString().padLeft(2, '0')} ${c.features[a.id]?.category ?? ''} ${a.album}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return PageBody(
      title: 'Gallery',
      c: c,
      actions: [
        IconButton(
          tooltip: 'Albums',
          onPressed: () => push(context, DeviceAlbumsScreen(c: c)),
          icon: const Icon(CupertinoIcons.square_stack),
        ),
        IconButton(
          tooltip: 'Search library',
          onPressed: () => setState(() => search = !search),
          icon: const Icon(CupertinoIcons.search),
        ),
      ],
      grid: all.isEmpty
          ? null
          : PhotoGrid(
              sliver: true,
              items: all,
              c: c,
              onTap: (a) => push(context, PhotoDetail(c: c, item: a)),
            ),
      footer: [
        Text(
          '${all.length} items · ${!c.demo && c.features.length < c.items.length ? 'Scan to measure storage' : formatBytes(all.fold(0, (n, a) => n + c.sizeOf(a)))}${c.demo ? ' · sample values' : ''}',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(CupertinoIcons.person_2),
          title: const PixelTitle('People', size: 22),
          subtitle: const Text(
            'Private groups, on your device',
            style: TextStyle(fontSize: 11),
          ),
          trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
          onTap: () => push(context, PeopleScreen(c: c)),
        ),
      ],
      children: [
        if (search)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Date or category',
                prefixIcon: Icon(CupertinoIcons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
        const PixelTitle('Vault', size: 23),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, box) {
            final size = (box.maxWidth / 2 - 8).clamp(0.0, 190.0);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                VaultTile(
                  label: 'Favorites',
                  count: '${c.items.where((a) => a.favorite).length} photos',
                  icon: CupertinoIcons.heart,
                  size: size,
                  onTap: () => setState(() => filter = 'Favorites'),
                ),
                VaultTile(
                  label: 'Memories',
                  count: 'Browse by date',
                  icon: CupertinoIcons.clock,
                  size: size,
                  circle: true,
                  onTap: () => push(context, AlbumsScreen(c: c)),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: PixelTitle(filter == 'All' ? 'Photos' : filter, size: 23),
            ),
            if (c.repository.canImport)
              IconButton(
                tooltip: 'Import photos',
                onPressed: c.busy || c.scanning ? null : c.importPhotos,
                icon: const Icon(CupertinoIcons.add_circled),
              ),
            TextButton(
              onPressed: c.busy ? null : c.connect,
              child: Text(
                c.busy ? 'Loading…' : 'Refresh',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in [
                'All',
                'Favorites',
                'Videos',
                'Screenshots',
                ...c.features.values
                    .map((f) => f.category)
                    .where((s) => s != 'Other')
                    .toSet(),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f, style: const TextStyle(fontSize: 11)),
                    selected: filter == f,
                    onSelected: (_) => setState(() => filter = f),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (all.isEmpty)
          EmptyState(
            title: 'Nothing here yet.',
            body:
                'Try another filter or add more photos to your permitted library.',
            icon: CupertinoIcons.photo,
          ),
      ],
    );
  }
}

class VaultTile extends StatelessWidget {
  final String label, count;
  final IconData icon;
  final double size;
  final bool circle;
  final VoidCallback onTap;
  const VaultTile({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.size,
    required this.onTap,
    this.circle = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $count',
    child: Material(
      color: circle ? const Color(0xFFF8F5EF) : const Color(0xFFAA4033),
      borderRadius: BorderRadius.circular(circle ? size / 2 : 24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: circle ? const Color(0xFFAA4033) : Colors.white,
                size: 28,
              ),
              const SizedBox(height: 18),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: circle ? const Color(0xFF9C352B) : Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                count,
                style: TextStyle(
                  fontSize: 11,
                  color: circle ? const Color(0xFF9C352B) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PhotoTile extends StatefulWidget {
  final GalleryController c;
  final MediaItem item;
  final BoxFit fit;
  final int size;
  const PhotoTile({
    super.key,
    required this.c,
    required this.item,
    this.fit = BoxFit.cover,
    this.size = 500,
  });
  @override
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile> {
  late Future<Uint8List?> bytes;
  @override
  void initState() {
    super.initState();
    bytes = widget.c.repository.thumbnail(widget.item, size: widget.size);
  }

  @override
  void didUpdateWidget(PhotoTile old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id) {
      bytes = widget.c.repository.thumbnail(widget.item, size: widget.size);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (context, s) {
      if (s.hasData) {
        return Image.memory(
          s.data!,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, error, stack) =>
              const Center(child: Icon(CupertinoIcons.photo)),
        );
      }
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Center(
          child: s.connectionState == ConnectionState.waiting
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.photo),
        ),
      );
    },
  );
}

class PhotoGrid extends StatelessWidget {
  final List<MediaItem> items;
  final GalleryController c;
  final void Function(MediaItem) onTap;
  final Set<String>? selected;
  final String? bestId;
  final bool sliver;
  const PhotoGrid({
    super.key,
    required this.items,
    required this.c,
    required this.onTap,
    this.selected,
    this.bestId,
    this.sliver = false,
  });
  SliverGridDelegate layout(double width) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width > 800
            ? 6
            : width > 550
            ? 4
            : 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      );
  @override
  Widget build(BuildContext context) {
    if (sliver) {
      return SliverLayoutBuilder(
        builder: (context, box) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverGrid(
            gridDelegate: layout(box.crossAxisExtent - 48),
            delegate: SliverChildBuilderDelegate(
              cell,
              childCount: items.length,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: layout(box.maxWidth),
          itemCount: items.length,
          itemBuilder: cell,
        ),
      ),
    );
  }

  Widget cell(BuildContext context, int i) {
    final a = items[i];
    final check = selected?.contains(a.id) ?? false;
    return Semantics(
      button: true,
      selected: selected == null ? null : check,
      label:
          '${a.video ? 'Video' : 'Photo'}, ${date(a.created)}${a.id == bestId ? ', suggested best shot' : ''}',
      child: InkWell(
        onTap: () => onTap(a),
        onLongPress: () => push(context, PhotoDetail(c: c, item: a)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoTile(c: c, item: a, size: 350),
            if (check) Container(color: Colors.black.withValues(alpha: .3)),
            if (selected != null)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  check
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: check ? Colors.white : Colors.white,
                  size: 24,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            if (a.favorite)
              const Positioned(
                left: 7,
                bottom: 7,
                child: Icon(
                  CupertinoIcons.heart_fill,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            if (a.video)
              Positioned(
                right: 5,
                bottom: 5,
                child: Text(
                  '${a.duration ~/ 60}:${(a.duration % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            if (a.id == bestId)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  color: const Color(0xFF222220),
                  child: const Text(
                    'BEST SHOT',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String date(DateTime d) =>
    '${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.day}, ${d.year}';

const cleanNames = <CleanKind, String>{
  CleanKind.duplicates: 'Duplicates',
  CleanKind.similar: 'Similar moments',
  CleanKind.screenshots: 'Screenshots',
  CleanKind.blurry: 'Soft & blurry',
  CleanKind.videos: 'Large videos',
  CleanKind.personal: 'Review queue',
};
const cleanIcons = <CleanKind, IconData>{
  CleanKind.duplicates: CupertinoIcons.square_on_square,
  CleanKind.similar: CupertinoIcons.photo_on_rectangle,
  CleanKind.screenshots: CupertinoIcons.viewfinder,
  CleanKind.blurry: CupertinoIcons.drop,
  CleanKind.videos: CupertinoIcons.play_rectangle,
  CleanKind.personal: CupertinoIcons.tray,
};

class CleanerScreen extends StatelessWidget {
  final GalleryController c;
  const CleanerScreen({super.key, required this.c});
  @override
  Widget build(BuildContext context) => PageBody(
    title: 'Cleaner',
    c: c,
    children: [
      const PixelTitle('Keep the good stuff.', size: 30),
      const SizedBox(height: 12),
      const Text(
        'Find the extras. You choose what goes.',
        style: TextStyle(fontSize: 11, height: 1.8),
      ),
      const SizedBox(height: 26),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.lock_shield, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.scanning
                        ? 'Looking through your library…'
                        : 'On-device scan',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (c.scanning)
              LinearProgressIndicator(
                value: c.items.isEmpty ? 0 : c.scanned / c.items.length,
              ),
            if (!c.scanning)
              Row(
                children: [
                  Expanded(
                    child: PixelTitle(
                      '${c.features.length} / ${c.items.length}',
                      size: 30,
                    ),
                  ),
                  Text(
                    'items checked',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              c.demo
                  ? c.repository.neural
                        ? 'Sample photos, real local AI. Dates, file sizes and video entries are demo fixtures.'
                        : 'Sample analysis is simulated.'
                  : 'TinyCLIP categories and similarity, exact hashes and thumbnail quality. Everything runs locally.',
              style: const TextStyle(fontSize: 11, height: 1.8),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: c.deleting
                    ? null
                    : c.scanning
                    ? c.pause
                    : c.scan,
                icon: Icon(
                  c.scanning ? CupertinoIcons.pause : CupertinoIcons.sparkles,
                  size: 17,
                ),
                label: Text(
                  c.scanning
                      ? 'Pause scan'
                      : c.features.isEmpty
                      ? 'Scan my library'
                      : 'Scan / resume',
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      const PixelTitle('A little room to breathe', size: 23),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final kind in CleanKind.values)
              SizedBox(
                width: box.maxWidth > 650
                    ? (box.maxWidth - 16) / 2
                    : box.maxWidth,
                child: CleanerRow(c: c, kind: kind),
              ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      TextButton.icon(
        onPressed: () => push(context, ModelStatusScreen(c: c)),
        icon: const Icon(CupertinoIcons.info_circle, size: 16),
        label: const Text(
          'AI models & availability',
          style: TextStyle(fontSize: 11),
        ),
      ),
    ],
  );
}

class CleanerRow extends StatelessWidget {
  final GalleryController c;
  final CleanKind kind;
  const CleanerRow({super.key, required this.c, required this.kind});
  @override
  Widget build(BuildContext context) {
    final groups = c.groups(kind);
    final items = groups.expand((g) => g.items).toList();
    final bytes = items.fold(0, (n, a) => n + c.sizeOf(a));
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => push(context, BatchScreen(c: c, kind: kind)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 70,
                child: items.isEmpty
                    ? Icon(cleanIcons[kind], size: 28)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: PhotoTile(c: c, item: items.first, size: 160),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PixelTitle(cleanNames[kind]!, size: 21),
                    const SizedBox(height: 8),
                    Text(
                      '${items.length} items · ${formatBytes(bytes)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_right, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class BatchScreen extends StatefulWidget {
  final GalleryController c;
  final CleanKind kind;
  const BatchScreen({super.key, required this.c, required this.kind});
  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  final Set<String> selected = {};
  bool working = false;
  GalleryController get c => widget.c;
  @override
  void initState() {
    super.initState();
    c.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(changed);
    super.dispose();
  }

  Future<void> confirm() async {
    final count = selected.length;
    final bytes = c.items
        .where((a) => selected.contains(a.id))
        .fold(0, (n, a) => n + c.sizeOf(a));
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(c.demo ? 'Remove sample items?' : 'Delete $count items?'),
        content: Text(
          '${formatBytes(bytes)} selected. ${c.demo ? 'This changes only the sample library.' : c.repository.deletionExplanation}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(c.demo ? 'Remove samples' : 'Delete selected'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => working = true);
    try {
      final result = await c.deleteReviewed(Set.of(selected));
      if (!mounted) return;
      setState(() => selected.removeAll(result.deleted));
      message(
        context,
        '${result.deleted.length} ${c.demo ? 'sample items removed' : 'items deleted'}.${result.failed.isNotEmpty ? ' ${result.failed.length} unchanged or cancelled.' : ''}',
      );
    } catch (_) {
      if (mounted) {
        message(
          context,
          'Deletion was not completed. Refresh the library before trying again.',
        );
      }
    }
    if (mounted) setState(() => working = false);
  }

  @override
  Widget build(BuildContext context) {
    final groups = c.groups(widget.kind);
    final valid = groups.expand((g) => g.items).map((a) => a.id).toSet();
    selected.removeWhere((id) => !valid.contains(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(cleanNames[widget.kind]!),
        actions: [
          TextButton(
            onPressed: selected.isEmpty ? null : () => setState(selected.clear),
            child: const Text('Clear'),
          ),
        ],
      ),
      body: groups.isEmpty
          ? const EmptyState(
              title: 'All clear here.',
              body:
                  'Scan your library to find items to review. Nothing is selected or deleted automatically.',
              icon: CupertinoIcons.check_mark_circled,
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Tap to select. Hold a photo to inspect it.',
                  style: TextStyle(fontSize: 11, height: 1.8),
                ),
                const SizedBox(height: 24),
                for (final group in groups) ...[
                  if (widget.kind == CleanKind.duplicates ||
                      widget.kind == CleanKind.similar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PixelTitle(
                        '${group.items.length} photos in this group',
                        size: 22,
                      ),
                    ),
                  Text(
                    group.reason,
                    style: const TextStyle(fontSize: 11, height: 1.8),
                  ),
                  const SizedBox(height: 16),
                  PhotoGrid(
                    items: group.items,
                    c: c,
                    selected: selected,
                    bestId: group.bestId,
                    onTap: (a) => setState(
                      () => selected.contains(a.id)
                          ? selected.remove(a.id)
                          : selected.add(a.id),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            onPressed: selected.isEmpty || working || c.scanning
                ? null
                : confirm,
            icon: const Icon(CupertinoIcons.trash, size: 18),
            label: Text(
              working
                  ? 'Waiting for confirmation…'
                  : 'Review deletion · ${selected.length} selected',
            ),
          ),
        ),
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  final GalleryController c;
  const ReviewScreen({super.key, required this.c});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final Set<String> skipped = {};
  Future<bool> decide(MediaItem a, Decision d) async {
    try {
      await widget.c.decide(a, d);
      if (mounted && d == Decision.skip) setState(() => skipped.add(a.id));
      return true;
    } catch (_) {
      if (mounted) message(context, 'Could not save your choice. Try again.');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final available = c
        .reviewCandidates()
        .where(
          (a) =>
              c.decisions[a.id] != 'keep' &&
              c.decisions[a.id] != 'delete' &&
              !skipped.contains(a.id),
        )
        .toList();
    final a = available.isEmpty ? null : available.first;
    return PageBody(
      title: 'Review',
      c: c,
      children: [
        Row(
          children: [
            const Expanded(child: PixelTitle('One photo at a time.', size: 25)),
            Text(
              '${c.reviewed} reviewed',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Swipe left to queue. Right to keep.',
          style: TextStyle(fontSize: 11, height: 1.8),
        ),
        const SizedBox(height: 24),
        if (a == null) ...[
          const EmptyState(
            title: 'You’re all caught up.',
            body: 'Your review queue is ready when you are.',
            icon: CupertinoIcons.check_mark_circled,
          ),
          TextButton(
            onPressed: () =>
                push(context, BatchScreen(c: c, kind: CleanKind.personal)),
            child: Text('Open deletion queue (${c.pending.length})'),
          ),
        ],
        if (a != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  SwipeDeck(
                    c: c,
                    items: available.take(3).toList(),
                    onDecision: (d) => decide(a, d),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Delete adds to your review queue.\nNothing is removed yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, height: 1.8),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (c.pending.isNotEmpty)
          OutlinedButton(
            onPressed: () =>
                push(context, BatchScreen(c: c, kind: CleanKind.personal)),
            child: Text('Review ${c.pending.length} queued items'),
          ),
      ],
    );
  }
}

class ReviewAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const ReviewAction({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconButton.filledTonal(
        onPressed: onTap,
        tooltip: label,
        icon: Icon(icon, color: color),
        style: IconButton.styleFrom(minimumSize: const Size(60, 60)),
      ),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );
}

class PhotoDetail extends StatelessWidget {
  final GalleryController c;
  final MediaItem item;
  const PhotoDetail({super.key, required this.c, required this.item});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(date(item.created))),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: item.video
                ? LocalVideo(repository: c.repository, item: item)
                : PhotoTile(c: c, item: item, size: 1200, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 24),
        PixelTitle(
          c.features[item.id]?.category ?? (item.video ? 'Video' : 'Photo'),
          size: 24,
        ),
        const SizedBox(height: 12),
        Text(
          '${item.width} × ${item.height} · ${c.sizeOf(item) == 0 ? 'Size not scanned' : formatBytes(c.sizeOf(item))}',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await c.decide(item, Decision.delete);
              if (context.mounted) {
                message(context, 'Added to review queue. Nothing deleted.');
              }
            } catch (_) {
              if (context.mounted) {
                message(context, 'Could not save this choice. Try again.');
              }
            }
          },
          icon: const Icon(CupertinoIcons.trash, size: 16),
          label: const Text('Add to deletion review'),
        ),
      ],
    ),
  );
}

class AlbumsScreen extends StatelessWidget {
  final GalleryController c;
  const AlbumsScreen({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final months = <String, List<MediaItem>>{};
    for (final a in c.items) {
      final key =
          '${['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][a.created.month - 1]} ${a.created.year}';
      (months[key] ??= []).add(a);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Memories')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final entry in months.entries) ...[
            PixelTitle(entry.key, size: 25),
            const SizedBox(height: 16),
            PhotoGrid(
              items: entry.value,
              c: c,
              onTap: (a) => push(context, PhotoDetail(c: c, item: a)),
            ),
            const SizedBox(height: 32),
          ],
          if (months.isEmpty)
            const EmptyState(
              title: 'No memories yet.',
              body: 'Photos will appear here by month.',
              icon: CupertinoIcons.clock,
            ),
        ],
      ),
    );
  }
}

class InsightsScreen extends StatelessWidget {
  final GalleryController c;
  const InsightsScreen({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final cats = <String, int>{};
    for (final a in c.items) {
      final cat = c.features[a.id]?.category ?? 'Not scanned';
      cats[cat] = (cats[cat] ?? 0) + 1;
    }
    return PageBody(
      title: 'Insights',
      c: c,
      children: [
        const PixelTitle('A little less.\nA little better.', size: 32),
        const SizedBox(height: 30),
        Wrap(
          spacing: 36,
          runSpacing: 24,
          children: [
            Stat('Space saved', formatBytes(c.saved)),
            Stat('Reviewed', '${c.reviewed}'),
            Stat(
              'Known storage',
              c.totalBytes == 0 && c.items.isNotEmpty
                  ? 'Not scanned'
                  : formatBytes(c.totalBytes),
            ),
            Stat('Photos', '${c.items.where((a) => !a.video).length}'),
            Stat('Videos', '${c.items.where((a) => a.video).length}'),
          ],
        ),
        const SizedBox(height: 36),
        const Divider(),
        const SizedBox(height: 24),
        const PixelTitle('In your library', size: 24),
        const SizedBox(height: 22),
        for (final entry in cats.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: c.items.isEmpty ? 0 : entry.value / c.items.length,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const PixelTitle('Learning your keepers', size: 24),
        const SizedBox(height: 14),
        Text(
          '${c.model.labels} explicit choices · ${c.model.canRank ? 'Personal ranking available' : 'Learning, not guessing'}',
          style: const TextStyle(fontSize: 11, height: 1.8),
        ),
        const SizedBox(height: 12),
        const Text(
          'Personalized ranking starts after 100 labeled items. Suggestions always need your review. Category filters use local TinyCLIP embeddings.',
          style: TextStyle(fontSize: 11, height: 1.8),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            const Expanded(child: PixelTitle('Cleanup history', size: 24)),
            Icon(
              CupertinoIcons.clock,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (c.audit.isEmpty)
          const Text(
            'Your first cleanup will appear here.',
            style: TextStyle(fontSize: 11, height: 1.8),
          ),
        for (final a in c.audit.reversed.take(10))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${a['deleted']} removed · ${formatBytes(a['bytes'] as num)}',
              style: const TextStyle(fontSize: 11),
            ),
            subtitle: Text(
              '${date(DateTime.parse(a['at']))} · ${a['status']}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class Stat extends StatelessWidget {
  final String label, value;
  const Stat(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelTitle(value, size: 30),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  final GalleryController c;
  const SettingsScreen({super.key, required this.c});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const PixelTitle('Make yourself at home.', size: 28),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Appearance'),
            subtitle: const Text('Follow your device, or choose a look.'),
            trailing: DropdownButton<String>(
              value: c.appearance,
              items: const [
                DropdownMenuItem(value: 'system', child: Text('System')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
              ],
              onChanged: (value) {
                if (value != null) c.setAppearance(value);
              },
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(CupertinoIcons.lock_shield),
            title: Text(
              c.repository.canImport ? 'Local photo copies' : 'Photo access',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              c.repository.canImport
                  ? c.demo
                        ? 'Sample photos · import your own in Gallery'
                        : 'Imported copies stay in this browser'
                  : c.demo
                  ? 'Sample library only'
                  : 'Managed by your device',
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => c.demo
                ? message(
                    context,
                    'The browser preview uses sample photos only.',
                  )
                : c.repository.openSettings(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(CupertinoIcons.person_2),
            title: const Text(
              'People grouping',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              c.peopleEnabled
                  ? '${c.peopleGroups.length} local groups'
                  : 'Off · no face collection',
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => push(context, PeopleScreen(c: c)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(CupertinoIcons.sparkles),
            title: const Text(
              'On-device models',
              style: TextStyle(fontSize: 13),
            ),
            onTap: () => push(context, ModelStatusScreen(c: c)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(CupertinoIcons.star),
            title: const Text('Mikro Plus', style: TextStyle(fontSize: 13)),
            subtitle: const Text(
              'Store setup pending',
              style: TextStyle(fontSize: 11),
            ),
            onTap: () => push(context, PremiumScreen(c: c)),
          ),
          const SizedBox(height: 26),
          const PixelTitle('Your library is yours.', size: 24),
          const SizedBox(height: 14),
          const Text(
            'Photos, videos, review decisions and local analysis stay on this device. There are no gallery uploads or analytics connections in this build.',
            style: TextStyle(fontSize: 11, height: 1.9),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              final yes = await showCupertinoDialog<bool>(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Reset your learning?'),
                  content: const Text(
                    'This clears review decisions and your deletion queue. Your photos and cleanup history stay.',
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (yes == true) {
                await c.resetLearning();
                if (context.mounted) message(context, 'Local learning reset.');
              }
            },
            child: const Text('Reset local learning'),
          ),
          const SizedBox(height: 32),
          const Text(
            'MIKRO 0.1 · DEVELOPMENT BUILD',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class ModelStatusScreen extends StatelessWidget {
  final GalleryController c;
  const ModelStatusScreen({super.key, required this.c});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('On-device models')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const PixelTitle('Local by design.', size: 32),
          const SizedBox(height: 24),
          Text(
            '${c.features.values.where((f) => f.embedding.length == 512).length} photos have TinyCLIP embeddings',
          ),
          Text('People grouping: ${c.peopleEnabled ? 'enabled' : 'off'}'),
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectableText(c.error!),
            ),
          FilledButton(
            onPressed: c.scanning || !c.allowed ? null : c.scan,
            child: Text(
              c.scanning
                  ? 'Scanning ${c.scanned}/${c.items.length}'
                  : 'Scan photos on this device',
            ),
          ),
          if (!c.allowed)
            const Text('Grant photo access from Gallery before scanning.'),

          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(CupertinoIcons.info_circle),
            title: Text(
              'Deterministic cleaner',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              'SHA-256 · dHash · Laplacian variance',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(CupertinoIcons.info_circle),
            title: Text(
              'Personal preference model',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              'Logistic regression · TinyCLIP + quality features',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
          ),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(CupertinoIcons.arrow_down_circle),
            title: Text('TinyCLIP · bundled', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              'Categories, similarity and personal-model inputs · runs during scan',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(CupertinoIcons.arrow_down_circle),
            title: Text(
              'YuNet + SFace · bundled',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              'Face detection and aligned embeddings · opt-in in People',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Models run locally with ONNX Runtime. TinyCLIP supplies semantic embeddings; YuNet landmarks align faces for SFace. People grouping is off until you enable it. No photos or embeddings are uploaded. Native phone performance still needs device validation.',
            style: TextStyle(fontSize: 11, height: 1.9),
          ),
        ],
      ),
    ),
  );
}

class PremiumScreen extends StatelessWidget {
  final GalleryController c;
  const PremiumScreen({super.key, required this.c});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mikro Plus')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PixelTitle('More room.\nLess busywork.', size: 36),
        const SizedBox(height: 28),
        for (final label in [
          'Unlimited smart review',
          'People grouping',
          'Advanced similarity & best shots',
          'Personalized cleanup batches',
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(CupertinoIcons.add, size: 18),
            title: Text(label, style: const TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 24),
        const Text(
          'Subscriptions are not connected in this development build. Pricing, purchasing and restore will be supplied by the app stores. No purchase can be made here.',
          style: TextStyle(fontSize: 11, height: 1.9),
        ),
        const SizedBox(height: 28),
        const FilledButton(
          onPressed: null,
          child: Text('Store connection pending'),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, body;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            PixelTitle(title, size: 26),
            const SizedBox(height: 14),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.9),
            ),
          ],
        ),
      ),
    ),
  );
}
