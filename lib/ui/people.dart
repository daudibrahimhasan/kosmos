part of 'app.dart';

class PeopleScreen extends StatelessWidget {
  final GalleryController c;
  const PeopleScreen({super.key, required this.c});
  Future<void> toggle(BuildContext context, bool value) async {
    try {
      await c.setPeopleEnabled(value);
    } catch (_) {
      if (context.mounted) {
        message(
          context,
          c.error ?? 'Could not update local face data. Try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const PixelTitle('Familiar faces.\nOnly on your device.', size: 30),
          const SizedBox(height: 22),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Group people locally',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Turning this off erases face embeddings, group names and corrections. Your photos stay.',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
            value: c.peopleEnabled,
            onChanged: c.changingPeople || (!c.peopleEnabled && c.scanning)
                ? null
                : (value) => toggle(context, value),
          ),
          const SizedBox(height: 12),
          if (c.changingPeople || c.scanning) ...[
            LinearProgressIndicator(
              value: c.scanning && c.items.isNotEmpty
                  ? c.scanned / c.items.length
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              c.peopleEnabled
                  ? 'Finding faces locally · ${c.scanned}/${c.items.length}'
                  : 'Erasing local face data…',
              style: const TextStyle(fontSize: 11),
            ),
          ],
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                c.error!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (!c.peopleEnabled && !c.changingPeople)
            const EmptyState(
              title: 'People grouping is off.',
              body:
                  'Enable it to run YuNet and SFace here. Faces and group names never leave this device.',
              icon: CupertinoIcons.person_2,
            ),
          if (c.peopleEnabled) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PixelTitle(
                    '${c.peopleGroups.length} groups',
                    size: 24,
                  ),
                ),
                TextButton(
                  onPressed: c.scanning ? null : c.scan,
                  child: const Text('Scan / resume'),
                ),
              ],
            ),
            const Text(
              'Groups can be imperfect. Rename, merge or split them to correct a match.',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
            const SizedBox(height: 24),
            if (c.peopleGroups.isEmpty && !c.scanning)
              const EmptyState(
                title: 'No usable faces found yet.',
                body:
                    'Run a scan or add clear photos with larger faces. Small, partial and very blurry faces are skipped.',
                icon: CupertinoIcons.person_crop_circle,
              ),
            LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 20,
                runSpacing: 24,
                children: [
                  for (final entry in c.peopleGroups.entries)
                    SizedBox(
                      width: box.maxWidth > 700 ? 140 : (box.maxWidth - 40) / 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () =>
                            push(context, PersonScreen(c: c, group: entry.key)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 84,
                                height: 84,
                                child: FaceAvatar(
                                  c: c,
                                  face: entry.value.first,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                c.personName(entry.key),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${entry.value.map((f) => f.item.id).toSet().length} photos',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: c.changingPeople
                ? null
                : () async {
                    final yes = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Erase face data?'),
                        content: const Text(
                          'This turns off people grouping and removes face embeddings, group names and corrections. Photos are kept.',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Erase'),
                          ),
                        ],
                      ),
                    );
                    if (yes == true && context.mounted) {
                      await toggle(context, false);
                    }
                  },
            child: const Text('Erase face data'),
          ),
        ],
      ),
    ),
  );
}

class FaceAvatar extends StatelessWidget {
  final GalleryController c;
  final PersonFace face;
  const FaceAvatar({super.key, required this.c, required this.face});
  @override
  Widget build(BuildContext context) => ClipOval(
    child: LayoutBuilder(
      builder: (context, box) {
        final r = face.face.rect,
            w = box.maxWidth / r[2],
            h = box.maxHeight / r[3];
        return Transform.translate(
          offset: Offset(-r[0] * w, -r[1] * h),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: w,
            maxWidth: w,
            minHeight: h,
            maxHeight: h,
            child: PhotoTile(
              c: c,
              item: face.item,
              size: 600,
              fit: BoxFit.fill,
            ),
          ),
        );
      },
    ),
  );
}

class PersonScreen extends StatefulWidget {
  final GalleryController c;
  final String group;
  const PersonScreen({super.key, required this.c, required this.group});
  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  final Set<String> selected = {};
  bool saving = false;
  GalleryController get c => widget.c;
  Future<void> edit(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
      if (mounted) setState(selected.clear);
    } catch (_) {
      if (mounted) {
        message(context, 'Could not save that correction. Try again.');
      }
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> rename() async {
    var value = c.personName(widget.group);
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Name this group'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(
            color: Colors.transparent,
            child: TextFormField(
              initialValue: value,
              onChanged: (text) => value = text,
              maxLength: 40,
              autofocus: true,
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // The dialog's reverse transition still owns its text field for a moment.
    if (name != null) await edit(() => c.renamePerson(widget.group, name));
  }

  Future<void> merge() async {
    final target = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: PixelTitle('Merge into…', size: 26),
            ),
            for (final entry in c.peopleGroups.entries.where(
              (e) => e.key != widget.group,
            ))
              ListTile(
                leading: SizedBox(
                  width: 44,
                  height: 44,
                  child: FaceAvatar(c: c, face: entry.value.first),
                ),
                title: Text(c.personName(entry.key)),
                subtitle: Text('${entry.value.length} faces'),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (target != null) {
      await edit(() => c.mergePeople(widget.group, target));
      if (mounted && !c.peopleGroups.containsKey(widget.group)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final faces = c.peopleGroups[widget.group] ?? <PersonFace>[];
      selected.removeWhere((key) => !faces.any((f) => f.key == key));
      return Scaffold(
        appBar: AppBar(
          title: Text(c.personName(widget.group)),
          actions: [
            IconButton(
              tooltip: 'Rename group',
              onPressed: saving || faces.isEmpty ? null : rename,
              icon: const Icon(CupertinoIcons.pencil),
            ),
            IconButton(
              tooltip: 'Merge groups',
              onPressed: saving || faces.isEmpty || c.peopleGroups.length < 2
                  ? null
                  : merge,
              icon: const Icon(CupertinoIcons.arrow_merge),
            ),
          ],
        ),
        body: faces.isEmpty
            ? const EmptyState(
                title: 'This group is empty.',
                body:
                    'Your correction was saved. Return to People to see the updated groups.',
                icon: CupertinoIcons.person,
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Tap a face to select it. Hold a photo to inspect it.',
                    style: TextStyle(fontSize: 11, height: 1.8),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, box) => GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: box.maxWidth > 700 ? 5 : 3,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                      ),
                      itemCount: faces.length,
                      itemBuilder: (context, i) {
                        final face = faces[i],
                            active = selected.contains(face.key);
                        return Semantics(
                          button: true,
                          selected: active,
                          label:
                              'Face in photo from ${date(face.item.created)}',
                          child: InkWell(
                            onTap: saving
                                ? null
                                : () => setState(
                                    () => active
                                        ? selected.remove(face.key)
                                        : selected.add(face.key),
                                  ),
                            onLongPress: () => push(
                              context,
                              PhotoDetail(c: c, item: face.item),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PhotoTile(c: c, item: face.item, size: 350),
                                if (active) Container(color: Colors.black38),
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: FaceAvatar(c: c, face: face),
                                  ),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Icon(
                                    active
                                        ? CupertinoIcons
                                              .check_mark_circled_solid
                                        : CupertinoIcons.circle,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed:
                        saving ||
                            selected.isEmpty ||
                            selected.length == faces.length
                        ? null
                        : () => edit(() => c.splitFaces(Set.of(selected))),
                    child: const Text('Move selected to a new group'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: saving || selected.isEmpty
                        ? null
                        : () => edit(() => c.removeFaces(Set.of(selected))),
                    child: const Text('Remove selected from this group'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Removing a face from a group does not delete its photo. Corrections stay local and are preserved on rescans.',
                    style: TextStyle(fontSize: 11, height: 1.8),
                  ),
                ],
              ),
      );
    },
  );
}
