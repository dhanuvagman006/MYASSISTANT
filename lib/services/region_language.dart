import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Resolves the user's REGIONAL language from their location, so a user
/// in Karnataka is heard (and answered) in Kannada by default, in Kerala
/// in Malayalam, and so on — no setup needed. The "I speak…" picker
/// always overrides this.
///
/// Needs ACCESS_COARSE_LOCATION in AndroidManifest.xml (see README).
class RegionLanguage {
  RegionLanguage._();

  /// Indian state / union territory → speech locale.
  /// Keys are lowercase admin-area names as the platform geocoder
  /// returns them.
  static const Map<String, String> _indiaStates = {
    'karnataka': 'kn_IN',
    'tamil nadu': 'ta_IN',
    'kerala': 'ml_IN',
    'andhra pradesh': 'te_IN',
    'telangana': 'te_IN',
    'maharashtra': 'mr_IN',
    'gujarat': 'gu_IN',
    'punjab': 'pa_IN',
    'west bengal': 'bn_IN',
    'tripura': 'bn_IN',
    'odisha': 'or_IN',
    'assam': 'as_IN',
    'uttar pradesh': 'hi_IN',
    'bihar': 'hi_IN',
    'madhya pradesh': 'hi_IN',
    'rajasthan': 'hi_IN',
    'haryana': 'hi_IN',
    'delhi': 'hi_IN',
    'nct of delhi': 'hi_IN',
    'jharkhand': 'hi_IN',
    'chhattisgarh': 'hi_IN',
    'uttarakhand': 'hi_IN',
    'himachal pradesh': 'hi_IN',
    'jammu and kashmir': 'ur_IN',
    'chandigarh': 'hi_IN',
    'puducherry': 'ta_IN',
    'goa': 'en_IN',
  };

  /// Country → speech locale, for outside India / unknown state.
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

      final marks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isEmpty) return const [];

      final state = (marks.first.administrativeArea ?? '').trim().toLowerCase();
      final country = (marks.first.isoCountryCode ?? '').trim().toUpperCase();

      final out = <String>[];
      final byState = _indiaStates[state];
      if (country == 'IN' && byState != null) out.add(byState);
      final byCountry = _countries[country];
      if (byCountry != null && !out.contains(byCountry)) out.add(byCountry);
      return out;
    } catch (_) {
      return const [];
    }
  }
}
