/// One fact Hari remembers about the signed-in user.
/// Mirrors a row from the backend's GET /memory.
class MemoryItem {
  final int id;
  final String category; // profile | preference | fact | context
  final String key; // machine key, e.g. 'favorite_food'
  final String value; // human sentence shown in the UI
  final String source; // signup | ai | user
  final DateTime updatedAt;

  const MemoryItem({
    required this.id,
    required this.category,
    required this.key,
    required this.value,
    required this.source,
    required this.updatedAt,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> j) => MemoryItem(
        id: j['id'] as int,
        category: (j['category'] as String?) ?? 'fact',
        key: (j['key'] as String?) ?? '',
        value: (j['value'] as String?) ?? '',
        source: (j['source'] as String?) ?? 'ai',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['updatedAt'] as num?)?.toInt() ?? 0),
      );

  /// 'favorite_food' → 'Favorite food' for display.
  String get title {
    final t = key.replaceAll('_', ' ').trim();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }
}
