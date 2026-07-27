class ChatSource {
  final String name;
  final String url;
  const ChatSource({required this.name, this.url = ''});

  static List<ChatSource> listFromJson(dynamic j) {
    if (j is! List) return const [];
    return j
        .whereType<Map>()
        .map((m) => ChatSource(
              name: (m['name'] ?? '').toString(),
              url: (m['url'] ?? '').toString(),
            ))
        .where((s) => s.name.isNotEmpty)
        .toList(growable: false);
  }
}

import 'user_document.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;

  /// A5 — live-information sources behind an assistant reply (may be empty).
  final List<ChatSource> sources;

  /// Saved documents Hari recalled for this reply — the app shows them as
  /// tappable cards while the answer is spoken (voice-to-voice recall).
  final List<UserDocument> documents;

  const ChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
    this.documents = const [],
  });

  /// Sources never travel back to the model — context stays lean.
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
