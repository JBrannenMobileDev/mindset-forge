import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/firebase/firestore_service.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final bool isGoogleLoading;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isGoogleLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isGoogleLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final FirestoreService _firestoreService;

  AuthNotifier(this._firestoreService) : super(const AuthState());

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
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
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapSignUpError(e.code),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred. Please try again.');
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isGoogleLoading: true, clearError: true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        state = state.copyWith(isGoogleLoading: false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCred.additionalUserInfo?.isNewUser == true) {
        final profile = UserProfile.create(
          uid: userCred.user!.uid,
          email: userCred.user!.email ?? googleUser.email,
          displayName:
              userCred.user!.displayName ?? googleUser.displayName ?? '',
        );
        await _firestoreService.createUserProfile(profile);
      } else {
        final existing =
            await _firestoreService.getUserProfile(userCred.user!.uid);
        if (existing == null) {
          final profile = UserProfile.create(
            uid: userCred.user!.uid,
            email: userCred.user!.email ?? googleUser.email,
            displayName:
                userCred.user!.displayName ?? googleUser.displayName ?? '',
          );
          await _firestoreService.createUserProfile(profile);
        }
      }
      // Navigation handled by GoRouter auth guard.
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isGoogleLoading: false,
        errorMessage: _mapAuthError(e.code),
      );
    } catch (_) {
      state = state.copyWith(isGoogleLoading: false, errorMessage: 'Google sign-in failed. Please try again.');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
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
  return AuthNotifier(ref.read(firestoreServiceProvider));
});
