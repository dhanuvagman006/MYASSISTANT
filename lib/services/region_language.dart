import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Resolves the user's REGIONAL language from their location, so a user
/// in Karnataka is heard (and answered) in Kannada by default, in Kerala
/// in Malayalam, and so on. The "I speak…" picker always overrides.
///
/// Indian states are resolved DIRECTLY from latitude/longitude with
/// coarse bounding boxes — the platform geocoder proved unreliable for
/// state names (it varies by device/locale, which silently fell back to
/// country-level Hindi). The geocoder is now only used for the country
/// when the user is outside India.
///
/// Needs ACCESS_COARSE_LOCATION in AndroidManifest.xml (see README).
class RegionLanguage {
  RegionLanguage._();

  /// (minLat, maxLat, minLng, maxLng, locale) — checked IN ORDER, first
  /// hit wins. Boxes overlap at borders; the order resolves the common
  /// cities correctly (Bengaluru→kn, Chennai→ta, Hyderabad→te,
  /// Kochi→ml, Mysuru→kn, Mumbai→mr…). Coarse by design.
  static const List<(double, double, double, double, String)> _indiaBoxes = [
    (14.88, 15.82, 73.65, 74.35, 'en_IN'), // Goa
    (8.00, 10.50, 76.00, 77.60, 'ml_IN'), // Kerala (south)
    (10.50, 12.85, 74.80, 76.35, 'ml_IN'), // Kerala (north)
    (15.85, 19.95, 77.20, 81.35, 'te_IN'), // Telangana
    (11.55, 18.50, 73.90, 78.60, 'kn_IN'), // Karnataka
    (7.90, 13.50, 77.30, 80.40, 'ta_IN'), // Tamil Nadu (east/main)
    (9.50, 12.05, 76.20, 77.30, 'ta_IN'), // Tamil Nadu (west)
    (12.55, 19.20, 76.70, 84.85, 'te_IN'), // Andhra Pradesh
    (15.60, 22.05, 72.60, 80.95, 'mr_IN'), // Maharashtra
    (20.05, 24.75, 68.05, 74.50, 'gu_IN'), // Gujarat
    (17.75, 22.60, 81.30, 87.55, 'or_IN'), // Odisha
    (21.45, 27.25, 85.75, 89.95, 'bn_IN'), // West Bengal
    (29.50, 32.60, 73.85, 76.95, 'pa_IN'), // Punjab
  ];

  /// Country → speech locale, for outside India.
  static const Map<String, String> _countries = {
    'IN': 'hi_IN',
    'PK': 'ur_PK',
    'BD': 'bn_BD',
    'LK': 'si_LK',
    'NP': 'ne_NP',
    'FR': 'fr_FR',
    'DE': 'de_DE',
    'ES': 'es_ES',
    'IT': 'it_IT',
    'PT': 'pt_PT',
    'BR': 'pt_BR',
    'MX': 'es_MX',
    'RU': 'ru_RU',
    'JP': 'ja_JP',
    'KR': 'ko_KR',
    'CN': 'zh_CN',
    'TW': 'zh_TW',
    'TH': 'th_TH',
    'VN': 'vi_VN',
    'ID': 'id_ID',
    'TR': 'tr_TR',
    'SA': 'ar_SA',
    'AE': 'ar_AE',
    'EG': 'ar_EG',
  };

  static bool _inIndia(double lat, double lng) =>
      lat >= 6.5 && lat <= 35.7 && lng >= 68.0 && lng <= 97.5;

  static String? _indiaStateLocale(double lat, double lng) {
    for (final b in _indiaBoxes) {
      if (lat >= b.$1 && lat <= b.$2 && lng >= b.$3 && lng <= b.$4) {
        return b.$5;
      }
    }
    return null;
  }

  /// Ordered locale candidates for where the user is right now
  /// (state language first, then country language). Empty if location
  /// is unavailable or permission is denied.
  static Future<List<String>> candidates() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const [];

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return const [];
      }

      // City-level accuracy is plenty for "which state am I in".
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 10));

      final lat = pos.latitude, lng = pos.longitude;
      final out = <String>[];

      if (_inIndia(lat, lng)) {
        // Pure math — no geocoder, no permission beyond location, no
        // network. Karnataka WILL come back kn_IN.
        final state = _indiaStateLocale(lat, lng);
        if (state != null) out.add(state);
        if (!out.contains('hi_IN')) out.add('hi_IN');
        return out;
      }

      // Outside India: geocode the country only.
      try {
        final marks = await placemarkFromCoordinates(lat, lng);
        final country =
            (marks.isNotEmpty ? marks.first.isoCountryCode ?? '' : '')
                .trim()
                .toUpperCase();
        final byCountry = _countries[country];
        if (byCountry != null) out.add(byCountry);
      } catch (_) {}
      return out;
    } catch (_) {
      return const [];
    }
  }
}
