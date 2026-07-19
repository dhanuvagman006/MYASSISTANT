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

  /// Shared secret matching the backend's APP_API_KEY (dev/X-App-Key mode).
  /// Pass with: --dart-define=APP_API_KEY=...
  static const String _appApiKey = String.fromEnvironment('APP_API_KEY');

  /// Session JWT issued by the backend after any sign-in (email/Google/Apple).
  /// Managed by AuthService — set on sign-in, cleared on sign-out.
  static String? sessionToken;

  static Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (sessionToken != null) 'Authorization': 'Bearer $sessionToken'
        else if (_appApiKey.isNotEmpty) 'X-App-Key': _appApiKey,
      };

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

  /// Fire-and-forget connection warm-up. Called the instant the wake
  /// word fires so DNS/TLS (and a sleeping free-tier host) are already
  /// awake by the time the question finishes being spoken.
  static void warm() {
    http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 8))
        .ignore();
  }

  static Future<String> sendChat(List<ChatMessage> history) async {
    final r = await http
        .post(
          Uri.parse('$baseUrl/chat'),
          headers: _authHeaders,
          body: jsonEncode({
            'messages': history.map((m) => m.toJson()).toList(),
            'language': 'auto',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (r.statusCode == 401) {
      throw Exception('Sign-in required — check APP_API_KEY or Google sign-in.');
    }
    if (r.statusCode != 200) {
      throw Exception('Server error ${r.statusCode}');
    }
    return (jsonDecode(r.body)['reply'] as String?) ?? '';
  }
}
