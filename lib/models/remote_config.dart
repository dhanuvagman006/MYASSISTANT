/// Mirrors the backend's GET /config response — the update switchboard.
class RemoteConfig {
  final int latestVersionCode;
  final String latestVersionName;
  final int forceUpdateBelow;
  final List<String> changelog;
  final String? announcement;
  final Map<String, bool> features;

  const RemoteConfig({
    this.latestVersionCode = 1,
    this.latestVersionName = '0.1.0',
    this.forceUpdateBelow = 0,
    this.changelog = const [],
    this.announcement,
    this.features = const {},
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> j) => RemoteConfig(
        latestVersionCode: j['latestVersionCode'] ?? 1,
        latestVersionName: j['latestVersionName'] ?? '0.1.0',
        forceUpdateBelow: j['forceUpdateBelow'] ?? 0,
        changelog: List<String>.from(j['changelog'] ?? const []),
        announcement: j['announcement'],
        features: Map<String, bool>.from(j['features'] ?? const {}),
      );

  bool isEnabled(String feature) => features[feature] == true;
}
