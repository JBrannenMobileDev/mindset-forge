import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firebase/accountability_service.dart';
import '../core/services/analytics_service.dart';
import '../models/accountability_relationship.dart';
import '../models/partner_progress.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

/// Owns accountability-partner state and is the single entry point widgets use
/// for partner actions (per the architecture rules — no direct service calls
/// from widgets).
class AccountabilityNotifier
    extends StateNotifier<List<AccountabilityRelationship>> {
  final Ref _ref;

  AccountabilityNotifier(this._ref) : super([]);

  void _loadFromProfile(UserProfile? profile) {
    if (profile == null) {
      state = [];
      return;
    }
    state = profile.accountabilityRelationships;
  }

  List<AccountabilityRelationship> get activeRelationships =>
      state.where((r) => r.status == 'active').toList();

  /// Creates an invite and returns a shareable https link.
  Future<String> createInvite({
    required String partnerEmail,
    required String partnerName,
  }) async {
    final link = await _ref.read(accountabilityServiceProvider).createPartnerInvite(
          partnerEmail: partnerEmail,
          partnerName: partnerName,
        );
    _ref.read(analyticsServiceProvider).trackPartnerInviteSent();
    return link;
  }

  Future<String?> getInviteInfo(String inviteId) =>
      _ref.read(accountabilityServiceProvider).getPartnerInviteInfo(inviteId);

  Future<void> acceptInvite(String inviteId) async {
    await _ref.read(accountabilityServiceProvider).acceptPartnerInvite(inviteId);
    _ref.read(analyticsServiceProvider).trackPartnerInviteAccepted();
  }

  Future<PartnerProgress> getProgress(String primaryUid) =>
      _ref.read(accountabilityServiceProvider).getPartnerProgress(primaryUid);

  Future<void> sendEncouragement({
    required String primaryUid,
    required String message,
  }) async {
    await _ref.read(accountabilityServiceProvider).sendEncouragement(
          partnerUid: primaryUid,
          message: message,
        );
    _ref.read(analyticsServiceProvider).trackEncouragementSent();
  }

  Future<void> removePartner(String relationshipId) async {
    // Optimistic removal — the stream will reconcile from Firestore.
    state = state.where((r) => r.id != relationshipId).toList();
    await _ref.read(accountabilityServiceProvider).removePartner(relationshipId);
  }
}

final accountabilityProvider = StateNotifierProvider<AccountabilityNotifier,
    List<AccountabilityRelationship>>((ref) {
  final notifier = AccountabilityNotifier(ref);
  ref.listen(currentUserProfileProvider, (_, next) {
    next.whenData((profile) => notifier._loadFromProfile(profile));
  });
  ref.read(currentUserProfileProvider).whenData(
        (profile) => notifier._loadFromProfile(profile),
      );
  return notifier;
});
