import 'package:flutter/material.dart';
import '../services/app_version_gate_service.dart';
import '../widgets/update_required_dialog.dart';

/// Reusable guard for any feature call site backed by a versioned API
/// contract. Returns `true` if [featureKey] is usable on this build. If the
/// installed build is below that feature's configured minimum (see
/// `AppVersionGateService`), shows the update-required dialog and returns
/// `false` so the caller can bail out before making the call — e.g.:
///
/// ```dart
/// if (!await ensureFeatureVersion(context, 'coachChat')) return;
/// ```
Future<bool> ensureFeatureVersion(
  BuildContext context,
  String featureKey, {
  String? message,
}) async {
  if (!AppVersionGateService.isFeatureBelowMinVersion(featureKey)) {
    return true;
  }
  await showUpdateRequiredDialog(context, message: message);
  return false;
}
