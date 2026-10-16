import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'store.dart';

class SharedDraft {
  final ItemType type;
  final String title, content;
  const SharedDraft(this.type, this.title, this.content);
  factory SharedDraft.fromShare(String text, [String subject = '']) {
    final trimmed = text.trim();
    // Chrome often shares a title followed by a URL. Keep arbitrary prose as a
    // note; only a standalone URL or a final URL on its own line becomes a link.
    final lines = trimmed.split('\n');
    final url = webUrl(trimmed) ?? webUrl(lines.last.trim());
    final title = subject.trim().isNotEmpty
        ? subject.trim()
        : url != null && lines.length > 1
            ? lines.take(lines.length - 1).join(' ').trim()
            : '';
    return SharedDraft(
        url == null ? ItemType.note : ItemType.link,
        title.length > 120 ? title.substring(0, 120) : title,
        url?.toString() ?? text);
  }
}

class ShareIntake extends ChangeNotifier {
  static const channel = MethodChannel('klasc/share');
  final List<SharedDraft> _pending = [];
  bool get hasPending => _pending.isNotEmpty;
  SharedDraft? take() => _pending.isEmpty ? null : _pending.removeAt(0);
  void receive(Map<dynamic, dynamic> data) {
    final text = data['text'];
    if (text is! String || text.trim().isEmpty) return;
    final subject = data['subject'];
    _pending.add(SharedDraft.fromShare(text, subject is String ? subject : ''));
    notifyListeners();
  }

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'received' && call.arguments is Map) {
        receive(call.arguments as Map);
      }
    });
    final initial = await channel.invokeListMethod<dynamic>('takeShares');
    for (final value in initial ?? []) {
      if (value is Map) receive(value);
    }
  }
}

final shareIntake = ShareIntake();
