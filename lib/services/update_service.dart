import 'dart:io' show Platform;

import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/remote_config.dart';

/// TWO-LAYER UPDATE STRATEGY — same on both platforms.
///
/// 1. SERVER FEATURES (instant, no rebuild, no store review):
///    The AI lives on the backend, so new capabilities ship server-side.
///    /config carries feature flags + announcements; the app reads them on
///    every launch. This is how most "the assistant can now do X" updates land.
///
/// 2. APP BINARY (needs a store release):
///    New screens/native code require a new build. The update button then:
///      • Android → Google Play In-App Updates (installs inside the app)
///      • iOS     → opens the App Store page (Apple has no in-app update API)
///
/// ⚠️ Never download and execute code outside the stores. It violates both
/// Google Play and Apple App Store policy and gets apps removed.
class UpdateService {
  /// iOS App Store id — fill in after the first App Store submission.
  static const String appStoreId = '0000000000';

  static Future<UpdateStatus> check(RemoteConfig config) async {
    final info = await PackageInfo.fromPlatform();
    final installed = int.tryParse(info.buildNumber) ?? 1;

    return UpdateStatus(
      upToDate: installed >= config.latestVersionCode,
      installedVersion: info.version,
      latestVersion: config.latestVersionName,
      changelog: config.changelog,
      forced: installed < config.forceUpdateBelow,
    );
  }

  static Future<void> launch({required bool forced}) async {
    if (Platform.isAndroid) {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        forced
            ? await InAppUpdate.performImmediateUpdate()
            : await InAppUpdate.startFlexibleUpdate()
                .then((_) => InAppUpdate.completeFlexibleUpdate());
      }
    } else if (Platform.isIOS) {
      final uri = Uri.parse('https://apps.apple.com/app/id$appStoreId');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

class UpdateStatus {
  final bool upToDate;
  final String installedVersion;
  final String latestVersion;
  final List<String> changelog;
  final bool forced;

  const UpdateStatus({
    required this.upToDate,
    required this.installedVersion,
    required this.latestVersion,
    required this.changelog,
    required this.forced,
  });
}
