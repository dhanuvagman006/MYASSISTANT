/// Result of a /vision call (Group B).
class VisionResult {
  final String answer;
  final VisionAction? action;
  const VisionResult({required this.answer, this.action});

  factory VisionResult.fromJson(Map<String, dynamic> j) => VisionResult(
        answer: (j['answer'] ?? '').toString(),
        action: j['action'] is Map<String, dynamic>
            ? VisionAction.fromJson(j['action'] as Map<String, dynamic>)
            : null,
      );
}

/// B4 — a suggested next step extracted from a screenshot, awaiting the
/// user's one-tap approval (currently: calendar/reminder entries).
class VisionAction {
  final String type; // 'calendar'
  final String title;
  final DateTime? start;
  final DateTime? end;
  final String? location;

  const VisionAction({
    required this.type,
    required this.title,
    this.start,
    this.end,
    this.location,
  });

  static VisionAction? fromJson(Map<String, dynamic> j) {
    final title = (j['title'] ?? '').toString();
    if (title.isEmpty) return null;
    return VisionAction(
      type: (j['type'] ?? 'calendar').toString(),
      title: title,
      start: DateTime.tryParse((j['startIso'] ?? '').toString())?.toLocal(),
      end: DateTime.tryParse((j['endIso'] ?? '').toString())?.toLocal(),
      location: j['location']?.toString(),
    );
  }
}
