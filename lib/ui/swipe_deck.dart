part of 'app.dart';

class SwipeDeck extends StatefulWidget {
  final GalleryController c;
  final List<MediaItem> items;
  final Future<bool> Function(Decision) onDecision;
  const SwipeDeck({
    super.key,
    required this.c,
    required this.items,
    required this.onDecision,
  });
  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Offset drag = Offset.zero;
  Animation<Offset>? travel;
  bool acting = false;
  bool snappingBack = false;
  double width = 340;
  Offset get position => travel?.value ?? drag;
  @override
  void didUpdateWidget(SwipeDeck old) {
    super.didUpdateWidget(old);
    if (old.items.first.id != widget.items.first.id) {
      drag = Offset.zero;
      travel = null;
      motion.reset();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  Future<void> move(Offset target, {bool returning = false}) async {
    snappingBack = returning;
    final reduced = MediaQuery.disableAnimationsOf(context);
    travel = Tween<Offset>(begin: position, end: target)
        .chain(
          CurveTween(
            curve: returning ? Curves.easeOutBack : Curves.easeInCubic,
          ),
        )
        .animate(motion);
    motion.duration = Duration(
      milliseconds: reduced
          ? 0
          : returning
          ? 320
          : 220,
    );
    try {
      await motion.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    setState(() {
      drag = target;
      travel = null;
      snappingBack = false;
    });
  }

  Future<void> choose(Decision d) async {
    if (acting) return;
    setState(() => acting = true);
    final reduced = MediaQuery.disableAnimationsOf(context);
    await move(
      reduced
          ? Offset.zero
          : switch (d) {
              Decision.keep => Offset(width * 1.5, -35),
              Decision.delete => Offset(-width * 1.5, -35),
              Decision.skip => const Offset(0, 45),
            },
    );
    if (!mounted) return;
    final saved = await widget.onDecision(d);
    if (!mounted) return;
    if (!saved) await move(Offset.zero, returning: true);
    if (mounted) setState(() => acting = false);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      width = box.maxWidth;
      final keepInk = Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF64B58C)
          : const Color(0xFF24694A);
      final height = (MediaQuery.sizeOf(context).height * .44).clamp(
        260.0,
        460.0,
      );
      return Column(
        children: [
          SizedBox(
            height: height + 24,
            child: AnimatedBuilder(
              animation: motion,
              builder: (context, _) {
                final offset = position;
                final progress = snappingBack
                    ? 0.0
                    : (offset.dx.abs() / (width * .3)).clamp(0.0, 1.0);
                final keep = offset.dx >= 0;
                final ink = keep
                    ? keepInk
                    : Theme.of(context).colorScheme.primary;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = widget.items.length - 1; i >= 1; i--)
                      Positioned(
                        top: i * 10.0,
                        left: i * 10.0 * (1 - progress * .4),
                        right: i * 10.0 * (1 - progress * .4),
                        height: height,
                        child: ExcludeSemantics(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: i == 1 ? 0.7 : 0.4,
                              child: _card(widget.items[i], height),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: height,
                      child: Transform.translate(
                        key: const ValueKey('swipe-card'),
                        offset: offset,
                        child: Transform.rotate(
                          angle: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : (offset.dx / width * .16).clamp(-.2, .2),
                          child: GestureDetector(
                            key: const ValueKey('swipe-surface'),
                            dragStartBehavior: DragStartBehavior.down,
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: acting
                                ? null
                                : (_) {
                                    drag = position;
                                    snappingBack = false;
                                    motion.stop();
                                    travel = null;
                                  },
                            onHorizontalDragUpdate: acting
                                ? null
                                : (details) => setState(
                                    () => drag += Offset(
                                      details.delta.dx,
                                      details.delta.dy * .15,
                                    ),
                                  ),
                            onHorizontalDragCancel: () =>
                                move(Offset.zero, returning: true),
                            onHorizontalDragEnd: acting
                                ? null
                                : (details) {
                                    final velocity =
                                        details.primaryVelocity ?? 0;
                                    if (drag.dx.abs() > width * .28 ||
                                        (drag.dx.abs() > 30 &&
                                            velocity.abs() > 700 &&
                                            velocity.sign == drag.dx.sign)) {
                                      choose(
                                        drag.dx > 0
                                            ? Decision.keep
                                            : Decision.delete,
                                      );
                                    } else {
                                      move(Offset.zero, returning: true);
                                    }
                                  },
                            child: Stack(
                              children: [
                                _card(widget.items.first, height),
                                if (progress > 0)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: ink.withValues(
                                              alpha: progress,
                                            ),
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (progress > 0)
                                  Positioned(
                                    top: 28,
                                    left: keep ? 22 : null,
                                    right: keep ? null : 22,
                                    child: Opacity(
                                      opacity: progress,
                                      child: Transform.rotate(
                                        angle: keep ? -.13 : .13,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor
                                                .withValues(alpha: .92),
                                            border: Border.all(
                                              color: ink,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: PixelTitle(
                                            keep ? 'KEEP' : 'QUEUE',
                                            size: 30,
                                            color: ink,
                                          ),
                                        ),
                                      ),
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
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ReviewAction(
                label: 'Delete',
                icon: CupertinoIcons.xmark,
                color: Theme.of(context).colorScheme.primary,
                onTap: acting ? null : () => choose(Decision.delete),
              ),
              ReviewAction(
                label: 'Skip',
                icon: CupertinoIcons.forward,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                onTap: acting ? null : () => choose(Decision.skip),
              ),
              ReviewAction(
                label: 'Keep',
                icon: CupertinoIcons.heart_fill,
                color: keepInk,
                onTap: acting ? null : () => choose(Decision.keep),
              ),
            ],
          ),
        ],
      );
    },
  );
  Widget _card(MediaItem item, double height) => Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .22),
          offset: const Offset(0, 8),
          blurRadius: 20,
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Expanded(
          child: PhotoTile(
            key: ValueKey(item.id),
            c: widget.c,
            item: item,
            size: 900,
            fit: BoxFit.contain,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  date(item.created),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Text(
                widget.c.sizeOf(item) == 0
                    ? 'Not scanned'
                    : formatBytes(widget.c.sizeOf(item)),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
