/// Minimum build-number requirements used by the app update gate.
///
/// `minBuildNumber` gates the entire app (see `AppVersionGateService`); a
/// value of `0` means no global gate is active. `featureMinBuildNumbers` gates
/// individual features by key (e.g. `"coachChat"`); a missing or `0` entry
/// means that feature has no gate. Values are the Flutter build number (the
/// `+N` in `pubspec.yaml`'s `version: 1.0.7+9`), a single unified counter
/// across platforms in this project's release process.
class AppVersionConfig {
  final int minBuildNumber;
  final Map<String, int> featureMinBuildNumbers;

  const AppVersionConfig({
    this.minBuildNumber = 0,
    this.featureMinBuildNumbers = const {},
  });

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) =>
      AppVersionConfig(
        minBuildNumber: (json['minBuildNumber'] as num?)?.toInt() ?? 0,
        featureMinBuildNumbers:
            (json['featureMinBuildNumbers'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
                ) ??
                const {},
      );
}
