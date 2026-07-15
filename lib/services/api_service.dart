import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/remote_config.dart';

/// All network traffic goes app → backend → AI providers.
/// The app never holds AI provider keys.
class ApiService {
  /// Point this at your backend.
  /// Android emulator against a local server: http://10.0.2.2:3000
  /// iOS simulator against a local server:    http://localhost:3000
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.myassistant.example.com',
  );

  static RemoteConfig config = const RemoteConfig();

  /// Fetched on every launch — drives feature flags, announcements, update prompts.
  static Future<RemoteConfig> refreshConfig() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/config'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        config = RemoteConfig.fromJson(jsonDecode(r.body));
      }
    } catch (_) {
      // Offline or server down — keep the last known config. Never crash on config.
    }
    return config;
  }

  static Future<String> sendChat(List<ChatMessage> history) async {
    final r = await http
        .post(
          Uri.parse('$baseUrl/chat'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'messages': history.map((m) => m.toJson()).toList(),
            'language': 'auto',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (r.statusCode != 200) {
      throw Exception('Server error ${r.statusCode}');
    }
    return (jsonDecode(r.body)['reply'] as String?) ?? '';
  }
}
