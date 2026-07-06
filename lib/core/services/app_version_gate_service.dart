import 'package:package_info_plus/package_info_plus.dart';
import '../../models/app_version_config.dart';
import '../firebase/firestore_service.dart';

/// Gates the app (or individual features) behind a minimum build number so a
/// backend contract change that an old client can't handle can force/prompt
/// an update instead of silently breaking.
///
/// Loaded once at startup (see `_InitAppState._init` in `lib/main.dart`) and
/// read synchronously everywhere else, the same pattern as `ConsentService`
/// and `PendingInviteStore` — this is build-time-loaded static config, not
/// reactive per-user state, so a Riverpod provider isn't warranted.
///
/// Fails open: if the Firestore read never completes (or throws), both
/// `_currentBuildNumber` and `_config` stay at their no-gate defaults, so a
/// config hiccup can never lock users out.
class AppVersionGateService {
  AppVersionGateService._();

  static int _currentBuildNumber = 0;
  static AppVersionConfig _config = const AppVersionConfig();

  static Future<void> load(FirestoreService firestoreService) async {
    final info = await PackageInfo.fromPlatform();
    _currentBuildNumber = int.tryParse(info.buildNumber) ?? 0;
    _config = await firestoreService.getAppVersionConfig();
  }

  /// True when the installed build is below the global minimum — the entire
  /// app should be replaced with `UpdateRequiredScreen`.
  static bool get isAppBelowMinVersion =>
      _config.minBuildNumber > 0 &&
      _currentBuildNumber < _config.minBuildNumber;

  /// True when the installed build is below [featureKey]'s configured
  /// minimum — that one action should be blocked behind
  /// `showUpdateRequiredDialog` via `ensureFeatureVersion`.
  static bool isFeatureBelowMinVersion(String featureKey) {
    final minBuild = _config.featureMinBuildNumbers[featureKey];
    return minBuild != null &&
        minBuild > 0 &&
        _currentBuildNumber < minBuild;
  }
}
