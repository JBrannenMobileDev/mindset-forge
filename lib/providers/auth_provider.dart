import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firebase/firestore_service.dart';
import '../models/user_profile.dart';

final firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final currentUserProfileProvider = StreamProvider<UserProfile?>(
  (ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      data: (user) {
        if (user == null) return const Stream.empty();
        return ref.watch(firestoreServiceProvider).streamUserProfile(user.uid);
      },
      loading: () => const Stream.empty(),
      error: (_, __) => const Stream.empty(),
    );
  },
);
