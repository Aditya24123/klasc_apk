import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'store.dart';
import 'image_data.dart';

const cloudImageLimit = 512 * 1024;

class CloudItemStore implements ItemRepository {
  static const shareOrigin = 'https://klasc-8d959.web.app';
  final String ownerId;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  CloudItemStore(this.ownerId,
      {FirebaseFirestore? firestore, FirebaseAuth? auth})
      : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;
  @override
  bool get isCloud => true;
  Stream<void> get changes => _items
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) =>
          !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites)
      .map((_) {});
  CollectionReference<Map<String, dynamic>> get _items =>
      firestore.collection('users').doc(ownerId).collection('items');
  void _checkSession() {
    if (auth.currentUser?.uid != ownerId) {
      throw StateError('Your session changed. Sign in again.');
    }
  }

  DocumentReference<Map<String, dynamic>> _share(int id) =>
      firestore.doc('users/$ownerId/shares/$id');
  Future<String?> publicToken(int id) async {
    _checkSession();
    final snapshot = await _share(id)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    _checkSession();
    return snapshot.data()?['token'] as String?;
  }

  Future<String> createPublicLink(int id) async {
    _checkSession();
    final random = Random.secure();
    final token = List.generate(
            32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    return firestore.runTransaction<String>((tx) async {
      _checkSession();
      final source = await tx.get(_items.doc('$id'));
      final existing = await tx.get(_share(id));
      if (!source.exists) throw StateError('This item no longer exists.');
      if (existing.exists) return existing.data()!['token'] as String;
      final row = source.data()!;
      tx.set(_share(id), {'token': token});
      tx.set(firestore.doc('shareOwners/$token'), {
        'ownerId': ownerId,
        'itemId': '$id',
        'sourceCreated': row['created'],
      });
      tx.set(firestore.doc('publicShares/$token'), {
        for (final key in ['type', 'title', 'content', 'imageData'])
          key: row[key],
        'sharedAt': FieldValue.serverTimestamp(),
      });
      return token;
    }, timeout: const Duration(seconds: 20), maxAttempts: 3);
  }

  Future<void> revokePublicLink(int id) async {
    _checkSession();
    await firestore.runTransaction((tx) async {
      _checkSession();
      final mapping = await tx.get(_share(id));
      if (!mapping.exists) return;
      final token = mapping.data()!['token'];
      tx.delete(firestore.doc('publicShares/$token'));
      tx.delete(firestore.doc('shareOwners/$token'));
      tx.delete(_share(id));
    }, timeout: const Duration(seconds: 20), maxAttempts: 3);
  }

  SavedItem _decode(DocumentSnapshot<Map<String, dynamic>> doc) {
    final row = doc.data()!;
    return SavedItem(
        id: row['id'] as int,
        type: ItemType.values.byName(row['type'] as String),
        title: row['title'] as String,
        content: row['content'] as String,
        tags: List<String>.from(row['tags'] as List),
        created: (row['created'] as Timestamp).toDate().toUtc(),
        updated: (row['updated'] as Timestamp).toDate().toUtc(),
        archived: row['archived'] as bool,
        image: decodeImageData(row['imageData']));
  }

  @override
  Future<List<SavedItem>> all() async {
    _checkSession();
    final snapshot = await _items
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    _checkSession();
    final items = snapshot.docs.map(_decode).toList();
    items.sort((a, b) {
      final order = b.updated.compareTo(a.updated);
      return order == 0 ? b.id.compareTo(a.id) : order;
    });
    return items;
  }

  @override
  Future<int> save(
      {int? id,
      required ItemType type,
      required String title,
      required String content,
      required List<String> tags,
      Uint8List? image}) async {
    _checkSession();
    if (title.trim().isEmpty || title.trim().length > 120) {
      throw ArgumentError('Use a title of 1–120 characters.');
    }
    if (content.length > 50000) {
      throw ArgumentError('Keep content under 50,000 characters.');
    }
    if (type == ItemType.link && webUrl(content) == null) {
      throw ArgumentError('Use a full http:// or https:// link.');
    }
    if ((type == ItemType.note || type == ItemType.snippet) &&
        content.trim().isEmpty) {
      throw ArgumentError('Add some content.');
    }
    if (type == ItemType.image &&
        (image == null || image.isEmpty || image.length > cloudImageLimit)) {
      throw ArgumentError('Choose an image under 512 KB for your cloud inbox.');
    }
    final normalizedTags = parseTags(tags.join(','));
    if (normalizedTags.length > 20 ||
        normalizedTags.any((tag) => tag.length > 40)) {
      throw ArgumentError('Use up to 20 tags, each under 40 characters.');
    }
    final sequence = firestore.doc('users/$ownerId/meta/sequence');
    return firestore.runTransaction<int>((transaction) async {
      _checkSession();
      int itemId;
      DocumentSnapshot<Map<String, dynamic>>? existing;
      if (id == null) {
        final counter = await transaction.get(sequence);
        itemId = counter.data()?['nextId'] as int? ?? 1;
        // Counter and document commit together. Failed requests never consume IDs.
        transaction.set(sequence, {'nextId': itemId + 1});
      } else {
        itemId = id;
        existing = await transaction.get(_items.doc('$id'));
        if (!existing.exists) {
          throw StateError('This item no longer exists. Refresh your inbox.');
        }
      }
      transaction.set(_items.doc('$itemId'), {
        'id': itemId,
        'ownerId': ownerId,
        'type': type.name,
        'title': title.trim(),
        'content': type == ItemType.snippet ? content : content.trim(),
        'tags': normalizedTags,
        'created': existing?.data()?['created'] ?? FieldValue.serverTimestamp(),
        'updated': FieldValue.serverTimestamp(),
        'archived': existing?.data()?['archived'] ?? false,
        'imageData': type == ItemType.image ? base64Encode(image!) : null,
      });
      return itemId;
    }, timeout: const Duration(seconds: 20), maxAttempts: 3);
  }

  @override
  Future<void> archive(int id, bool value) async {
    _checkSession();
    await firestore.runTransaction((transaction) async {
      final ref = _items.doc('$id');
      final item = await transaction.get(ref);
      if (!item.exists) throw StateError('This item no longer exists.');
      transaction.update(
          ref, {'archived': value, 'updated': FieldValue.serverTimestamp()});
    }, timeout: const Duration(seconds: 20), maxAttempts: 3);
  }

  @override
  Future<void> delete(int id) async {
    _checkSession();
    await firestore.runTransaction((transaction) async {
      final ref = _items.doc('$id');
      final item = await transaction.get(ref);
      final mapping = await transaction.get(_share(id));
      if (!item.exists) throw StateError('This item no longer exists.');
      if (mapping.exists) {
        final token = mapping.data()!['token'];
        transaction.delete(firestore.doc('publicShares/$token'));
        transaction.delete(firestore.doc('shareOwners/$token'));
        transaction.delete(_share(id));
      }
      transaction.delete(ref);
    }, timeout: const Duration(seconds: 20), maxAttempts: 3);
  }
}

String friendlyError(Object error) {
  if (error is ArgumentError) return error.message.toString();
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Email or password is incorrect. Try again.',
      'email-already-in-use' =>
        'An account already uses this email. Sign in instead.',
      'weak-password' => 'Use a password with at least 8 characters.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and retry.',
      'network-request-failed' =>
        'No connection. Check your internet and retry.',
      _ => 'Could not sign in. Please try again.',
    };
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Access denied. Sign in again or retry after your project rules are configured.';
  }
  if (error is StateError) return error.message;
  return 'Could not reach your cloud inbox. Check your connection and try again. Your changes are still here.';
}
