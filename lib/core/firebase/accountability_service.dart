import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps all Cloud Function calls for accountability partner features.
class AccountabilityService {
  final _functions = FirebaseFunctions.instance;

  Future<void> sendPartnerInvite({
    required String partnerEmail,
    required String partnerName,
  }) async {
    final callable = _functions.httpsCallable('sendPartnerInviteEmail');
    await callable.call({'partnerEmail': partnerEmail, 'partnerName': partnerName});
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
