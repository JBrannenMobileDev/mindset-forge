import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/fcm_service.dart';
import 'auth_provider.dart';

final fcmServiceProvider = Provider<FcmService>((_) => FcmService());

/// Auto-initializes FCM when the user is authenticated.
/// Watch this provider anywhere to trigger FCM setup.
final fcmInitProvider = FutureProvider<void>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return;

  final fcmService = ref.read(fcmServiceProvider);
  final firestoreService = ref.read(firestoreServiceProvider);

  await fcmService.initAndStoreToken(user.uid, firestoreService);
});
