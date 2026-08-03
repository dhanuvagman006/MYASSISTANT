import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_update/in_app_update.dart';
import 'package:ota_update/ota_update.dart';
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
/// ⚠️ STORE BUILDS must never self-update outside the stores (policy ban).
/// The self-hosted OTA path below exists ONLY for the sideload/testing
/// distribution phase; the Play path automatically takes precedence for
/// store installs, and the OTA channel should be retired at store launch.
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

  /// Runs the update. [onOtaProgress] fires with 0–100 while the
  /// self-hosted APK downloads (sideload builds only); Play-store installs
  /// use Google's own UI and never call it.
  ///
  /// Android order of preference:
  ///   1. Play In-App Update — works when the app was installed from Play.
  ///   2. Self-hosted OTA (config.apkUrl) — the sideload/testing channel:
  ///      downloads the APK from our backend (sha256-verified) and hands it
  ///      to the system installer. Requires REQUEST_INSTALL_PACKAGES; the
  ///      user confirms the install in the system prompt.
  static Future<void> launch({
    required RemoteConfig config,
    required bool forced,
    void Function(double percent)? onOtaProgress,
  }) async {
    if (Platform.isAndroid) {
      // 1. Play path — throws/reports unavailable for sideloaded installs.
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          forced
              ? await InAppUpdate.performImmediateUpdate()
              : await InAppUpdate.startFlexibleUpdate()
                  .then((_) => InAppUpdate.completeFlexibleUpdate());
          return;
        }
      } catch (_) {
        // Not a Play install (or Play unreachable) — fall through to OTA.
      }

      // 2. Self-hosted OTA.
      final url = config.apkUrl;
      if (url == null || url.isEmpty) return;
      final done = Completer<void>();
      OtaUpdate()
          .execute(
        url,
        destinationFilename: 'hari-update.apk',
        sha256checksum: config.apkSha256,
      )
          .listen(
        (OtaEvent e) {
          switch (e.status) {
            case OtaStatus.DOWNLOADING:
              onOtaProgress?.call(double.tryParse(e.value ?? '') ?? 0);
              break;
            case OtaStatus.INSTALLING:
              onOtaProgress?.call(100);
              if (!done.isCompleted) done.complete();
              break;
            default: // errors, permission denied, checksum mismatch…
              if (!done.isCompleted) {
                done.completeError(Exception('Update failed: ${e.status}'));
              }
          }
        },
        onError: (Object err) {
          if (!done.isCompleted) done.completeError(err);
        },
      );
      return done.future;
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
