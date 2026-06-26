import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firebase/firestore_service.dart';
import '../core/services/analytics_service.dart';
import '../core/services/notification_service.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final FirestoreService _firestoreService;
  final Ref _ref;

  AuthNotifier(this._firestoreService, this._ref) : super(const AuthState());

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _ref.read(analyticsServiceProvider).trackLogIn();
      // Navigation is handled reactively by GoRouter's auth guard.
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapAuthError(e.code),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred. Please try again.');
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());

      final profile = UserProfile.create(
        uid: cred.user!.uid,
        email: email.trim(),
        displayName: name.trim(),
      );
      await _firestoreService.createUserProfile(profile);
      _ref.read(analyticsServiceProvider).trackSignUp();
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapSignUpError(e.code),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred. Please try again.');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    // Clear push token + local reminders so a logged-out user (or the next user
    // on a shared device) stops receiving this account's notifications.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final service = NotificationService();
      if (uid != null) await service.clearToken(uid, _firestoreService);
      await service.cancelAll();
    } catch (_) {}
    final analytics = _ref.read(analyticsServiceProvider);
    analytics.trackLogOut();
    analytics.reset();
    await FirebaseAuth.instance.signOut();
  }

  // ─── Error mapping ──────────────────────────────────────────────────────────

  String _mapAuthError(String code) {
    return switch (code) {
      'user-not-found' => 'No account found with this email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-email' => 'Please enter a valid email address.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'invalid-credential' => 'Invalid credentials. Please check and try again.',
      'network-request-failed' => 'Network error. Check your connection.',
      _ => 'Sign-in failed. Please try again.',
    };
  }

  String _mapSignUpError(String code) {
    return switch (code) {
      'email-already-in-use' => 'An account with this email already exists.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      _ => 'Sign-up failed. Please try again.',
    };
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(firestoreServiceProvider), ref);
});
