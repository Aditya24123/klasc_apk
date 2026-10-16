import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloud_store.dart';
import 'design.dart';
import 'store.dart';
import 'image_data.dart';

class PublicShareDialog extends StatefulWidget {
  final CloudItemStore store;
  final SavedItem item;
  const PublicShareDialog({super.key, required this.store, required this.item});
  @override
  State<PublicShareDialog> createState() => _PublicShareDialogState();
}

class _PublicShareDialogState extends State<PublicShareDialog> {
  String? token, error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    run(() async {
      token = await widget.store.publicToken(widget.item.id);
    });
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      error = friendlyError(e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Share this idea'),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(widget.item.title,
                  style: const TextStyle(
                      color: accent, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                  'Anyone with the link can read this item’s title and content or image. Your inbox, tags and profile stay private.'),
              const SizedBox(height: 8),
              const Text(
                  'The link shows a snapshot. To share later edits, revoke it and create a new link.',
                  style: TextStyle(color: muted, fontSize: 12)),
              if (busy)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator())),
              if (token != null) ...[
                const SizedBox(height: 16),
                SelectableText('${CloudItemStore.shareOrigin}/s/$token',
                    style: const TextStyle(fontSize: 12)),
              ],
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ])),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Close')),
          if (error != null)
            TextButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          token =
                              await widget.store.publicToken(widget.item.id);
                        }),
                child: const Text('Retry')),
          if (token == null && error == null)
            FilledButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          token = await widget.store
                              .createPublicLink(widget.item.id);
                        }),
                child: const Text('Create public link')),
          if (token != null) ...[
            TextButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          await widget.store.revokePublicLink(widget.item.id);
                          token = null;
                        }),
                child: const Text('Revoke link')),
            FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        String message;
                        try {
                          await Clipboard.setData(ClipboardData(
                              text: '${CloudItemStore.shareOrigin}/s/$token'));
                          message = 'Public link copied';
                        } catch (_) {
                          message =
                              'Could not copy. Select the link to copy it manually.';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(message)));
                        }
                      },
                child: const Text('Copy link')),
          ],
        ],
      );
}

class PublicItemPage extends StatefulWidget {
  final String token;
  final Future<Map<String, dynamic>?> Function(String)? loader;
  const PublicItemPage({super.key, required this.token, this.loader});
  @override
  State<PublicItemPage> createState() => _PublicItemPageState();
}

class _PublicItemPageState extends State<PublicItemPage> {
  Map<String, dynamic>? item;
  bool loading = true, unavailable = false, failed = false, fetching = false;
  Timer? refresh;
  int loadVersion = 0;
  @override
  void initState() {
    super.initState();
    startPolling();
    load();
  }

  void startPolling() {
    refresh?.cancel();
    refresh = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  @override
  void didUpdateWidget(covariant PublicItemPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      item = null;
      loading = true;
      unavailable = failed = false;
      startPolling();
      load(force: true);
    }
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    if (fetching && !force) return;
    fetching = true;
    final request = ++loadVersion;
    Map<String, dynamic>? data;
    var missing = false, network = false;
    try {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(widget.token)) {
        missing = true;
      } else {
        data = widget.loader != null
            ? await widget.loader!(widget.token)
            : (await FirebaseFirestore.instance
                    .doc('publicShares/${widget.token}')
                    .get(const GetOptions(source: Source.server))
                    .timeout(const Duration(seconds: 20)))
                .data();
        missing = data == null;
      }
    } on FirebaseException catch (e) {
      missing = e.code == 'permission-denied' || e.code == 'not-found';
      network = !missing;
    } catch (_) {
      network = true;
    }
    if (mounted && request == loadVersion) {
      fetching = false;
      if (missing) refresh?.cancel();
      if (!missing && !network && refresh?.isActive != true) startPolling();
      setState(() {
        loading = false;
        unavailable = missing;
        failed = network;
        item = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const BrandHeader()),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: loading
                    ? const CircularProgressIndicator()
                    : unavailable || failed
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.link_off_rounded,
                                      color: accent, size: 42),
                                  const SizedBox(height: 16),
                                  Text(
                                      unavailable
                                          ? 'This link is unavailable'
                                          : 'Could not load this idea',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  const SizedBox(height: 8),
                                  Text(
                                      unavailable
                                          ? 'It may have been revoked or the item deleted.'
                                          : 'Check your connection and try again.',
                                      textAlign: TextAlign.center),
                                  TextButton(
                                      onPressed: load,
                                      child: const Text('Try again')),
                                ]))
                        : ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                                const Text('SHARED IDEA · READ ONLY',
                                    style: TextStyle(
                                        color: accent,
                                        letterSpacing: 1.5,
                                        fontSize: 11)),
                                const SizedBox(height: 16),
                                Semantics(
                                    header: true,
                                    label: item!['title'] as String,
                                    child: ExcludeSemantics(
                                        child: SelectableText(
                                            item!['title'] as String,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineLarge))),
                                const SizedBox(height: 20),
                                if (item!['imageData'] != null)
                                  SharedImage(value: item!['imageData']),
                                Semantics(
                                    label: item!['content'] as String,
                                    child: ExcludeSemantics(
                                        child: SelectableText(
                                            item!['content'] as String,
                                            style: const TextStyle(
                                                fontSize: 17, height: 1.6)))),
                                if (item!['type'] == 'link' &&
                                    webUrl(item!['content'] as String) != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 20),
                                      child: OutlinedButton.icon(
                                          onPressed: () async {
                                            try {
                                              final opened = await launchUrl(
                                                  webUrl(item!['content']
                                                      as String)!,
                                                  mode: LaunchMode
                                                      .externalApplication);
                                              if (!opened) {
                                                throw StateError(
                                                    'No app could open the link.');
                                              }
                                            } catch (_) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'Could not open the link.')));
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.open_in_new),
                                          label: const Text(
                                              'Open original link'))),
                                const SizedBox(height: 24),
                                const Text(
                                    'Shared from KLASC. This page contains only this idea.',
                                    style:
                                        TextStyle(color: muted, fontSize: 12)),
                              ]))),
      );
}

class SharedImage extends StatelessWidget {
  final Object? value;
  const SharedImage({super.key, required this.value});
  @override
  Widget build(BuildContext context) {
    final bytes = decodeImageData(value);
    if (bytes == null) return const Text('Image unavailable');
    return Image.memory(bytes,
        errorBuilder: (_, __, ___) => const Text('Image unavailable'));
  }
}
