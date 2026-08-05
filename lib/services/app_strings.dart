import 'style_prefs.dart';

/// A3 — application menus in English, Hindi and Malayalam.
///
/// Deliberately NOT flutter gen-l10n: the app has a handful of menu
/// strings, so a const lookup table is smaller, has zero codegen/build
/// steps, and lookups are O(1) map reads on const data — nothing is
/// allocated at runtime. Conversations themselves are already
/// multi-language via the backend (50+ languages).
class S {
  static const Map<String, Map<String, String>> _t = {
    // ---- bottom navigation ----
    'tab_assistant': {'en': 'Assistant', 'hi': 'सहायक', 'ml': 'അസിസ്റ്റന്റ്'},
    'tab_today': {'en': 'Today', 'hi': 'आज', 'ml': 'ഇന്ന്'},
    'tab_calls': {'en': 'Calls', 'hi': 'कॉल', 'ml': 'കോളുകൾ'},
    'tab_you': {'en': 'You', 'hi': 'आप', 'ml': 'നിങ്ങൾ'},
    // ---- app bar / menus ----
    'sign_out': {'en': 'Sign out', 'hi': 'साइन आउट', 'ml': 'സൈൻ ഔട്ട്'},
    'sign_out_q': {'en': 'Sign out?', 'hi': 'साइन आउट करें?', 'ml': 'സൈൻ ഔട്ട് ചെയ്യണോ?'},
    'sign_out_body': {
      'en': 'You can sign back in any time.',
      'hi': 'आप कभी भी दोबारा साइन इन कर सकते हैं।',
      'ml': 'എപ്പോൾ വേണമെങ്കിലും വീണ്ടും സൈൻ ഇൻ ചെയ്യാം.'
    },
    'cancel': {'en': 'Cancel', 'hi': 'रद्द करें', 'ml': 'റദ്ദാക്കുക'},
    'settings': {'en': 'Assistant settings', 'hi': 'सहायक सेटिंग्स', 'ml': 'അസിസ്റ്റന്റ് ക്രമീകരണങ്ങൾ'},
    // ---- style sheet (A4) ----
    'style_title': {'en': 'Assistant style', 'hi': 'सहायक की शैली', 'ml': 'അസിസ്റ്റന്റ് ശൈലി'},
    'style_tone': {'en': 'Tone', 'hi': 'लहजा', 'ml': 'ശൈലി'},
    'tone_friendly': {'en': 'Friendly', 'hi': 'दोस्ताना', 'ml': 'സൗഹൃദപരം'},
    'tone_professional': {'en': 'Professional', 'hi': 'पेशेवर', 'ml': 'പ്രൊഫഷണൽ'},
    'tone_cheerful': {'en': 'Cheerful', 'hi': 'उत्साही', 'ml': 'ഉന്മേഷം'},
    'tone_calm': {'en': 'Calm', 'hi': 'शांत', 'ml': 'ശാന്തം'},
    'style_length': {'en': 'Answer length', 'hi': 'उत्तर की लंबाई', 'ml': 'ഉത്തരത്തിന്റെ ദൈർഘ്യം'},
    'len_short': {'en': 'Short', 'hi': 'छोटा', 'ml': 'ചെറുത്'},
    'len_balanced': {'en': 'Balanced', 'hi': 'संतुलित', 'ml': 'സന്തുലിതം'},
    'len_detailed': {'en': 'Detailed', 'hi': 'विस्तृत', 'ml': 'വിശദം'},
    'style_voice_speed': {'en': 'Voice speed', 'hi': 'आवाज़ की गति', 'ml': 'ശബ്ദ വേഗത'},
    'style_app_language': {'en': 'App language', 'hi': 'ऐप की भाषा', 'ml': 'ആപ്പ് ഭാഷ'},
    'lang_en': {'en': 'English', 'hi': 'English', 'ml': 'English'},
    'lang_hi': {'en': 'हिन्दी', 'hi': 'हिन्दी', 'ml': 'हिन्दी'},
    'lang_ml': {'en': 'മലയാളം', 'hi': 'മലയാളം', 'ml': 'മലയാളം'},
    // ---- chat (A1/A5) ----
    'chat_hint': {
      'en': 'Ask anything — any language…',
      'hi': 'कुछ भी पूछें — किसी भी भाषा में…',
      'ml': 'എന്തും ചോദിക്കൂ — ഏത് ഭാഷയിലും…'
    },
    'sources': {'en': 'Sources', 'hi': 'स्रोत', 'ml': 'ഉറവിടങ്ങൾ'},
    'chat_error': {
      'en': "Couldn't reach the assistant. Check your connection.",
      'hi': 'सहायक से संपर्क नहीं हो सका। अपना कनेक्शन जांचें।',
      'ml': 'അസിസ്റ്റന്റുമായി ബന്ധപ്പെടാനായില്ല. കണക്ഷൻ പരിശോധിക്കുക.'
    },
  };

  /// O(1) lookup; falls back to English, then to the key itself so a
  /// missing translation can never crash or blank the UI.
  static String t(String key) {
    final entry = _t[key];
    if (entry == null) return key;
    return entry[StylePrefs.instance.uiLanguage] ?? entry['en'] ?? key;
  }
}
