import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/partner_progress.dart';

/// Wraps all Cloud Function calls for accountability partner features.
class AccountabilityService {
  final _functions = FirebaseFunctions.instance;

  /// Creates a partner invite and returns a shareable https link.
  Future<String> createPartnerInvite({
    required String partnerEmail,
    required String partnerName,
  }) async {
    final callable = _functions.httpsCallable('sendPartnerInviteEmail');
    final result = await callable.call({
      'partnerEmail': partnerEmail,
      'partnerName': partnerName,
    });
    return result.data['inviteLink'] as String? ?? '';
  }

  /// Fetches the privacy-curated progress snapshot for a primary user the
  /// caller is partnered with.
  Future<PartnerProgress> getPartnerProgress(String primaryUid) async {
    final callable = _functions.httpsCallable('getPartnerProgress');
    final result = await callable.call({'primaryUid': primaryUid});
    return PartnerProgress.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<void> removePartner(String relationshipId) async {
    final callable = _functions.httpsCallable('removePartner');
    await callable.call({'relationshipId': relationshipId});
  }

  Future<String?> getPartnerInviteInfo(String inviteId) async {
    final callable = _functions.httpsCallable('getPartnerInviteInfo');
    final result = await callable.call({'inviteId': inviteId});
    return result.data['primaryName'] as String?;
  }

  Future<void> acceptPartnerInvite(String inviteId) async {
    final callable = _functions.httpsCallable('acceptPartnerInvite');
    await callable.call({'inviteId': inviteId});
  }

  Future<void> sendEncouragement({
    required String partnerUid,
    required String message,
  }) async {
    final callable = _functions.httpsCallable('sendEncouragement');
    await callable.call({'primaryUid': partnerUid, 'message': message});
  }

  Future<void> deleteUserAccount() async {
    final callable = _functions.httpsCallable('deleteUserAccount');
    await callable.call();
  }
}

final accountabilityServiceProvider = Provider<AccountabilityService>(
  (_) => AccountabilityService(),
);
