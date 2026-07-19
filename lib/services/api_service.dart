import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/memory_item.dart';
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

  /// Regional language from the caller's IP (server-side lookup —
  /// no location permission needed). Returns e.g. 'kn_IN', or null.
  static Future<String?> fetchRegionLocale() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/region'), headers: _authHeaders)
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final locale = jsonDecode(r.body)['locale'] as String?;
      return (locale != null && locale.isNotEmpty) ? locale : null;
    } catch (_) {
      return null;
    }
  }

  /// Sends a recorded question to /stt (Whisper). Returns the
  /// transcript; the language is auto-detected server-side.
  static Future<String> transcribe(
    String filePath, {
    String? forceLanguage, // ISO-639-1, e.g. 'kn' — user picked it: lock it
    String? hintLanguage, // ISO-639-1 — bias detection, others still work
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/stt'));
    // Multipart sets its own Content-Type; add only auth.
    if (sessionToken != null) {
      req.headers['Authorization'] = 'Bearer $sessionToken';
    } else if (_appApiKey.isNotEmpty) {
      req.headers['X-App-Key'] = _appApiKey;
    }
    if (forceLanguage != null) req.fields['language'] = forceLanguage;
    if (hintLanguage != null) req.fields['hint'] = hintLanguage;
    req.files.add(await http.MultipartFile.fromPath('audio', filePath));

    final streamed = await req.send().timeout(const Duration(seconds: 40));
    final r = await http.Response.fromStream(streamed);
    try {
      File(filePath).delete().ignore();
    } catch (_) {}
    if (r.statusCode != 200) {
      throw Exception('stt ${r.statusCode}');
    }
    return (jsonDecode(r.body)['text'] as String?)?.trim() ?? '';
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

  /// Personalized spoken greeting for app open / sign-in. The backend
  /// builds it from the user's memory; if Hari barely knows them, the
  /// greeting includes one get-to-know-you question.
  static Future<String?> fetchGreeting() async {
    try {
      final r = await http
          .post(Uri.parse('$baseUrl/chat/greeting'), headers: _authHeaders)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final g = (jsonDecode(r.body)['greeting'] as String?)?.trim();
      return (g == null || g.isEmpty) ? null : g;
    } catch (_) {
      return null;
    }
  }

  // ---------------- PER-USER MEMORY ----------------
  // Backs the "Privacy & memory → WHAT I REMEMBER" screen. All calls
  // require a signed-in session (memory is per-account, not per-device).

  /// Everything Hari remembers about the signed-in user.
  static Future<List<MemoryItem>> fetchMemories() async {
    final r = await http
        .get(Uri.parse('$baseUrl/memory'), headers: _authHeaders)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw Exception('Could not load memories (${r.statusCode})');
    }
    final list = (jsonDecode(r.body)['memories'] as List? ?? []);
    return list
        .map((m) => MemoryItem.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// User teaches Hari a fact directly ("remember that I'm vegetarian").
  static Future<void> addMemory(String key, String value,
      {String category = 'fact'}) async {
    final r = await http
        .post(
          Uri.parse('$baseUrl/memory'),
          headers: _authHeaders,
          body: jsonEncode({'key': key, 'value': value, 'category': category}),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Could not save (${r.statusCode})');
  }

  /// Forget one fact — powers the per-row delete button.
  static Future<void> deleteMemory(int id) async {
    final r = await http
        .delete(Uri.parse('$baseUrl/memory/$id'), headers: _authHeaders)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Could not delete (${r.statusCode})');
  }

  /// Forget everything — the nuclear "clear memory" button.
  static Future<void> clearMemories() async {
    final r = await http
        .delete(Uri.parse('$baseUrl/memory'), headers: _authHeaders)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Could not clear (${r.statusCode})');
  }
}
