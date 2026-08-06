import 'package:flutter/material.dart';

/// One audited assistant action — a row from the backend's GET /actions
/// (Phase 1 · ADR-004: every externally-visible or destructive thing Hari
/// does is logged, and this model is how the user sees it).
class ActionEntry {
  final int id;
  final String action; // dotted past-tense name, e.g. 'reminder.created'
  final String detail; // short human summary written by the backend
  final DateTime at;

  const ActionEntry({
    required this.id,
    required this.action,
    required this.detail,
    required this.at,
  });

  factory ActionEntry.fromJson(Map<String, dynamic> j) => ActionEntry(
        id: (j['id'] as num).toInt(),
        action: (j['action'] as String?) ?? '',
        detail: (j['detail'] as String?) ?? '',
        at: DateTime.fromMillisecondsSinceEpoch(
            (j['created_at'] as num?)?.toInt() ?? 0),
      );

  /// 'calendar.event.created' → 'Calendar event created' for display.
  String get title {
    final t = action.replaceAll('.', ' ').replaceAll('_', ' ').trim();
    return t.isEmpty ? 'Action' : t[0].toUpperCase() + t.substring(1);
  }

  /// Icon per action family — unknown actions get a safe default, so new
  /// backend action types never break this screen.
  IconData get icon {
    final head = action.split('.').first;
    switch (head) {
      case 'reminder':
        return Icons.alarm_rounded;
      case 'document':
        return Icons.description_outlined;
      case 'calendar':
        return Icons.calendar_month_outlined;
      case 'email':
        return Icons.mail_outline_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'call':
        return Icons.call_outlined;
      default:
        return Icons.bolt_rounded;
    }
  }

  /// Destructive actions are tinted so they stand out in the list.
  bool get isDestructive => action.endsWith('.deleted');
}
