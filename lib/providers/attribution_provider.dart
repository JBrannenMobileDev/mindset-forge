import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/constants/app_strings.dart';
import '../models/attribution_source.dart';
import 'auth_provider.dart';

/// Offline fallback for the onboarding attribution question.
///
/// Deliberately contains generic channels only. Referral partners are added to
/// the `app_config/attribution_sources` Firestore doc instead, so signing a new
/// partner never requires an App Store release.
const kDefaultAttributionSources = <AttributionSource>[
  AttributionSource(id: 'instagram', label: AppStrings.attributionSourceInstagram),
  AttributionSource(id: 'tiktok', label: AppStrings.attributionSourceTiktok),
  AttributionSource(id: 'youtube', label: AppStrings.attributionSourceYoutube),
  AttributionSource(id: 'podcast', label: AppStrings.attributionSourcePodcast),
  AttributionSource(id: 'friend', label: AppStrings.attributionSourceFriend),
  AttributionSource(id: 'search', label: AppStrings.attributionSourceSearch),
  AttributionSource(id: 'other', label: AppStrings.attributionSourceOther),
];

/// The option list shown in onboarding. Reads remote config, falling back to
/// [kDefaultAttributionSources] when the doc is missing, empty, or unreadable.
/// Never surfaces an error state: a failed config read must not block signup.
final attributionSourcesProvider =
    FutureProvider<List<AttributionSource>>((ref) async {
  try {
    final remote =
        await ref.read(firestoreServiceProvider).getAttributionSources();
    if (remote.isNotEmpty) return remote;
  } catch (e) {
    debugPrint('attributionSourcesProvider: using defaults after error: $e');
  }
  return kDefaultAttributionSources;
});

/// Writes the user's attribution answer to their profile and mirrors it to
/// RevenueCat, where it becomes a subscriber attribute available on purchase
/// webhooks and in revenue chart segmentation. That mirroring is what lets
/// partner revenue be reported without a bespoke commission ledger.
class AttributionService {
  final Ref _ref;

  AttributionService(this._ref);

  /// Records [sourceId] against the signed-in user. [detail] carries the raw
  /// Play Install Referrer string on Android so a deterministic referrer and a
  /// contradicting self-report remain independently visible.
  ///
  /// Failures are logged rather than surfaced: attribution is analytics, and
  /// losing it must never trap a user mid-onboarding.
  Future<void> record(String sourceId, {String? detail}) async {
    if (sourceId.isEmpty) return;
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'referralSource': sourceId,
        if (detail != null && detail.isNotEmpty) 'referralSourceDetail': detail,
        'referredAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('AttributionService.record persist failed: $e');
    }

    await _syncToRevenueCat(sourceId);
  }

  /// RevenueCat is not configured on web (see `_initRevenueCat` in main.dart),
  /// so this is a no-op there.
  Future<void> _syncToRevenueCat(String sourceId) async {
    if (kIsWeb) return;
    try {
      await Purchases.setAttributes({'referral_source': sourceId});
    } catch (e) {
      debugPrint('AttributionService RevenueCat attribute failed: $e');
    }
  }
}

final attributionServiceProvider =
    Provider<AttributionService>(AttributionService.new);
