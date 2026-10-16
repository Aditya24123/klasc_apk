import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store.dart';
import 'design.dart';
import 'cloud_gate.dart';
import 'cloud_store.dart';
import 'local_factory.dart';
import 'profile.dart';
import 'share_intake.dart';
import 'public_share.dart';

SemanticsHandle? browserSemantics;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) browserSemantics = SemanticsBinding.instance.ensureSemantics();
  await shareIntake.initialize();
  runApp(const KlascApp());
}

String date(DateTime value) {
  final d = value.toLocal();
  return '${d.day}/${d.month}/${d.year}';
}

IconData typeIcon(ItemType type) => switch (type) {
      ItemType.note => Icons.notes_rounded,
      ItemType.link => Icons.link_rounded,
      ItemType.snippet => Icons.code_rounded,
      ItemType.image => Icons.image_outlined,
    };
String typeLabel(ItemType type) =>
    '${type.name[0].toUpperCase()}${type.name.substring(1)}';
Color typeColor(ItemType type) => switch (type) {
      ItemType.note => accent,
      ItemType.link => const Color(0xffb7a5ff),
      ItemType.snippet => const Color(0xffffd089),
      ItemType.image => const Color(0xff8bc8ef),
    };

final homeRoutes = RouteObserver<ModalRoute<void>>();

class KlascApp extends StatelessWidget {
  final ItemRepository? store;
  const KlascApp({super.key, this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'KLASC',
        navigatorObservers: [homeRoutes],
        debugShowCheckedModeBanner: false,
        theme: klascTheme(),
        home: store == null ? const CloudGate() : Home(store: store),
      );
}

class Home extends StatefulWidget {
  final ItemRepository? store;
  final VoidCallback? onSignOut;
  final String? account;
  final Future<void> Function(String)? onUpdateName;
  const Home(
      {super.key, this.store, this.onSignOut, this.account, this.onUpdateName});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with RouteAware {
  bool reviewingShare = false;
  ModalRoute<void>? observedRoute;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != observedRoute && route != null) {
      homeRoutes.unsubscribe(this);
      observedRoute = route;
      homeRoutes.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => reviewShared();
  void reviewShared() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          store == null ||
          reviewingShare ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final draft = shareIntake.take();
      if (draft == null) return;
      reviewingShare = true;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => Editor(store: store!, draft: draft)));
      reviewingShare = false;
      if (mounted) {
        await reload();
        reviewShared();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  StreamSubscription<void>? changes;
  final searchController = TextEditingController();
  ItemRepository? store;
  List<SavedItem> items = [];
  bool loading = true, archived = false;
  bool ownsLocalStore = false;
  int loadVersion = 0;
  String query = '';
  String? error, tag;
  ItemType? type;
  @override
  void dispose() {
    shareIntake.removeListener(reviewShared);
    homeRoutes.unsubscribe(this);
    changes?.cancel();
    if (ownsLocalStore && store is ItemStore) {
      unawaited((store as ItemStore).db.close());
    }
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    shareIntake.addListener(reviewShared);
    store = widget.store;
    initialize();
  }

  Future<void> initialize() async {
    try {
      if (store == null) {
        final local = await openLocalStore();
        if (!mounted) {
          await local.db.close();
          return;
        }
        store = local;
        ownsLocalStore = true;
      }
      await reload();
      if (!mounted) return;
      reviewShared();
      if (store is CloudItemStore && changes == null) {
        changes = (store as CloudItemStore).changes.listen((_) => reload(),
            onError: (Object e) {
          if (mounted) setState(() => error = friendlyError(e));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = friendlyError(e);
        });
      }
    }
  }

  Future<void> reload() async {
    final request = ++loadVersion;
    try {
      final result = await store!.all();
      if (mounted && request == loadVersion) {
        setState(() {
          items = result;
          loading = false;
          error = null;
          if (tag != null &&
              !items
                  .any((i) => i.archived == archived && i.tags.contains(tag))) {
            tag = null;
          }
        });
      }
    } catch (e) {
      if (mounted && request == loadVersion) {
        setState(() {
          loading = false;
          error = friendlyError(e);
        });
      }
    }
  }

  Future<void> edit([SavedItem? item]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Editor(store: store!, item: item),
      ),
    );
    await reload();
  }

  Future<void> detail(SavedItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Detail(store: store!, item: item),
      ),
    );
    await reload();
  }

  Future<void> editProfile() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ProfileDialog(
        initialName: widget.account ?? '',
        save: widget.onUpdateName!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = filterItems(
      items,
      archived: archived,
      query: query,
      type: type,
      tag: tag,
    );
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(fit: BoxFit.scaleDown, child: BrandHeader()),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
                tooltip: 'Sign out',
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: RefreshIndicator(
              onRefresh: reload,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(
                                    store?.isCloud == true
                                        ? Icons.cloud_done_outlined
                                        : Icons.smartphone_rounded,
                                    size: 14,
                                    color: accent),
                                const SizedBox(width: 7),
                                Expanded(
                                    child: Text(
                                        store?.isCloud == true
                                            ? 'PRIVATE CLOUD INBOX'
                                            : 'ON THIS DEVICE',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: muted,
                                            letterSpacing: 1.5)))
                              ]),
                              if (widget.onUpdateName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: editProfile,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(children: [
                                        const CartoonAvatar(),
                                        const SizedBox(width: 9),
                                        Flexible(
                                            child: Text(
                                                widget.account
                                                            ?.trim()
                                                            .isNotEmpty ==
                                                        true
                                                    ? widget.account!
                                                    : 'Choose your username',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 13, color: ink))),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.edit_outlined,
                                            size: 14, color: muted),
                                      ]),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                      text: archived
                                          ? 'KEPT FOR '
                                          : 'YOUR IDEAS. '),
                                  TextSpan(
                                      text: archived ? 'LATER.' : 'WITH YOU.',
                                      style: const TextStyle(color: accent))
                                ]),
                                style: const TextStyle(
                                  fontFamily: 'BebasNeue',
                                  fontSize: 38,
                                  height: 1.12,
                                  fontWeight: FontWeight.w400,
                                  color: ink,
                                  letterSpacing: .5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                archived
                                    ? 'Your saved items, just out of the way.'
                                    : 'Notes, links, code & images. Kept close.',
                                style: TextStyle(
                                    color: ink.withValues(alpha: .65)),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: TextField(
                            controller: searchController,
                            onChanged: (v) => setState(() => query = v),
                            decoration: const InputDecoration(
                              hintText: 'Search titles, content, or tags',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Everything'),
                                selected: type == null,
                                onSelected: (_) => setState(() => type = null),
                              ),
                              for (final t in ItemType.values)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                    avatar: Icon(typeIcon(t), size: 17),
                                    label: Text(typeLabel(t)),
                                    selected: type == t,
                                    onSelected: (_) => setState(() => type = t),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                archived ? 'ARCHIVE' : 'YOUR INBOX',
                                style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w400,
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loading || error != null || visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(error!),
                                      TextButton(
                                        onPressed: initialize,
                                        child: const Text('Try again'),
                                      ),
                                    ],
                                  ),
                                )
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          archived
                                              ? Icons.inventory_2_outlined
                                              : Icons.bookmark_border_rounded,
                                          size: 52,
                                          color: ink,
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          query.isNotEmpty ||
                                                  type != null ||
                                                  tag != null
                                              ? 'No matching items'
                                              : archived
                                                  ? 'Your archive is empty'
                                                  : 'Start with something worth keeping',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          query.isNotEmpty ||
                                                  type != null ||
                                                  tag != null
                                              ? 'Try another search or clear your filters.'
                                              : archived
                                                  ? 'Archive items from their detail screen.'
                                                  : 'Tap Save ideas to add your first item.',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                    ),
                  if (!loading && error == null && visible.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = visible[index];
                          return Card(
                            color: panel,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                  color: typeColor(item.type)
                                      .withValues(alpha: .16)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => detail(item),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          typeIcon(item.type),
                                          size: 18,
                                          color: typeColor(item.type),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          typeLabel(item.type),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: typeColor(item.type),
                                              fontWeight: FontWeight.w700),
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                    if (item.image != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.memory(
                                            item.image!,
                                            height: 140,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Text(
                                              'Image could not be displayed',
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (item.type == ItemType.image &&
                                        item.image == null)
                                      const Padding(
                                          padding: EdgeInsets.only(top: 12),
                                          child: Text(
                                              'Image unavailable. Edit this idea to replace it.',
                                              style: TextStyle(
                                                  color: muted, fontSize: 12))),
                                    const SizedBox(height: 12),
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'BebasNeue',
                                        fontSize: 24,
                                        fontWeight: FontWeight.w400,
                                        color: ink,
                                      ),
                                    ),
                                    if (item.content.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          item.content,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: muted,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 5,
                                      children: [
                                        for (final t in item.tags)
                                          Text(
                                            '#$t',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: ink,
                                            ),
                                          ),
                                        Text(
                                          date(item.updated),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }, childCount: visible.length),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: store == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => edit(),
              backgroundColor: accent,
              foregroundColor: paper,
              icon: const Icon(Icons.add),
              label: const Text('Save ideas'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: archived ? 1 : 0,
        onDestinationSelected: (index) => setState(() {
          archived = index == 1;
          tag = null;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Archive',
          ),
        ],
      ),
    );
  }
}

class Editor extends StatefulWidget {
  final ItemRepository store;
  final SavedItem? item;
  final SharedDraft? draft;
  const Editor({super.key, required this.store, this.item, this.draft});
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final form = GlobalKey<FormState>();
  late TextEditingController title, content, tags;
  late ItemType type;
  Uint8List? image;
  bool busy = false, picking = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final item = widget.item;
    title = TextEditingController(text: item?.title ?? widget.draft?.title);
    content =
        TextEditingController(text: item?.content ?? widget.draft?.content);
    tags = TextEditingController(text: item?.tags.join(', '));
    type = item?.type ?? widget.draft?.type ?? ItemType.note;
    image = item?.image;
  }

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    tags.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: widget.store.isCloud ? 1200 : 2400,
        maxHeight: widget.store.isCloud ? 1200 : 2400,
        imageQuality: widget.store.isCloud ? 70 : 85,
      );
      if (file != null) {
        if (await file.length() >
            (widget.store.isCloud ? cloudImageLimit : 10 * 1024 * 1024)) {
          throw ArgumentError(widget.store.isCloud
              ? 'Choose an image under 512 KB for cloud saving.'
              : 'Choose an image smaller than 10 MB.');
        }
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => image = bytes);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ArgumentError
              ? friendlyError(e)
              : 'Could not load the image. Check photo access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (type == ItemType.image && image == null) {
      setState(() => error = 'Choose an image first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.save(
        id: widget.item?.id,
        type: type,
        title: title.text,
        content: content.text,
        tags: parseTags(tags.text),
        image: image,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.item == null ? 'Save ideas' : 'Edit idea',
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Make room for a good find.',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in ItemType.values)
                        ChoiceChip(
                          label: Text(typeLabel(t)),
                          avatar: Icon(typeIcon(t), size: 18),
                          selected: type == t,
                          onSelected: busy
                              ? null
                              : (_) => setState(() {
                                    type = t;
                                    error = null;
                                  }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: title,
                    enabled: !busy,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Give it a memorable name',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Add a title.' : null,
                  ),
                  const SizedBox(height: 12),
                  if (type == ItemType.image) ...[
                    if (image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(
                          image!,
                          height: 230,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Text('Please choose a different image.'),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: busy || picking ? null : pick,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        picking
                            ? 'Loading image…'
                            : image == null
                                ? 'Choose an image'
                                : 'Replace image',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: content,
                    enabled: !busy,
                    minLines: type == ItemType.link ? 2 : 5,
                    maxLines: 12,
                    keyboardType: type == ItemType.link
                        ? TextInputType.url
                        : TextInputType.multiline,
                    style: const TextStyle(fontFamily: 'Nunito'),
                    decoration: InputDecoration(
                      labelText: type == ItemType.link
                          ? 'URL'
                          : type == ItemType.image
                              ? 'Caption (optional)'
                              : 'Content',
                      hintText: type == ItemType.link
                          ? 'https://example.com'
                          : 'Something you want to remember…',
                    ),
                    validator: (v) {
                      if (type == ItemType.link && webUrl(v ?? '') == null) {
                        return 'Use a full http:// or https:// URL.';
                      }
                      if ((type == ItemType.note || type == ItemType.snippet) &&
                          (v ?? '').trim().isEmpty) {
                        return 'Add some content.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: tags,
                    enabled: !busy,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'ideas, reading, inspiration',
                      helperText: 'Separate tags with commas.',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy || picking ? null : save,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    label: Text(busy ? 'Saving…' : 'Save item'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.store.isCloud
                        ? 'Saved privately to your account. Images up to 512 KB.'
                        : 'Saved on this device. Always close at hand.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class Detail extends StatefulWidget {
  final ItemRepository store;
  final SavedItem item;
  const Detail({super.key, required this.store, required this.item});
  @override
  State<Detail> createState() => _DetailState();
}

class _DetailState extends State<Detail> {
  late SavedItem item;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    item = widget.item;
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Editor(store: widget.store, item: item),
      ),
    );
    try {
      final all = await widget.store.all();
      if (mounted) {
        setState(() => item = all.firstWhere((i) => i.id == item.id));
      }
    } catch (_) {
      message('Could not refresh this item.');
    }
  }

  Future<void> mutate(bool deleting) async {
    if (deleting) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this item?'),
          content: const Text(
            'This permanently removes the item and its saved image.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep item'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      if (deleting) {
        await widget.store.delete(item.id);
      } else {
        await widget.store.archive(item.id, !item.archived);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      message(friendlyError(e));
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openLink() async {
    try {
      final uri = webUrl(item.content);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        message('Could not open this link.');
      }
    } catch (_) {
      message('Could not open this link.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Saved idea'),
          actions: [
            IconButton(
              tooltip: 'Edit item',
              onPressed: busy ? null : edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Icon(typeIcon(item.type), color: ink),
                    const SizedBox(width: 8),
                    Text(typeLabel(item.type)),
                    const Spacer(),
                    if (item.archived) const Chip(label: Text('Archived')),
                  ],
                ),
                const SizedBox(height: 20),
                SelectableText(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 20),
                if (item.image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      item.image!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Text('Image could not be displayed.'),
                    ),
                  ),
                if (item.type == ItemType.image && item.image == null)
                  const Text(
                      'Image unavailable. Edit this idea to replace it.'),
                const SizedBox(height: 16),
                SelectableText(
                  item.content,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.6,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in item.tags)
                      Chip(
                          label: Text('#$t'),
                          backgroundColor: accent.withValues(alpha: .10)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Created ${date(item.created)} · Updated ${date(item.updated)}',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 28),
                if (widget.store is CloudItemStore)
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) => PublicShareDialog(
                                store: widget.store as CloudItemStore,
                                item: item)),
                    icon: const Icon(Icons.public_rounded),
                    label: const Text('Public link'),
                  ),
                if (item.type == ItemType.link)
                  FilledButton.icon(
                    onPressed: openLink,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open link'),
                  ),
                if (item.content.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: item.content));
                      message('Copied to clipboard');
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy content'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => mutate(false),
                  icon: Icon(
                    item.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label:
                      Text(item.archived ? 'Restore to inbox' : 'Archive item'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => mutate(true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete item'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
