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

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;

  /// A5 — live-information sources behind an assistant reply (may be empty).
  final List<ChatSource> sources;

  const ChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
  });

  /// Sources never travel back to the model — context stays lean.
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
